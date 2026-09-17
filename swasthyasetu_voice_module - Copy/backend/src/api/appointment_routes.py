"""Standard Appointment Endpoints Router."""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List

try:
    from app.database.database import get_db
    from src.appointment.schemas import (
        AppointmentSearchRequest, AvailableSlot, AppointmentBookingRequest,
        AppointmentBookingResponse, AppointmentCancelRequest, AppointmentRescheduleRequest
    )
    from src.appointment.appointment_service import appointment_service
except ImportError:
    from backend.app.database.database import get_db
    from backend.src.appointment.schemas import (
        AppointmentSearchRequest, AvailableSlot, AppointmentBookingRequest,
        AppointmentBookingResponse, AppointmentCancelRequest, AppointmentRescheduleRequest
    )
    from backend.src.appointment.appointment_service import appointment_service

router = APIRouter(prefix="/api/appointments", tags=["Appointments Management"])

@router.post("/search", response_model=List[AvailableSlot])
def search_available_appointment_slots(request: AppointmentSearchRequest, db: Session = Depends(get_db)):
    """Search for real consultation slots for doctors & facilities."""
    return appointment_service.search_slots(db, request)

@router.post("/book", response_model=AppointmentBookingResponse)
def book_new_appointment(request: AppointmentBookingRequest, db: Session = Depends(get_db)):
    """Books appointment with clinical triage safety gating."""
    return appointment_service.book(db, request)

@router.get("/{appointment_id}")
def get_appointment_details(appointment_id: str, db: Session = Depends(get_db)):
    """Retrieves full details of a specific appointment."""
    return appointment_service.get_appointment(db, appointment_id)

@router.post("/cancel")
def cancel_existing_appointment(request: AppointmentCancelRequest, db: Session = Depends(get_db)):
    """Cancels a scheduled appointment."""
    return appointment_service.cancel(db, request)

@router.post("/reschedule")
def reschedule_existing_appointment(request: AppointmentRescheduleRequest, db: Session = Depends(get_db)):
    """Reschedules an appointment to a new slot."""
    return appointment_service.reschedule(db, request)
