"""
AWS Voice Agent - Lambda Orchestrator Handler

This module serves as the main entry point for the voice agent Lambda function.
It orchestrates the interaction between Amazon Connect, Bedrock, Polly, and other services.
"""

import json
import os
import time
import uuid
from typing import Any

from session_manager import SessionManager
from bedrock_client import BedrockClient
from neptune_client import NeptuneClient
from logger import get_logger, log_latency
from error_handler import handle_error, VoiceAgentError
from metrics import MetricsPublisher

# Initialize logger
logger = get_logger(__name__)

# Initialize clients
bedrock_client = BedrockClient()
session_manager = SessionManager()
metrics = MetricsPublisher()

# Initialize Neptune client if enabled
neptune_client = None
if os.environ.get("NEPTUNE_ENABLED", "false").lower() == "true":
    neptune_client = NeptuneClient()


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """
    Main Lambda handler for voice agent orchestration.

    Args:
        event: The event from Amazon Connect or other triggers
        context: Lambda context object

    Returns:
        Response dict with agent response and action
    """
    start_time = time.time()
    request_id = context.aws_request_id if context else str(uuid.uuid4())

    logger.info(
        "Processing request",
        extra={
            "request_id": request_id,
            "event_type": event.get("Details", {}).get("ContactData", {}).get("Channel", "UNKNOWN"),
        },
    )

    try:
        # Parse the incoming event
        contact_data = event.get("Details", {}).get("ContactData", {})
        parameters = event.get("Details", {}).get("Parameters", {})

        # Extract key information
        contact_id = contact_data.get("ContactId", str(uuid.uuid4()))
        customer_endpoint = contact_data.get("CustomerEndpoint", {})
        phone_number = customer_endpoint.get("Address", "unknown")
        channel = contact_data.get("Channel", "VOICE")

        # Get user input from Connect
        user_input = parameters.get("userInput", "")

        # Handle different event types
        event_type = parameters.get("eventType", "user_input")

        if event_type == "init":
            return handle_init(contact_id, phone_number, request_id)
        elif event_type == "user_input":
            return handle_user_input(
                contact_id=contact_id,
                phone_number=phone_number,
                user_input=user_input,
                request_id=request_id,
            )
        elif event_type == "end":
            return handle_end(contact_id, request_id)
        else:
            logger.warning(f"Unknown event type: {event_type}")
            return handle_user_input(
                contact_id=contact_id,
                phone_number=phone_number,
                user_input=user_input,
                request_id=request_id,
            )

    except VoiceAgentError as e:
        logger.error(f"Voice agent error: {e}", exc_info=True)
        return handle_error(e, request_id)
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
        return handle_error(e, request_id)
    finally:
        # Log total latency
        total_latency = (time.time() - start_time) * 1000
        log_latency("TotalLatency", total_latency)
        metrics.publish_latency("TotalLatency", total_latency)


def handle_init(contact_id: str, phone_number: str, request_id: str) -> dict[str, Any]:
    """
    Handle initialization of a new call session.

    Args:
        contact_id: The unique contact ID from Connect
        phone_number: The caller's phone number
        request_id: The request ID for logging

    Returns:
        Response with greeting message
    """
    logger.info(f"Initializing session for contact: {contact_id}")

    # Create or retrieve session
    session = session_manager.create_session(contact_id, phone_number)

    # Get caller history if Neptune is enabled
    caller_context = ""
    if neptune_client:
        try:
            caller_history = neptune_client.get_caller_history(phone_number)
            if caller_history:
                caller_context = f"\nCaller has {len(caller_history)} previous interactions."
                session["caller_history"] = caller_history
                session_manager.update_session(contact_id, session)
        except Exception as e:
            logger.warning(f"Failed to retrieve caller history: {e}")

    # Generate personalized greeting
    greeting = os.environ.get(
        "GREETING_MESSAGE",
        "Hello! Thank you for calling. How can I help you today?",
    )

    # Store greeting in conversation history
    session_manager.add_message(contact_id, "assistant", greeting)

    return {
        "response": greeting,
        "action": "continue",
        "sessionId": session["session_id"],
    }


def handle_user_input(
    contact_id: str,
    phone_number: str,
    user_input: str,
    request_id: str,
) -> dict[str, Any]:
    """
    Handle user input and generate response.

    Args:
        contact_id: The unique contact ID
        phone_number: The caller's phone number
        user_input: The transcribed user speech
        request_id: The request ID for logging

    Returns:
        Response with agent message and action
    """
    logger.info(
        f"Processing user input for contact: {contact_id}",
        extra={"input_length": len(user_input)},
    )

    # Get or create session
    session = session_manager.get_session(contact_id)
    if not session:
        session = session_manager.create_session(contact_id, phone_number)

    # Add user message to history
    session_manager.add_message(contact_id, "user", user_input)

    # Get conversation history
    conversation_history = session_manager.get_conversation_history(contact_id)

    # Build context for Bedrock
    context = build_context(session, conversation_history)

    # Call Bedrock for response
    llm_start = time.time()
    bedrock_response = bedrock_client.generate_response(
        conversation_history=conversation_history,
        context=context,
        session_id=session["session_id"],
    )
    llm_latency = (time.time() - llm_start) * 1000
    log_latency("LLMLatency", llm_latency)
    metrics.publish_latency("LLMLatency", llm_latency)

    # Parse response
    response_text = bedrock_response.get("response", "")
    action = bedrock_response.get("action", "continue")
    tool_calls = bedrock_response.get("tool_calls", [])

    # Execute any tool calls
    if tool_calls:
        tool_results = execute_tools(tool_calls, session)
        # If tools returned results, we might need another LLM call
        if tool_results:
            # Add tool results to context and regenerate
            bedrock_response = bedrock_client.generate_response(
                conversation_history=conversation_history,
                context=context,
                session_id=session["session_id"],
                tool_results=tool_results,
            )
            response_text = bedrock_response.get("response", response_text)
            action = bedrock_response.get("action", action)

    # Add assistant response to history
    session_manager.add_message(contact_id, "assistant", response_text)

    # Store conversation in Neptune if enabled
    if neptune_client:
        try:
            neptune_client.store_conversation_turn(
                session_id=session["session_id"],
                phone_number=phone_number,
                user_input=user_input,
                assistant_response=response_text,
            )
        except Exception as e:
            logger.warning(f"Failed to store conversation in Neptune: {e}")

    # Check for conversation limits
    turn_count = len(conversation_history) // 2
    max_turns = int(os.environ.get("MAX_CONVERSATION_TURNS", "50"))
    if turn_count >= max_turns:
        action = "transfer"
        response_text = (
            "I've been helping you for a while now. "
            "Let me transfer you to a specialist who can continue assisting you."
        )

    # Update session
    session["turn_count"] = turn_count
    session_manager.update_session(contact_id, session)

    return {
        "response": response_text,
        "action": action,
        "sessionId": session["session_id"],
        "turnCount": turn_count,
    }


