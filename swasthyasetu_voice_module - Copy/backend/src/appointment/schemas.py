"""Pydantic schemas for appointment search, booking, cancellation, and rescheduling."""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import date

class AppointmentSearchRequest(BaseModel):
    specialty: Optional[str] = None
    facility_id: Optional[str] = None
    district: Optional[str] = None
    pincode: Optional[str] = None
    preferred_date: Optional[date] = None
    triage_level: Optional[str] = "LOW_RISK"

class HospitalInfo(BaseModel):
    id: str
    name: str
    facility_type: str
    district: str
    address: Optional[str] = None
    emergency_capable: bool = False
    phone: Optional[str] = None

class DoctorInfo(BaseModel):
    id: str
    name: str
    specialty: str
    facility_id: str
    facility_name: Optional[str] = None
    is_active: bool = True

class AvailableSlot(BaseModel):
    slot_id: str
    doctor_id: str
    doctor_name: str
    facility_id: str
    facility_name: str
    specialty: str
    date: str
    start_time: str
    end_time: str
    urgency_tier: str = "routine"  # routine, urgent

class AppointmentBookingRequest(BaseModel):
    patient_id: str
    hospital_id: str
    doctor_id: str
    slot_id: str
    triage_level: Optional[str] = "LOW_RISK"
    reason: Optional[str] = None

class AppointmentBookingResponse(BaseModel):
    status: str  # CONFIRMED, BLOCKED_EMERGENCY, FAILED
    appointment_id: Optional[str] = None
    patient_id: str
    doctor_name: Optional[str] = None
    facility_name: Optional[str] = None
    specialty: Optional[str] = None
    appointment_date: Optional[str] = None
    appointment_time: Optional[str] = None
    care_pathway: str
    instructions: List[str] = Field(default_factory=list)

class AppointmentCancelRequest(BaseModel):
    appointment_id: str
    reason: Optional[str] = None

class AppointmentRescheduleRequest(BaseModel):
    appointment_id: str
    new_slot_id: str
    preferred_date: Optional[str] = None
