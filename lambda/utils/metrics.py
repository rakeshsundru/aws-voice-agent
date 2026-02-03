"""
Metrics utilities for Voice Agent Lambda functions.

Provides CloudWatch metrics publishing for monitoring.
"""

import os
import time
from typing import Any

import boto3
from botocore.exceptions import ClientError

from logger import get_logger

logger = get_logger(__name__)


class MetricsPublisher:
    """Publishes custom metrics to CloudWatch."""

    def __init__(self, namespace: str | None = None):
        """
        Initialize metrics publisher.

        Args:
            namespace: CloudWatch namespace (defaults to VoiceAgent)
        """
        self._client = boto3.client("cloudwatch")
        self._namespace = namespace or os.environ.get("METRICS_NAMESPACE", "VoiceAgent")
        self._environment = os.environ.get("ENVIRONMENT", "dev")
        self._buffer: list[dict] = []
        self._buffer_size = int(os.environ.get("METRICS_BUFFER_SIZE", "20"))
        self._enabled = os.environ.get("METRICS_ENABLED", "true").lower() == "true"

    def publish_latency(
        self,
        operation: str,
        latency_ms: float,
        dimensions: dict[str, str] | None = None,
    ) -> None:
        """
        Publish a latency metric.

        Args:
            operation: Name of the operation
            latency_ms: Latency in milliseconds
            dimensions: Additional dimensions
        """
        self._publish_metric(
            metric_name=operation,
            value=latency_ms,
            unit="Milliseconds",
            dimensions=dimensions,
        )

    def publish_count(
        self,
        metric_name: str,
        count: int = 1,
        dimensions: dict[str, str] | None = None,
    ) -> None:
        """
        Publish a count metric.

        Args:
            metric_name: Name of the metric
            count: Count value
            dimensions: Additional dimensions
        """
        self._publish_metric(
            metric_name=metric_name,
            value=count,
            unit="Count",
            dimensions=dimensions,
        )

    def publish_error(
        self,
        error_type: str,
        dimensions: dict[str, str] | None = None,
    ) -> None:
        """
        Publish an error metric.

        Args:
            error_type: Type of error
            dimensions: Additional dimensions
        """
        dims = dimensions or {}
        dims["ErrorType"] = error_type

        self._publish_metric(
            metric_name="Errors",
            value=1,
            unit="Count",
            dimensions=dims,
        )

    def publish_call_metrics(
        self,
        duration_seconds: float,
        turn_count: int,
        contained: bool,
    ) -> None:
        """
        Publish call-level metrics.

        Args:
            duration_seconds: Call duration
            turn_count: Number of conversation turns
            contained: Whether the call was contained (not transferred)
        """
        # Call duration
        self._publish_metric(
            metric_name="CallDuration",
            value=duration_seconds,
            unit="Seconds",
        )

        # Turn count
        self._publish_metric(
            metric_name="TurnCount",
            value=turn_count,
            unit="Count",
        )

        # Containment
        self._publish_metric(
            metric_name="ContainedCalls" if contained else "TransferredCalls",
            value=1,
            unit="Count",
        )

    def _publish_metric(
        self,
        metric_name: str,
        value: float,
        unit: str,
        dimensions: dict[str, str] | None = None,
    ) -> None:
        """
        Publish a single metric.

        Args:
            metric_name: Name of the metric
            value: Metric value
            unit: Metric unit
            dimensions: Additional dimensions
        """
        if not self._enabled:
            return

        # Build dimensions
        metric_dimensions = [{"Name": "Environment", "Value": self._environment}]

        if dimensions:
            for name, dim_value in dimensions.items():
                metric_dimensions.append({"Name": name, "Value": dim_value})

        metric_data = {
            "MetricName": metric_name,
            "Value": value,
            "Unit": unit,
            "Dimensions": metric_dimensions,
            "Timestamp": time.time(),
        }

        self._buffer.append(metric_data)

        # Flush if buffer is full
        if len(self._buffer) >= self._buffer_size:
            self.flush()

    def flush(self) -> None:
        """Flush buffered metrics to CloudWatch."""
        if not self._buffer:
            return

        try:
            # CloudWatch allows max 1000 metrics per request
            for i in range(0, len(self._buffer), 1000):
                batch = self._buffer[i : i + 1000]
                self._client.put_metric_data(
                    Namespace=self._namespace,
                    MetricData=batch,
                )

            logger.debug(f"Flushed {len(self._buffer)} metrics to CloudWatch")
            self._buffer = []

        except ClientError as e:
            logger.warning(f"Failed to publish metrics: {e}")
            # Don't clear buffer on failure - try again next time
            # But limit buffer size to prevent memory issues
            if len(self._buffer) > 1000:
                self._buffer = self._buffer[-1000:]

    def __del__(self):
        """Flush remaining metrics on cleanup."""
        try:
            self.flush()
        except Exception:
            pass


class MetricsContext:
    """Context manager for collecting metrics."""

    def __init__(
        self,
        publisher: MetricsPublisher,
        operation: str,
        dimensions: dict[str, str] | None = None,
    ):
        """
        Initialize metrics context.

        Args:
            publisher: Metrics publisher instance
            operation: Operation name
            dimensions: Additional dimensions
        """
        self.publisher = publisher
        self.operation = operation
        self.dimensions = dimensions
        self.start_time: float | None = None
        self.success = True
        self.error_type: str | None = None

    def __enter__(self) -> "MetricsContext":
        """Start collecting metrics."""
        self.start_time = time.time()
        self.publisher.publish_count(
            f"{self.operation}Started",
            dimensions=self.dimensions,
        )
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> None:
        """Finish collecting metrics."""
        if self.start_time:
            latency_ms = (time.time() - self.start_time) * 1000
            self.publisher.publish_latency(
                f"{self.operation}Latency",
                latency_ms,
                dimensions=self.dimensions,
            )

        if exc_type:
            self.success = False
            self.error_type = exc_type.__name__
            self.publisher.publish_error(
                self.error_type,
                dimensions=self.dimensions,
            )
        else:
            self.publisher.publish_count(
                f"{self.operation}Completed",
                dimensions=self.dimensions,
            )

    def mark_error(self, error_type: str) -> None:
        """Mark an error occurred without raising."""
        self.success = False
        self.error_type = error_type
        self.publisher.publish_error(error_type, dimensions=self.dimensions)


# Global metrics publisher instance
_metrics_publisher: MetricsPublisher | None = None


def get_metrics_publisher() -> MetricsPublisher:
    """Get the global metrics publisher instance."""
    global _metrics_publisher
    if _metrics_publisher is None:
        _metrics_publisher = MetricsPublisher()
    return _metrics_publisher
