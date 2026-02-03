"""
Logging utilities for Voice Agent Lambda functions.

Provides structured logging with JSON output for CloudWatch integration.
"""

import json
import logging
import os
import sys
import time
from typing import Any


class JSONFormatter(logging.Formatter):
    """Custom formatter that outputs JSON for CloudWatch Logs Insights."""

    def format(self, record: logging.LogRecord) -> str:
        """Format log record as JSON."""
        log_data = {
            "timestamp": self.formatTime(record, self.datefmt),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "function": record.funcName,
            "line": record.lineno,
        }

        # Add extra fields
        if hasattr(record, "__dict__"):
            for key, value in record.__dict__.items():
                if key not in (
                    "name",
                    "msg",
                    "args",
                    "created",
                    "filename",
                    "funcName",
                    "levelname",
                    "levelno",
                    "lineno",
                    "module",
                    "msecs",
                    "pathname",
                    "process",
                    "processName",
                    "relativeCreated",
                    "stack_info",
                    "exc_info",
                    "exc_text",
                    "thread",
                    "threadName",
                    "message",
                ):
                    log_data[key] = value

        # Add exception info if present
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)

        return json.dumps(log_data, default=str)


def get_logger(name: str) -> logging.Logger:
    """
    Get a configured logger instance.

    Args:
        name: The logger name (typically __name__)

    Returns:
        Configured logger instance
    """
    logger = logging.getLogger(name)

    # Avoid adding handlers multiple times
    if not logger.handlers:
        log_level = os.environ.get("LOG_LEVEL", "INFO").upper()
        logger.setLevel(getattr(logging, log_level, logging.INFO))

        # Create handler
        handler = logging.StreamHandler(sys.stdout)
        handler.setLevel(logger.level)

        # Use JSON formatter for production, readable format for local dev
        if os.environ.get("AWS_LAMBDA_FUNCTION_NAME"):
            formatter = JSONFormatter()
        else:
            formatter = logging.Formatter(
                "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
            )

        handler.setFormatter(formatter)
        logger.addHandler(handler)

        # Prevent propagation to root logger
        logger.propagate = False

    return logger


def log_latency(operation: str, latency_ms: float) -> None:
    """
    Log latency metrics for monitoring.

    Args:
        operation: Name of the operation
        latency_ms: Latency in milliseconds
    """
    logger = get_logger("latency")
    logger.info(
        f"Latency measurement",
        extra={
            "metric_type": "latency",
            "operation": operation,
            "latency_ms": latency_ms,
        },
    )


def log_event(event_type: str, details: dict[str, Any]) -> None:
    """
    Log a structured event.

    Args:
        event_type: Type of event
        details: Event details
    """
    logger = get_logger("events")
    logger.info(
        f"Event: {event_type}",
        extra={
            "event_type": event_type,
            **details,
        },
    )


class LatencyTracker:
    """Context manager for tracking operation latency."""

    def __init__(self, operation: str, auto_log: bool = True):
        """
        Initialize latency tracker.

        Args:
            operation: Name of the operation
            auto_log: Whether to automatically log on exit
        """
        self.operation = operation
        self.auto_log = auto_log
        self.start_time: float | None = None
        self.end_time: float | None = None

    def __enter__(self) -> "LatencyTracker":
        """Start tracking."""
        self.start_time = time.time()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> None:
        """Stop tracking and optionally log."""
        self.end_time = time.time()
        if self.auto_log:
            log_latency(self.operation, self.latency_ms)

    @property
    def latency_ms(self) -> float:
        """Get latency in milliseconds."""
        if self.start_time is None:
            return 0.0
        end = self.end_time or time.time()
        return (end - self.start_time) * 1000
