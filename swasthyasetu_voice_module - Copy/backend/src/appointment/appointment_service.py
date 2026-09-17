"""Unified Appointment Service Facade."""

from typing import List, Dict, Any
from sqlalchemy.orm import Session
from fastapi import HTTPException

try:
    from app.models.models import Appointment, DoctorUser, Facility, Patient
    from src.appointment.schemas import (
        AppointmentSearchRequest, AvailableSlot, AppointmentBookingRequest,
        AppointmentBookingResponse, AppointmentCancelRequest, AppointmentRescheduleRequest
    )
    from src.appointment.slot_manager import generate_available_slots
    from src.appointment.booking import book_appointment
    from src.appointment.cancellation import cancel_appointment
    from src.appointment.rescheduling import reschedule_appointment
except ImportError:
    from backend.app.models.models import Appointment, DoctorUser, Facility, Patient
    from backend.src.appointment.schemas import (
        AppointmentSearchRequest, AvailableSlot, AppointmentBookingRequest,
        AppointmentBookingResponse, AppointmentCancelRequest, AppointmentRescheduleRequest
    )
    from backend.src.appointment.slot_manager import generate_available_slots
    from backend.src.appointment.booking import book_appointment
    from backend.src.appointment.cancellation import cancel_appointment
    from backend.src.appointment.rescheduling import reschedule_appointment

class AppointmentService:
    """Service facade for appointment lifecycle management."""

    def search_slots(self, db: Session, request: AppointmentSearchRequest) -> List[AvailableSlot]:
        is_urgent = (request.triage_level or "").upper() == "HIGH_RISK"
        return generate_available_slots(
            db=db,
            specialty=request.specialty,
            target_date=request.preferred_date,
            is_urgent=is_urgent
        )

    def book(self, db: Session, request: AppointmentBookingRequest) -> AppointmentBookingResponse:
        return book_appointment(db, request)

    def get_appointment(self, db: Session, appointment_id: str) -> Dict[str, Any]:
        apt = db.query(Appointment).filter(Appointment.id == appointment_id).first()
        if not apt:
            raise HTTPException(status_code=404, detail="Appointment not found.")

        doc = db.query(DoctorUser).filter(DoctorUser.id == apt.doctor_id).first() if apt.doctor_id else None
        fac = db.query(Facility).filter(Facility.id == apt.facility_id).first() if apt.facility_id else None
        patient = db.query(Patient).filter(Patient.id == apt.patient_id).first() if apt.patient_id else None

        return {
            "appointment_id": apt.id,
            "patient_id": apt.patient_id,
            "patient_name": patient.name if patient else "Patient",
            "doctor_name": (doc.name or doc.username) if doc else "Attending Physician",
            "specialty": doc.speciality if doc else "General Medicine",
            "facility_name": fac.name if fac else "Central Hospital OPD",
            "appointment_time": apt.scheduled_time.strftime("%Y-%m-%d %H:%M") if apt.scheduled_time else None,
            "status": apt.status,
            "notes": apt.notes
        }

    def cancel(self, db: Session, request: AppointmentCancelRequest) -> dict:
        return cancel_appointment(db, request)

    def reschedule(self, db: Session, request: AppointmentRescheduleRequest) -> dict:
        return reschedule_appointment(db, request)

appointment_service = AppointmentService()
