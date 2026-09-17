"""SwasthyaSetu Appointment Package."""

from src.appointment.schemas import (
    AppointmentSearchRequest, AvailableSlot, AppointmentBookingRequest,
    AppointmentBookingResponse, AppointmentCancelRequest, AppointmentRescheduleRequest,
    HospitalInfo, DoctorInfo
)
from src.appointment.appointment_service import AppointmentService, appointment_service
from src.appointment.specialty_mapping import resolve_specialty_for_symptoms, update_specialty_mapping
from src.appointment.hospital_search import search_hospitals, get_hospital_by_id
from src.appointment.doctor_search import search_doctors, get_doctor_by_id
from src.appointment.slot_manager import generate_available_slots
from src.appointment.booking import book_appointment
from src.appointment.cancellation import cancel_appointment
from src.appointment.rescheduling import reschedule_appointment

__all__ = [
    "AppointmentSearchRequest",
    "AvailableSlot",
    "AppointmentBookingRequest",
    "AppointmentBookingResponse",
    "AppointmentCancelRequest",
    "AppointmentRescheduleRequest",
    "HospitalInfo",
    "DoctorInfo",
    "AppointmentService",
    "appointment_service",
    "resolve_specialty_for_symptoms",
    "update_specialty_mapping",
    "search_hospitals",
    "get_hospital_by_id",
    "search_doctors",
    "get_doctor_by_id",
    "generate_available_slots",
    "book_appointment",
    "cancel_appointment",
    "reschedule_appointment"
]
