"""
Session Manager for Voice Agent

Manages conversation sessions, including creation, retrieval,
and message history management.
"""

import json
import os
import time
import uuid
from typing import Any

import boto3
from botocore.exceptions import ClientError

from logger import get_logger

logger = get_logger(__name__)


class SessionManager:
    """Manages voice agent conversation sessions."""

    def __init__(self):
        """Initialize session manager with in-memory storage or DynamoDB."""
        self._sessions: dict[str, dict] = {}
        self._use_dynamodb = os.environ.get("USE_DYNAMODB_SESSIONS", "false").lower() == "true"

        if self._use_dynamodb:
            self._dynamodb = boto3.resource("dynamodb")
            self._table_name = os.environ.get("SESSIONS_TABLE_NAME", "voice-agent-sessions")
            self._table = self._dynamodb.Table(self._table_name)

        self._max_history_length = int(os.environ.get("MAX_HISTORY_LENGTH", "20"))
        self._session_ttl_seconds = int(os.environ.get("SESSION_TTL_SECONDS", "3600"))

    def create_session(self, contact_id: str, phone_number: str) -> dict[str, Any]:
        """
        Create a new session for a contact.

        Args:
            contact_id: The unique contact ID from Connect
            phone_number: The caller's phone number

        Returns:
            The created session object
        """
        session_id = str(uuid.uuid4())
        timestamp = int(time.time())

        session = {
            "session_id": session_id,
            "contact_id": contact_id,
            "phone_number": phone_number,
            "created_at": timestamp,
            "updated_at": timestamp,
            "ttl": timestamp + self._session_ttl_seconds,
            "conversation_history": [],
            "turn_count": 0,
            "status": "active",
            "metadata": {},
        }

        if self._use_dynamodb:
            try:
                self._table.put_item(Item=session)
            except ClientError as e:
                logger.error(f"Failed to create session in DynamoDB: {e}")
                raise
        else:
            self._sessions[contact_id] = session

        logger.info(
            f"Created session",
            extra={
                "session_id": session_id,
                "contact_id": contact_id,
            },
        )

        return session

    def get_session(self, contact_id: str) -> dict[str, Any] | None:
        """
        Retrieve a session by contact ID.

        Args:
            contact_id: The unique contact ID

        Returns:
            The session object or None if not found
        """
        if self._use_dynamodb:
            try:
                response = self._table.get_item(Key={"contact_id": contact_id})
                session = response.get("Item")
                if session:
                    # Check if session has expired
                    if session.get("ttl", 0) < int(time.time()):
                        logger.info(f"Session expired: {contact_id}")
                        return None
                return session
            except ClientError as e:
                logger.error(f"Failed to get session from DynamoDB: {e}")
                return None
        else:
            session = self._sessions.get(contact_id)
            if session and session.get("ttl", 0) < int(time.time()):
                del self._sessions[contact_id]
                return None
            return session

    def update_session(self, contact_id: str, session: dict[str, Any]) -> None:
        """
        Update an existing session.

        Args:
            contact_id: The unique contact ID
            session: The updated session object
        """
        session["updated_at"] = int(time.time())
        session["ttl"] = int(time.time()) + self._session_ttl_seconds

        if self._use_dynamodb:
            try:
                self._table.put_item(Item=session)
            except ClientError as e:
                logger.error(f"Failed to update session in DynamoDB: {e}")
                raise
        else:
            self._sessions[contact_id] = session

    def end_session(self, contact_id: str) -> None:
        """
        End and clean up a session.

        Args:
            contact_id: The unique contact ID
        """
        session = self.get_session(contact_id)
        if session:
            session["status"] = "completed"
            session["ended_at"] = int(time.time())

            if self._use_dynamodb:
                try:
                    # Update with completed status but keep for audit
                    self._table.put_item(Item=session)
                except ClientError as e:
                    logger.error(f"Failed to end session in DynamoDB: {e}")
            else:
                if contact_id in self._sessions:
                    del self._sessions[contact_id]

            logger.info(
                f"Ended session",
                extra={
                    "session_id": session.get("session_id"),
                    "contact_id": contact_id,
                    "turn_count": session.get("turn_count", 0),
                },
            )

    def add_message(self, contact_id: str, role: str, content: str) -> None:
        """
        Add a message to the conversation history.

        Args:
            contact_id: The unique contact ID
            role: The message role (user or assistant)
            content: The message content
        """
        session = self.get_session(contact_id)
        if not session:
            logger.warning(f"Session not found for adding message: {contact_id}")
            return

        message = {
            "role": role,
            "content": content,
            "timestamp": int(time.time()),
        }

        conversation_history = session.get("conversation_history", [])
        conversation_history.append(message)

        # Trim history if it exceeds max length
        if len(conversation_history) > self._max_history_length * 2:
            # Keep the most recent messages
            conversation_history = conversation_history[-self._max_history_length * 2:]

        session["conversation_history"] = conversation_history
        self.update_session(contact_id, session)

    def get_conversation_history(
        self,
        contact_id: str,
        max_messages: int | None = None,
    ) -> list[dict[str, Any]]:
        """
        Get the conversation history for a session.

        Args:
            contact_id: The unique contact ID
            max_messages: Maximum number of messages to return

        Returns:
            List of conversation messages
        """
        session = self.get_session(contact_id)
        if not session:
            return []

        history = session.get("conversation_history", [])

        if max_messages and len(history) > max_messages:
            history = history[-max_messages:]

        # Format for Bedrock
        formatted_history = []
        for msg in history:
            formatted_history.append({
                "role": msg["role"],
                "content": [{"type": "text", "text": msg["content"]}],
            })

        return formatted_history

    def get_session_metadata(self, contact_id: str) -> dict[str, Any]:
        """
        Get session metadata.

        Args:
            contact_id: The unique contact ID

        Returns:
            Session metadata dictionary
        """
        session = self.get_session(contact_id)
        if not session:
            return {}

        return session.get("metadata", {})

    def update_session_metadata(
        self,
        contact_id: str,
        metadata: dict[str, Any],
    ) -> None:
        """
        Update session metadata.

        Args:
            contact_id: The unique contact ID
            metadata: Metadata to merge into existing metadata
        """
        session = self.get_session(contact_id)
        if not session:
            logger.warning(f"Session not found for metadata update: {contact_id}")
            return

        current_metadata = session.get("metadata", {})
        current_metadata.update(metadata)
        session["metadata"] = current_metadata

        self.update_session(contact_id, session)

    def get_active_sessions_count(self) -> int:
        """
        Get the count of active sessions.

        Returns:
            Number of active sessions
        """
        if self._use_dynamodb:
            try:
                response = self._table.scan(
                    FilterExpression="status = :status AND #ttl > :now",
                    ExpressionAttributeNames={"#ttl": "ttl"},
                    ExpressionAttributeValues={
                        ":status": "active",
                        ":now": int(time.time()),
                    },
                    Select="COUNT",
                )
                return response.get("Count", 0)
            except ClientError as e:
                logger.error(f"Failed to count active sessions: {e}")
                return 0
        else:
            current_time = int(time.time())
            return sum(
                1
                for s in self._sessions.values()
                if s.get("status") == "active" and s.get("ttl", 0) > current_time
            )
