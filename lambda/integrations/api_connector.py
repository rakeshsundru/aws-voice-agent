"""
API Connector for Voice Agent

Handles external API integrations for the voice agent,
including CRM, scheduling, and other third-party services.
"""

import json
import os
import time
from typing import Any
from urllib.parse import urljoin

import boto3
import requests
from botocore.exceptions import ClientError

import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from utils.logger import get_logger
from utils.error_handler import VoiceAgentError, ToolExecutionError

logger = get_logger(__name__)


class APIConnector:
    """Base class for API connectors."""

    def __init__(
        self,
        base_url: str,
        timeout: int = 5,
        api_key_param: str | None = None,
    ):
        """
        Initialize API connector.

        Args:
            base_url: Base URL for the API
            timeout: Request timeout in seconds
            api_key_param: SSM parameter name for API key
        """
        self.base_url = base_url
        self.timeout = timeout
        self._session = requests.Session()
        self._api_key: str | None = None
        self._api_key_param = api_key_param

        if api_key_param:
            self._load_api_key()

    def _load_api_key(self) -> None:
        """Load API key from SSM Parameter Store."""
        if not self._api_key_param:
            return

        try:
            ssm = boto3.client("ssm")
            response = ssm.get_parameter(
                Name=self._api_key_param,
                WithDecryption=True,
            )
            self._api_key = response["Parameter"]["Value"]
        except ClientError as e:
            logger.error(f"Failed to load API key: {e}")
            raise VoiceAgentError(
                f"Failed to load API key from {self._api_key_param}",
                error_code="CONFIGURATION_ERROR",
            ) from e

    def _get_headers(self) -> dict[str, str]:
        """Get request headers."""
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json",
        }
        if self._api_key:
            headers["Authorization"] = f"Bearer {self._api_key}"
        return headers

    def get(self, endpoint: str, params: dict | None = None) -> dict[str, Any]:
        """
        Make a GET request.

        Args:
            endpoint: API endpoint
            params: Query parameters

        Returns:
            Response data
        """
        url = urljoin(self.base_url, endpoint)
        try:
            response = self._session.get(
                url,
                params=params,
                headers=self._get_headers(),
                timeout=self.timeout,
            )
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            logger.error(f"API GET request failed: {e}")
            raise ToolExecutionError(
                f"API request failed: {e}",
                tool_name="api_connector",
            ) from e

    def post(
        self,
        endpoint: str,
        data: dict[str, Any],
        params: dict | None = None,
    ) -> dict[str, Any]:
        """
        Make a POST request.

        Args:
            endpoint: API endpoint
            data: Request body
            params: Query parameters

        Returns:
            Response data
        """
        url = urljoin(self.base_url, endpoint)
        try:
            response = self._session.post(
                url,
                json=data,
                params=params,
                headers=self._get_headers(),
                timeout=self.timeout,
            )
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            logger.error(f"API POST request failed: {e}")
            raise ToolExecutionError(
                f"API request failed: {e}",
                tool_name="api_connector",
            ) from e


class CRMConnector(APIConnector):
    """Connector for CRM integrations."""

    def __init__(self):
        """Initialize CRM connector."""
        base_url = os.environ.get("CRM_API_URL", "")
        api_key_param = os.environ.get("CRM_API_KEY_PARAM")
        timeout = int(os.environ.get("CRM_TIMEOUT_MS", "5000")) // 1000

        super().__init__(base_url, timeout, api_key_param)

    def lookup_customer(self, identifier: str) -> dict[str, Any]:
        """
        Look up customer by phone number or account ID.

        Args:
            identifier: Phone number or account ID

        Returns:
            Customer data
        """
        if not self.base_url:
            # Return mock data if no CRM configured
            return {
                "found": False,
                "message": "CRM not configured",
            }

        try:
            return self.get(f"/customers/lookup", params={"identifier": identifier})
        except ToolExecutionError:
            return {
                "found": False,
                "error": "Failed to lookup customer",
            }

    def get_customer_history(self, customer_id: str) -> list[dict[str, Any]]:
        """
        Get customer interaction history.

        Args:
            customer_id: Customer ID

        Returns:
            List of previous interactions
        """
        if not self.base_url:
            return []

        try:
            response = self.get(f"/customers/{customer_id}/history")
            return response.get("interactions", [])
        except ToolExecutionError:
            return []

    def create_ticket(
        self,
        customer_id: str,
        subject: str,
        description: str,
        priority: str = "normal",
    ) -> dict[str, Any]:
        """
        Create a support ticket.

        Args:
            customer_id: Customer ID
            subject: Ticket subject
            description: Ticket description
            priority: Ticket priority

        Returns:
            Created ticket data
        """
        if not self.base_url:
            return {
                "ticket_id": f"MOCK-{int(time.time())}",
                "status": "created",
                "message": "CRM not configured - mock ticket created",
            }

        try:
            return self.post(
                "/tickets",
                data={
                    "customer_id": customer_id,
                    "subject": subject,
                    "description": description,
                    "priority": priority,
                    "source": "voice_agent",
                },
            )
        except ToolExecutionError:
            return {
                "error": "Failed to create ticket",
            }


