"""
Error handling utilities for Voice Agent Lambda functions.

Provides custom exceptions and error handling logic.
"""

import os
import traceback
from typing import Any

from logger import get_logger

logger = get_logger(__name__)


class VoiceAgentError(Exception):
    """Base exception for voice agent errors."""

    def __init__(
        self,
        message: str,
        error_code: str = "UNKNOWN_ERROR",
        recoverable: bool = True,
        details: dict[str, Any] | None = None,
    ):
        """
        Initialize voice agent error.

        Args:
            message: Error message
            error_code: Error code for categorization
            recoverable: Whether the error is recoverable
            details: Additional error details
        """
        super().__init__(message)
        self.message = message
        self.error_code = error_code
        self.recoverable = recoverable
        self.details = details or {}

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary."""
        return {
            "error_code": self.error_code,
            "message": self.message,
            "recoverable": self.recoverable,
            "details": self.details,
        }


class SessionError(VoiceAgentError):
    """Error related to session management."""

    def __init__(self, message: str, **kwargs):
        super().__init__(message, error_code="SESSION_ERROR", **kwargs)


class BedrockError(VoiceAgentError):
    """Error related to Bedrock API calls."""

    def __init__(self, message: str, **kwargs):
        super().__init__(message, error_code="BEDROCK_ERROR", **kwargs)


class NeptuneError(VoiceAgentError):
    """Error related to Neptune database."""

    def __init__(self, message: str, **kwargs):
        super().__init__(message, error_code="NEPTUNE_ERROR", **kwargs)


class TranscriptionError(VoiceAgentError):
    """Error related to speech transcription."""

    def __init__(self, message: str, **kwargs):
        super().__init__(message, error_code="TRANSCRIPTION_ERROR", **kwargs)


class ToolExecutionError(VoiceAgentError):
    """Error related to tool execution."""

    def __init__(self, message: str, tool_name: str = "", **kwargs):
        details = kwargs.pop("details", {})
        details["tool_name"] = tool_name
        super().__init__(
            message,
            error_code="TOOL_EXECUTION_ERROR",
            details=details,
            **kwargs,
        )


class ConfigurationError(VoiceAgentError):
    """Error related to configuration."""

    def __init__(self, message: str, **kwargs):
        super().__init__(
            message,
            error_code="CONFIGURATION_ERROR",
            recoverable=False,
            **kwargs,
        )


class RateLimitError(VoiceAgentError):
    """Error when rate limit is exceeded."""

    def __init__(self, message: str = "Rate limit exceeded", **kwargs):
        super().__init__(
            message,
            error_code="RATE_LIMIT_ERROR",
            recoverable=True,
            **kwargs,
        )


def handle_error(
    error: Exception,
    request_id: str,
    context: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """
    Handle an error and return appropriate response.

    Args:
        error: The exception that occurred
        request_id: Request ID for tracking
        context: Additional context for error handling

    Returns:
        Response dictionary with error handling
    """
    context = context or {}

    # Log the error
    logger.error(
        f"Error occurred: {error}",
        extra={
            "request_id": request_id,
            "error_type": type(error).__name__,
            "traceback": traceback.format_exc(),
            **context,
        },
    )

    # Determine response based on error type
    if isinstance(error, VoiceAgentError):
        return _handle_voice_agent_error(error)
    elif isinstance(error, TimeoutError):
        return _handle_timeout_error()
    else:
        return _handle_unexpected_error(error)


def _handle_voice_agent_error(error: VoiceAgentError) -> dict[str, Any]:
    """Handle a VoiceAgentError."""
    if error.recoverable:
        if error.error_code == "RATE_LIMIT_ERROR":
            return {
                "response": "I'm experiencing high demand right now. Please try again in a moment.",
                "action": "continue",
                "error": error.to_dict(),
            }
        elif error.error_code == "BEDROCK_ERROR":
            return {
                "response": "I had trouble processing that. Could you please rephrase?",
                "action": "continue",
                "error": error.to_dict(),
            }
        elif error.error_code == "NEPTUNE_ERROR":
            # Neptune errors shouldn't block the conversation
            return {
                "response": "Let me help you with that.",
                "action": "continue",
                "error": error.to_dict(),
            }
        else:
            return {
                "response": "I encountered a brief issue. Please continue.",
                "action": "continue",
                "error": error.to_dict(),
            }
    else:
        # Non-recoverable error - transfer to agent
        return {
            "response": "I'm having technical difficulties. Let me connect you with someone who can help.",
            "action": "transfer",
            "error": error.to_dict(),
        }


def _handle_timeout_error() -> dict[str, Any]:
    """Handle a timeout error."""
    return {
        "response": "I'm taking longer than expected. Let me try a different approach.",
        "action": "continue",
        "error": {
            "error_code": "TIMEOUT_ERROR",
            "message": "Operation timed out",
            "recoverable": True,
        },
    }


def _handle_unexpected_error(error: Exception) -> dict[str, Any]:
    """Handle an unexpected error."""
    # Don't expose internal error details to users
    return {
        "response": "I apologize, but I'm experiencing technical issues. Let me transfer you to someone who can assist.",
        "action": "transfer",
        "error": {
            "error_code": "INTERNAL_ERROR",
            "message": "An unexpected error occurred",
            "recoverable": False,
        },
    }


def with_error_handling(func):
    """
    Decorator for error handling.

    Wraps a function with error handling and logging.
    """

    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except VoiceAgentError:
            raise
        except Exception as e:
            logger.error(
                f"Unhandled error in {func.__name__}: {e}",
                extra={"traceback": traceback.format_exc()},
            )
            raise VoiceAgentError(
                message=str(e),
                error_code="UNHANDLED_ERROR",
                recoverable=False,
                details={"original_error": type(e).__name__},
            ) from e

    return wrapper


def validate_required_env_vars(var_names: list[str]) -> None:
    """
    Validate that required environment variables are set.

    Args:
        var_names: List of required environment variable names

    Raises:
        ConfigurationError: If any required variable is missing
    """
    missing = [name for name in var_names if not os.environ.get(name)]

    if missing:
        raise ConfigurationError(
            f"Missing required environment variables: {', '.join(missing)}",
            details={"missing_vars": missing},
        )
