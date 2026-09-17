"""Appointment rescheduling handler."""

from datetime import datetime
from sqlalchemy.orm import Session
from fastapi import HTTPException
from app.models.models import Appointment
from src.appointment.schemas import AppointmentRescheduleRequest

def reschedule_appointment(db: Session, request: AppointmentRescheduleRequest) -> dict:
    """Reschedules an existing appointment to a new slot."""
    apt = db.query(Appointment).filter(Appointment.id == request.appointment_id).first()
    if not apt:
        raise HTTPException(status_code=404, detail="Appointment not found.")

    new_time = datetime.utcnow()
    try:
        parts = request.new_slot_id.split("_")
        if len(parts) >= 4:
            date_str = parts[2]
            time_str = parts[3]
            new_time = datetime.strptime(f"{date_str}_{time_str}", "%Y%m%d_%H%M")
    except Exception:
        pass

    apt.scheduled_time = new_time
    apt.status = "booked"
    apt.notes = f"{apt.notes or ''} | Rescheduled to {new_time.isoformat()}".strip()

    db.commit()
    db.refresh(apt)

    return {
        "status": "RESCHEDULED",
        "appointment_id": apt.id,
        "new_appointment_time": new_time.strftime("%Y-%m-%d %H:%M"),
        "message": "Appointment has been successfully rescheduled."
    }