class SchedulingConnector(APIConnector):
    """Connector for scheduling integrations."""

    def __init__(self):
        """Initialize scheduling connector."""
        base_url = os.environ.get("SCHEDULING_API_URL", "")
        api_key_param = os.environ.get("SCHEDULING_API_KEY_PARAM")
        timeout = int(os.environ.get("SCHEDULING_TIMEOUT_MS", "5000")) // 1000

        super().__init__(base_url, timeout, api_key_param)

    def get_available_slots(
        self,
        date: str,
        appointment_type: str,
    ) -> list[dict[str, Any]]:
        """
        Get available appointment slots.

        Args:
            date: Date in YYYY-MM-DD format
            appointment_type: Type of appointment

        Returns:
            List of available time slots
        """
        if not self.base_url:
            # Return mock slots
            return [
                {"time": "09:00", "available": True},
                {"time": "10:00", "available": True},
                {"time": "11:00", "available": False},
                {"time": "14:00", "available": True},
                {"time": "15:00", "available": True},
            ]

        try:
            response = self.get(
                "/slots",
                params={"date": date, "type": appointment_type},
            )
            return response.get("slots", [])
        except ToolExecutionError:
            return []

    def book_appointment(
        self,
        customer_id: str,
        date: str,
        time_slot: str,
        appointment_type: str,
        notes: str = "",
    ) -> dict[str, Any]:
        """
        Book an appointment.

        Args:
            customer_id: Customer ID
            date: Appointment date
            time_slot: Appointment time
            appointment_type: Type of appointment
            notes: Additional notes

        Returns:
            Booking confirmation
        """
        if not self.base_url:
            return {
                "appointment_id": f"APT-{int(time.time())}",
                "date": date,
                "time": time_slot,
                "type": appointment_type,
                "status": "confirmed",
                "message": "Mock appointment booked",
            }

        try:
            return self.post(
                "/appointments",
                data={
                    "customer_id": customer_id,
                    "date": date,
                    "time": time_slot,
                    "type": appointment_type,
                    "notes": notes,
                    "source": "voice_agent",
                },
            )
        except ToolExecutionError:
            return {
                "error": "Failed to book appointment",
            }

    def cancel_appointment(self, appointment_id: str) -> dict[str, Any]:
        """
        Cancel an appointment.

        Args:
            appointment_id: Appointment ID

        Returns:
            Cancellation confirmation
        """
        if not self.base_url:
            return {
                "appointment_id": appointment_id,
                "status": "cancelled",
                "message": "Mock appointment cancelled",
            }

        try:
            return self.post(f"/appointments/{appointment_id}/cancel", data={})
        except ToolExecutionError:
            return {
                "error": "Failed to cancel appointment",
            }


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """
    Lambda handler for integration operations.

    Args:
        event: Lambda event
        context: Lambda context

    Returns:
        Integration response
    """
    logger.info("Processing integration request", extra={"event": event})

    operation = event.get("operation", "")
    parameters = event.get("parameters", {})

    try:
        if operation == "crm_lookup":
            crm = CRMConnector()
            result = crm.lookup_customer(parameters.get("identifier", ""))
        elif operation == "crm_history":
            crm = CRMConnector()
            result = crm.get_customer_history(parameters.get("customer_id", ""))
        elif operation == "crm_ticket":
            crm = CRMConnector()
            result = crm.create_ticket(
                customer_id=parameters.get("customer_id", ""),
                subject=parameters.get("subject", "Voice Agent Ticket"),
                description=parameters.get("description", ""),
                priority=parameters.get("priority", "normal"),
            )
        elif operation == "schedule_slots":
            scheduler = SchedulingConnector()
            result = scheduler.get_available_slots(
                date=parameters.get("date", ""),
                appointment_type=parameters.get("type", "general"),
            )
        elif operation == "schedule_book":
            scheduler = SchedulingConnector()
            result = scheduler.book_appointment(
                customer_id=parameters.get("customer_id", ""),
                date=parameters.get("date", ""),
                time_slot=parameters.get("time", ""),
                appointment_type=parameters.get("type", "general"),
                notes=parameters.get("notes", ""),
            )
        elif operation == "schedule_cancel":
            scheduler = SchedulingConnector()
            result = scheduler.cancel_appointment(
                appointment_id=parameters.get("appointment_id", ""),
            )
        else:
            result = {"error": f"Unknown operation: {operation}"}

        return {
            "statusCode": 200,
            "body": json.dumps(result),
        }

    except Exception as e:
        logger.error(f"Integration error: {e}", exc_info=True)
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)}),
        }