def handle_end(contact_id: str, request_id: str) -> dict[str, Any]:
    """
    Handle end of call session.

    Args:
        contact_id: The unique contact ID
        request_id: The request ID for logging

    Returns:
        Response confirming session end
    """
    logger.info(f"Ending session for contact: {contact_id}")

    # Get session for final storage
    session = session_manager.get_session(contact_id)

    if session and neptune_client:
        try:
            neptune_client.complete_session(session["session_id"])
        except Exception as e:
            logger.warning(f"Failed to complete session in Neptune: {e}")

    # Clean up session
    session_manager.end_session(contact_id)

    goodbye_message = os.environ.get(
        "GOODBYE_MESSAGE",
        "Thank you for calling. Have a great day!",
    )

    return {
        "response": goodbye_message,
        "action": "end",
    }


def build_context(session: dict, conversation_history: list) -> dict[str, Any]:
    """
    Build context object for Bedrock.

    Args:
        session: Current session data
        conversation_history: List of conversation messages

    Returns:
        Context dictionary for Bedrock
    """
    company_name = os.environ.get("COMPANY_NAME", "our company")

    context = {
        "company_name": company_name,
        "session_id": session.get("session_id", ""),
        "phone_number": session.get("phone_number", ""),
        "turn_count": session.get("turn_count", 0),
        "caller_history": session.get("caller_history", []),
        "current_time": time.strftime("%Y-%m-%d %H:%M:%S"),
    }

    return context


def execute_tools(tool_calls: list, session: dict) -> list[dict]:
    """
    Execute tool calls from Bedrock response.

    Args:
        tool_calls: List of tool calls to execute
        session: Current session data

    Returns:
        List of tool results
    """
    results = []

    for tool_call in tool_calls:
        tool_name = tool_call.get("name", "")
        tool_input = tool_call.get("input", {})
        tool_id = tool_call.get("id", str(uuid.uuid4()))

        logger.info(f"Executing tool: {tool_name}")

        try:
            if tool_name == "search_knowledge_base":
                result = execute_knowledge_base_search(tool_input)
            elif tool_name == "lookup_account":
                result = execute_account_lookup(tool_input, session)
            elif tool_name == "schedule_appointment":
                result = execute_schedule_appointment(tool_input, session)
            elif tool_name == "transfer_to_agent":
                result = {"transfer_requested": True, "department": tool_input.get("department", "general")}
            else:
                result = {"error": f"Unknown tool: {tool_name}"}

            results.append({
                "tool_use_id": tool_id,
                "content": json.dumps(result),
            })

        except Exception as e:
            logger.error(f"Tool execution failed: {e}")
            results.append({
                "tool_use_id": tool_id,
                "content": json.dumps({"error": str(e)}),
            })

    return results


def execute_knowledge_base_search(tool_input: dict) -> dict:
    """Execute knowledge base search."""
    query = tool_input.get("query", "")

    # If Neptune is enabled, use it for knowledge retrieval
    if neptune_client:
        try:
            results = neptune_client.search_knowledge(query)
            return {"results": results}
        except Exception as e:
            logger.warning(f"Knowledge search failed: {e}")

    # Fallback to Bedrock Knowledge Base if configured
    kb_id = os.environ.get("BEDROCK_KNOWLEDGE_BASE_ID")
    if kb_id:
        return bedrock_client.retrieve_from_knowledge_base(kb_id, query)

    return {"results": [], "message": "Knowledge base not configured"}


def execute_account_lookup(tool_input: dict, session: dict) -> dict:
    """Execute account lookup."""
    account_id = tool_input.get("account_id", session.get("phone_number", ""))

    # This would integrate with your CRM or account system
    # For now, return a placeholder
    return {
        "account_id": account_id,
        "status": "active",
        "message": "Account lookup would be performed here",
    }


def execute_schedule_appointment(tool_input: dict, session: dict) -> dict:
    """Execute appointment scheduling."""
    date = tool_input.get("date", "")
    time_slot = tool_input.get("time", "")
    appointment_type = tool_input.get("type", "general")

    # This would integrate with your scheduling system
    # For now, return a placeholder
    return {
        "appointment_id": str(uuid.uuid4()),
        "date": date,
        "time": time_slot,
        "type": appointment_type,
        "status": "pending",
        "message": "Appointment scheduling would be performed here",
    }
