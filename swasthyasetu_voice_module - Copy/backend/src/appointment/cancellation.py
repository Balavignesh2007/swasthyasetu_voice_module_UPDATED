"""Appointment cancellation handler."""

from sqlalchemy.orm import Session
from fastapi import HTTPException
from app.models.models import Appointment
from src.appointment.schemas import AppointmentCancelRequest

def cancel_appointment(db: Session, request: AppointmentCancelRequest) -> dict:
    """Cancels a scheduled appointment record."""
    apt = db.query(Appointment).filter(Appointment.id == request.appointment_id).first()
    if not apt:
        raise HTTPException(status_code=404, detail="Appointment not found.")

    apt.status = "cancelled"
    if request.reason:
        apt.notes = f"{apt.notes or ''} | Cancellation reason: {request.reason}".strip()

    db.commit()
    return {
        "status": "CANCELLED",
        "appointment_id": apt.id,
        "message": "Appointment has been successfully cancelled."
    }
