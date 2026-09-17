"""WebSocket Connection Manager for Real-Time SwasthyaSetu Telephony & Alerts.

Enables live broadcasting of incoming call triage events, emergency alerts,
and ASHA notifications directly to connected web dashboard clients.
"""

import asyncio
import json
import logging
from datetime import datetime
from typing import List, Dict, Any, Optional
from fastapi import WebSocket

logger = logging.getLogger(__name__)


class AlertConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        logger.info(f"WebSocket client connected. Active connections: {len(self.active_connections)}")

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
            logger.info(f"WebSocket client disconnected. Remaining: {len(self.active_connections)}")

    async def broadcast(self, message: Dict[str, Any]):
        """Send JSON message to all active WebSocket connections."""
        if not self.active_connections:
            return

        payload = json.dumps(message)
        disconnected = []

        for connection in self.active_connections:
            try:
                await connection.send_text(payload)
            except Exception as e:
                logger.warning(f"Failed to send to WebSocket client: {e}")
                disconnected.append(connection)

        for conn in disconnected:
            self.disconnect(conn)

    def broadcast_sync(self, message: Dict[str, Any]):
        """Thread-safe and sync-friendly helper to broadcast from non-async route handlers."""
        try:
            loop = asyncio.get_running_loop()
            loop.create_task(self.broadcast(message))
        except RuntimeError:
            # No running event loop in thread; create one
            asyncio.run(self.broadcast(message))

    def broadcast_emergency_alert(
        self,
        alert_id: str,
        red_flag_type: str,
        severity: str = "HIGH",
        status: str = "UNACKNOWLEDGED",
        call_session_id: Optional[str] = None,
        patient_id: Optional[str] = None,
        patient_name: Optional[str] = None,
        patient_phone: Optional[str] = None,
        patient_village: Optional[str] = "Central Village",
        symptoms: Optional[str] = None,
        risk_score: Optional[int] = 90,
        assigned_asha_id: Optional[str] = None,
        created_at: Optional[str] = None
    ):
        """Broadcasts a structured EMERGENCY_ALERT event to all connected dashboards."""
        data = {
            "type": "EMERGENCY_ALERT",
            "alert": {
                "id": alert_id,
                "call_session_id": call_session_id,
                "patient_id": patient_id,
                "patient_name": patient_name or "Emergency Caller",
                "patient_phone": patient_phone or "+919121458655",
                "patient_village": patient_village or "Central Village",
                "red_flag_type": red_flag_type,
                "severity": severity,
                "status": status,
                "symptoms": symptoms or red_flag_type,
                "risk_score": risk_score or 90,
                "assigned_asha_id": assigned_asha_id,
                "notes": f"TwiML IVR Call Alert: {red_flag_type}",
                "created_at": created_at or datetime.utcnow().isoformat()
            }
        }
        logger.info(f"Broadcasting EMERGENCY_ALERT for event {alert_id} over WebSocket")
        self.broadcast_sync(data)


# Global singleton instance
websocket_manager = AlertConnectionManager()
