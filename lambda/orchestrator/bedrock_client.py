"""
Bedrock Client for Voice Agent

Handles interaction with Amazon Bedrock for LLM inference,
including streaming responses and tool use.
"""

import json
import os
import time
from typing import Any

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

from logger import get_logger

logger = get_logger(__name__)


class BedrockClient:
    """Client for interacting with Amazon Bedrock."""

    def __init__(self):
        """Initialize the Bedrock client."""
        config = Config(
            retries={"max_attempts": 3, "mode": "adaptive"},
            connect_timeout=5,
            read_timeout=60,
        )

        self._client = boto3.client("bedrock-runtime", config=config)
        self._agent_client = boto3.client("bedrock-agent-runtime", config=config)

        self._model_id = os.environ.get(
            "BEDROCK_MODEL_ID",
            "anthropic.claude-3-5-sonnet-20241022-v2:0",
        )
        self._max_tokens = int(os.environ.get("BEDROCK_MAX_TOKENS", "2000"))
        self._temperature = float(os.environ.get("BEDROCK_TEMPERATURE", "0.7"))
        self._streaming = os.environ.get("BEDROCK_STREAMING", "true").lower() == "true"
        self._guardrail_id = os.environ.get("BEDROCK_GUARDRAIL_ID")
        self._guardrail_version = os.environ.get("BEDROCK_GUARDRAIL_VERSION", "DRAFT")

        self._system_prompt = self._load_system_prompt()
        self._tools = self._load_tools()

    def _load_system_prompt(self) -> str:
        """Load the system prompt from file or environment."""
        prompt_path = os.environ.get("SYSTEM_PROMPT_PATH", "/opt/prompts/voice_agent_system_prompt.txt")

        try:
            with open(prompt_path) as f:
                return f.read()
        except FileNotFoundError:
            logger.warning(f"System prompt file not found at {prompt_path}, using default")

        company_name = os.environ.get("COMPANY_NAME", "Company")

        return f"""You are a helpful voice assistant for {company_name}. You are speaking with a customer over the phone.

Your role:
- Answer customer questions accurately and concisely
- Be friendly, professional, and empathetic
- Keep responses brief (2-3 sentences max) since this is voice
- Ask clarifying questions when needed
- Offer to transfer to a human agent for complex issues
- Never make up information you don't know

Guidelines:
- Speak naturally as if in a phone conversation
- Avoid technical jargon
- Use conversational language
- Acknowledge what the caller says before responding
- If you don't understand, politely ask them to rephrase

Available actions:
- Schedule appointments
- Look up account information
- Process simple requests
- Transfer to human agent
- Send follow-up information

If the user wants to end the call or says goodbye, respond with a brief farewell and set action to "end".
If you need to transfer to a human agent, set action to "transfer".
Otherwise, set action to "continue".
"""

    def _load_tools(self) -> list[dict]:
        """Load tool definitions."""
        tools_path = os.environ.get("TOOLS_PATH", "/opt/tools/tool_definitions.json")

        try:
            with open(tools_path) as f:
                data = json.load(f)
                return data.get("tools", [])
        except FileNotFoundError:
            logger.warning(f"Tools file not found at {tools_path}, using defaults")

        return [
            {
                "name": "search_knowledge_base",
                "description": "Search the company knowledge base for information to answer customer questions",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "query": {
                            "type": "string",
                            "description": "The search query based on the customer's question",
                        }
                    },
                    "required": ["query"],
                },
            },
            {
                "name": "lookup_account",
                "description": "Look up customer account information by account ID or phone number",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "account_id": {
                            "type": "string",
                            "description": "The customer account ID or phone number",
                        }
                    },
                    "required": ["account_id"],
                },
            },
            {
                "name": "schedule_appointment",
                "description": "Schedule an appointment for the customer",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "date": {
                            "type": "string",
                            "description": "Appointment date in YYYY-MM-DD format",
                        },
                        "time": {
                            "type": "string",
                            "description": "Appointment time in HH:MM format",
                        },
                        "type": {
                            "type": "string",
                            "description": "Type of appointment",
                        },
                    },
                    "required": ["date", "time", "type"],
                },
            },
            {
                "name": "transfer_to_agent",
                "description": "Transfer the call to a human agent when you cannot help or the customer requests it",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "department": {
                            "type": "string",
                            "description": "Which department to transfer to",
                            "enum": ["sales", "support", "billing", "general"],
                        },
                        "reason": {
                            "type": "string",
                            "description": "Reason for the transfer",
                        },
                    },
                    "required": ["department", "reason"],
                },
            },
        ]

    def generate_response(
        self,
        conversation_history: list[dict],
        context: dict[str, Any],
        session_id: str,
        tool_results: list[dict] | None = None,
    ) -> dict[str, Any]:
        """
        Generate a response using Bedrock.

        Args:
            conversation_history: List of previous conversation messages
            context: Context information for the prompt
            session_id: The session ID for tracking
            tool_results: Results from previous tool calls

        Returns:
            Dictionary with response, action, and optional tool calls
        """
        start_time = time.time()

        try:
            # Build the system prompt with context
            system_prompt = self._build_system_prompt(context)

            # Build messages
            messages = self._build_messages(conversation_history, tool_results)

            # Call Bedrock
            request_body = {
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": self._max_tokens,
                "temperature": self._temperature,
                "system": system_prompt,
                "messages": messages,
            }

            # Add tools if not processing tool results
            if not tool_results and self._tools:
                request_body["tools"] = self._tools

            # Add guardrail if configured
            additional_params = {}
            if self._guardrail_id:
                additional_params["guardrailIdentifier"] = self._guardrail_id
                additional_params["guardrailVersion"] = self._guardrail_version

            if self._streaming:
                response = self._invoke_with_streaming(request_body, additional_params)
            else:
                response = self._invoke_model(request_body, additional_params)

            latency = (time.time() - start_time) * 1000
            logger.info(
                f"Bedrock response generated",
                extra={
                    "latency_ms": latency,
                    "session_id": session_id,
                    "model_id": self._model_id,
                },
            )

            return response

        except ClientError as e:
            error_code = e.response["Error"]["Code"]
            logger.error(f"Bedrock API error: {error_code} - {e}")

            if error_code == "ThrottlingException":
                return {
                    "response": "I'm experiencing high demand right now. Please hold on a moment.",
                    "action": "continue",
                }
            elif error_code == "ModelStreamErrorException":
                return {
                    "response": "I had a brief issue. Could you please repeat that?",
                    "action": "continue",
                }
            else:
                return {
                    "response": "I'm having trouble processing your request. Let me transfer you to an agent.",
                    "action": "transfer",
                }

        except Exception as e:
            logger.error(f"Unexpected error in Bedrock call: {e}", exc_info=True)
            return {
                "response": "I encountered an issue. Let me connect you with someone who can help.",
                "action": "transfer",
            }

    def _build_system_prompt(self, context: dict[str, Any]) -> str:
        """Build the system prompt with context."""
        prompt = self._system_prompt

        # Add context information
        if context.get("company_name"):
            prompt = prompt.replace("{company_name}", context["company_name"])

        if context.get("caller_history"):
            history_summary = f"\n\nCaller History:\nThis caller has had {len(context['caller_history'])} previous interactions."
            prompt += history_summary

        if context.get("current_time"):
            prompt += f"\n\nCurrent time: {context['current_time']}"

        return prompt

    def _build_messages(
        self,
        conversation_history: list[dict],
        tool_results: list[dict] | None = None,
    ) -> list[dict]:
        """Build messages list for Bedrock API."""
        messages = []

        # Add conversation history
        for msg in conversation_history:
            messages.append(msg)

        # Add tool results if present
        if tool_results:
            tool_result_content = []
            for result in tool_results:
                tool_result_content.append({
                    "type": "tool_result",
                    "tool_use_id": result["tool_use_id"],
                    "content": result["content"],
                })

            messages.append({
                "role": "user",
                "content": tool_result_content,
            })

        return messages

    def _invoke_model(
        self,
        request_body: dict,
        additional_params: dict,
    ) -> dict[str, Any]:
        """Invoke Bedrock model without streaming."""
        invoke_params = {
            "modelId": self._model_id,
            "body": json.dumps(request_body),
            "contentType": "application/json",
            "accept": "application/json",
        }
        invoke_params.update(additional_params)

        response = self._client.invoke_model(**invoke_params)

        response_body = json.loads(response["body"].read())

        return self._parse_response(response_body)

    def _invoke_with_streaming(
        self,
        request_body: dict,
        additional_params: dict,
    ) -> dict[str, Any]:
        """Invoke Bedrock model with streaming."""
        invoke_params = {
            "modelId": self._model_id,
            "body": json.dumps(request_body),
            "contentType": "application/json",
            "accept": "application/json",
        }
        invoke_params.update(additional_params)

        response = self._client.invoke_model_with_response_stream(**invoke_params)

        # Process streaming response
        full_response = ""
        tool_calls = []
        stop_reason = None

        for event in response["body"]:
            chunk = json.loads(event["chunk"]["bytes"])

            if chunk["type"] == "content_block_delta":
                if "text" in chunk["delta"]:
                    full_response += chunk["delta"]["text"]
            elif chunk["type"] == "content_block_start":
                if chunk.get("content_block", {}).get("type") == "tool_use":
                    tool_calls.append({
                        "id": chunk["content_block"]["id"],
                        "name": chunk["content_block"]["name"],
                        "input": {},
                    })
            elif chunk["type"] == "message_delta":
                stop_reason = chunk.get("delta", {}).get("stop_reason")

        return self._build_response(full_response, tool_calls, stop_reason)

    def _parse_response(self, response_body: dict) -> dict[str, Any]:
        """Parse non-streaming response from Bedrock."""
        content = response_body.get("content", [])
        stop_reason = response_body.get("stop_reason")

        full_response = ""
        tool_calls = []

        for block in content:
            if block["type"] == "text":
                full_response += block["text"]
            elif block["type"] == "tool_use":
                tool_calls.append({
                    "id": block["id"],
                    "name": block["name"],
                    "input": block["input"],
                })

        return self._build_response(full_response, tool_calls, stop_reason)

    def _build_response(
        self,
        text: str,
        tool_calls: list[dict],
        stop_reason: str | None,
    ) -> dict[str, Any]:
        """Build the final response dictionary."""
        # Determine action from response
        action = "continue"
        text_lower = text.lower()

        if stop_reason == "tool_use" and tool_calls:
            # Check if any tool call is for transfer
            for tc in tool_calls:
                if tc["name"] == "transfer_to_agent":
                    action = "transfer"
                    break
        elif any(
            phrase in text_lower
            for phrase in ["goodbye", "have a great day", "thank you for calling", "take care"]
        ):
            action = "end"
        elif "transfer" in text_lower and "agent" in text_lower:
            action = "transfer"

        return {
            "response": text,
            "action": action,
            "tool_calls": tool_calls,
            "stop_reason": stop_reason,
        }

    def retrieve_from_knowledge_base(
        self,
        knowledge_base_id: str,
        query: str,
        max_results: int = 5,
    ) -> dict[str, Any]:
        """
        Retrieve information from Bedrock Knowledge Base.

        Args:
            knowledge_base_id: The knowledge base ID
            query: The search query
            max_results: Maximum number of results to return

        Returns:
            Dictionary with search results
        """
        try:
            response = self._agent_client.retrieve(
                knowledgeBaseId=knowledge_base_id,
                retrievalQuery={"text": query},
                retrievalConfiguration={
                    "vectorSearchConfiguration": {
                        "numberOfResults": max_results,
                    }
                },
            )

            results = []
            for result in response.get("retrievalResults", []):
                results.append({
                    "content": result.get("content", {}).get("text", ""),
                    "score": result.get("score", 0),
                    "source": result.get("location", {}),
                })

            return {"results": results}

        except ClientError as e:
            logger.error(f"Knowledge base retrieval failed: {e}")
            return {"results": [], "error": str(e)}
