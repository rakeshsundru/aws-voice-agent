"""
Neptune Client for Voice Agent

Handles interaction with Amazon Neptune graph database
for conversation memory and caller history.
"""

import json
import os
import time
import uuid
from typing import Any

from logger import get_logger

logger = get_logger(__name__)

# Neptune connection - using gremlin-python
try:
    from gremlin_python.driver.driver_remote_connection import DriverRemoteConnection
    from gremlin_python.process.anonymous_traversal import traversal
    from gremlin_python.process.graph_traversal import __
    from gremlin_python.process.traversal import T, P

    GREMLIN_AVAILABLE = True
except ImportError:
    GREMLIN_AVAILABLE = False
    logger.warning("gremlin-python not available, Neptune features disabled")


class NeptuneClient:
    """Client for interacting with Amazon Neptune."""

    def __init__(self):
        """Initialize the Neptune client."""
        if not GREMLIN_AVAILABLE:
            raise ImportError("gremlin-python is required for Neptune client")

        self._endpoint = os.environ.get("NEPTUNE_ENDPOINT", "")
        self._port = int(os.environ.get("NEPTUNE_PORT", "8182"))
        self._use_iam = os.environ.get("NEPTUNE_USE_IAM", "true").lower() == "true"

        self._connection = None
        self._g = None

    def _connect(self):
        """Establish connection to Neptune."""
        if self._g is not None:
            return

        try:
            connection_string = f"wss://{self._endpoint}:{self._port}/gremlin"

            if self._use_iam:
                # Use IAM authentication
                from gremlin_python.driver.aiohttp.transport import AiohttpTransport
                from neptune_python_utils.gremlin_utils import GremlinUtils

                gremlin_utils = GremlinUtils()
                connection = gremlin_utils.remote_connection()
            else:
                connection = DriverRemoteConnection(connection_string, "g")

            self._connection = connection
            self._g = traversal().withRemote(connection)

            logger.info(f"Connected to Neptune at {self._endpoint}")

        except Exception as e:
            logger.error(f"Failed to connect to Neptune: {e}")
            raise

    def _ensure_connected(self):
        """Ensure connection is established."""
        if self._g is None:
            self._connect()

    def close(self):
        """Close the Neptune connection."""
        if self._connection:
            self._connection.close()
            self._connection = None
            self._g = None

    def get_caller_history(
        self,
        phone_number: str,
        limit: int = 10,
    ) -> list[dict[str, Any]]:
        """
        Get the conversation history for a caller.

        Args:
            phone_number: The caller's phone number
            limit: Maximum number of sessions to return

        Returns:
            List of previous session summaries
        """
        self._ensure_connected()

        try:
            # Query for caller's previous sessions
            results = (
                self._g.V()
                .has("Caller", "phone_number", phone_number)
                .out("HAS_SESSION")
                .order()
                .by("start_time", "desc")
                .limit(limit)
                .project("session_id", "start_time", "end_time", "status", "summary")
                .by("session_id")
                .by("start_time")
                .by(__.coalesce(__.values("end_time"), __.constant(None)))
                .by("status")
                .by(__.coalesce(__.values("summary"), __.constant("")))
                .toList()
            )

            return [dict(r) for r in results]

        except Exception as e:
            logger.error(f"Failed to get caller history: {e}")
            return []

    def store_conversation_turn(
        self,
        session_id: str,
        phone_number: str,
        user_input: str,
        assistant_response: str,
    ) -> None:
        """
        Store a conversation turn in Neptune.

        Args:
            session_id: The session ID
            phone_number: The caller's phone number
            user_input: The user's input
            assistant_response: The assistant's response
        """
        self._ensure_connected()

        try:
            timestamp = int(time.time())
            message_id = str(uuid.uuid4())

            # Create or get caller vertex
            caller = (
                self._g.V()
                .has("Caller", "phone_number", phone_number)
                .fold()
                .coalesce(
                    __.unfold(),
                    __.addV("Caller")
                    .property("phone_number", phone_number)
                    .property("created_at", timestamp),
                )
                .next()
            )

            # Create or get session vertex
            session = (
                self._g.V()
                .has("Session", "session_id", session_id)
                .fold()
                .coalesce(
                    __.unfold(),
                    __.addV("Session")
                    .property("session_id", session_id)
                    .property("start_time", timestamp)
                    .property("status", "active"),
                )
                .next()
            )

            # Ensure caller-session edge exists
            self._g.V(caller).as_("c").V(session).as_("s").coalesce(
                __.inE("HAS_SESSION").where(__.outV().as_("c")),
                __.addE("HAS_SESSION").from_("c"),
            ).iterate()

            # Add user message
            user_msg = (
                self._g.addV("Message")
                .property("message_id", f"{message_id}-user")
                .property("role", "user")
                .property("content", user_input)
                .property("timestamp", timestamp)
                .next()
            )

            # Add assistant message
            assistant_msg = (
                self._g.addV("Message")
                .property("message_id", f"{message_id}-assistant")
                .property("role", "assistant")
                .property("content", assistant_response)
                .property("timestamp", timestamp + 1)
                .next()
            )

            # Create edges from session to messages
            self._g.V(session).addE("CONTAINS").to(__.V(user_msg)).iterate()
            self._g.V(session).addE("CONTAINS").to(__.V(assistant_msg)).iterate()

            # Create sequence edge between messages
            self._g.V(user_msg).addE("FOLLOWED_BY").to(__.V(assistant_msg)).iterate()

            logger.debug(
                f"Stored conversation turn",
                extra={"session_id": session_id, "message_id": message_id},
            )

        except Exception as e:
            logger.error(f"Failed to store conversation turn: {e}")

    def complete_session(self, session_id: str, summary: str = "") -> None:
        """
        Mark a session as completed.

        Args:
            session_id: The session ID
            summary: Optional session summary
        """
        self._ensure_connected()

        try:
            timestamp = int(time.time())

            self._g.V().has("Session", "session_id", session_id).property(
                "status", "completed"
            ).property("end_time", timestamp).property("summary", summary).iterate()

            logger.info(f"Completed session: {session_id}")

        except Exception as e:
            logger.error(f"Failed to complete session: {e}")

    def search_knowledge(
        self,
        query: str,
        limit: int = 5,
    ) -> list[dict[str, Any]]:
        """
        Search for relevant knowledge based on query.

        This searches through previous conversations and stored knowledge
        to find relevant information.

        Args:
            query: The search query
            limit: Maximum number of results

        Returns:
            List of relevant knowledge items
        """
        self._ensure_connected()

        try:
            # Simple text search through messages
            # In production, you might want to use full-text search or embeddings
            results = (
                self._g.V()
                .hasLabel("Message")
                .has("role", "assistant")
                .has("content", P.containing(query.lower()))
                .limit(limit)
                .project("content", "timestamp")
                .by("content")
                .by("timestamp")
                .toList()
            )

            return [dict(r) for r in results]

        except Exception as e:
            logger.error(f"Knowledge search failed: {e}")
            return []

    def get_session_context(
        self,
        session_id: str,
        max_messages: int = 20,
    ) -> list[dict[str, Any]]:
        """
        Get the full context for a session.

        Args:
            session_id: The session ID
            max_messages: Maximum number of messages to return

        Returns:
            List of messages in the session
        """
        self._ensure_connected()

        try:
            results = (
                self._g.V()
                .has("Session", "session_id", session_id)
                .out("CONTAINS")
                .order()
                .by("timestamp", "asc")
                .limit(max_messages)
                .project("role", "content", "timestamp")
                .by("role")
                .by("content")
                .by("timestamp")
                .toList()
            )

            return [dict(r) for r in results]

        except Exception as e:
            logger.error(f"Failed to get session context: {e}")
            return []

    def add_intent(
        self,
        session_id: str,
        intent_name: str,
        confidence: float,
        entities: dict[str, Any] | None = None,
    ) -> None:
        """
        Add an intent detection to the session.

        Args:
            session_id: The session ID
            intent_name: Name of the detected intent
            confidence: Confidence score
            entities: Optional extracted entities
        """
        self._ensure_connected()

        try:
            timestamp = int(time.time())
            intent_id = str(uuid.uuid4())

            # Get session
            session = self._g.V().has("Session", "session_id", session_id).next()

            # Create intent vertex
            intent = (
                self._g.addV("Intent")
                .property("intent_id", intent_id)
                .property("intent_name", intent_name)
                .property("confidence", confidence)
                .property("entities", json.dumps(entities or {}))
                .property("timestamp", timestamp)
                .next()
            )

            # Create edge
            self._g.V(session).addE("HAS_INTENT").to(__.V(intent)).iterate()

            logger.debug(f"Added intent: {intent_name} to session {session_id}")

        except Exception as e:
            logger.error(f"Failed to add intent: {e}")

    def get_caller_preferences(self, phone_number: str) -> dict[str, Any]:
        """
        Get stored preferences for a caller.

        Args:
            phone_number: The caller's phone number

        Returns:
            Dictionary of caller preferences
        """
        self._ensure_connected()

        try:
            result = (
                self._g.V()
                .has("Caller", "phone_number", phone_number)
                .project("name", "preferences", "last_contact")
                .by(__.coalesce(__.values("name"), __.constant(None)))
                .by(__.coalesce(__.values("preferences"), __.constant("{}")))
                .by(
                    __.out("HAS_SESSION")
                    .order()
                    .by("start_time", "desc")
                    .limit(1)
                    .values("start_time")
                    .fold()
                )
                .next()
            )

            preferences = json.loads(result.get("preferences", "{}"))
            last_contact_times = result.get("last_contact", [])

            return {
                "name": result.get("name"),
                "preferences": preferences,
                "last_contact": last_contact_times[0] if last_contact_times else None,
            }

        except Exception as e:
            logger.error(f"Failed to get caller preferences: {e}")
            return {}

    def update_caller_preferences(
        self,
        phone_number: str,
        preferences: dict[str, Any],
    ) -> None:
        """
        Update preferences for a caller.

        Args:
            phone_number: The caller's phone number
            preferences: Preferences to update
        """
        self._ensure_connected()

        try:
            # Get existing preferences
            existing = self.get_caller_preferences(phone_number)
            current_prefs = existing.get("preferences", {})
            current_prefs.update(preferences)

            # Update in Neptune
            self._g.V().has("Caller", "phone_number", phone_number).property(
                "preferences", json.dumps(current_prefs)
            ).iterate()

            logger.debug(f"Updated preferences for caller: {phone_number}")

        except Exception as e:
            logger.error(f"Failed to update caller preferences: {e}")
