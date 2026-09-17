"""Appointment Booking Engine with Clinical Safety Check."""

import uuid
from datetime import datetime
from sqlalchemy.orm import Session
from fastapi import HTTPException

try:
    from app.models.models import Appointment, Patient, DoctorUser, Facility
    from src.appointment.schemas import AppointmentBookingRequest, AppointmentBookingResponse
    from src.care_pathway.care_pathway import determine_care_pathway
except ImportError:
    from backend.app.models.models import Appointment, Patient, DoctorUser, Facility
    from backend.src.appointment.schemas import AppointmentBookingRequest, AppointmentBookingResponse
    from backend.src.care_pathway.care_pathway import determine_care_pathway

def book_appointment(db: Session, request: AppointmentBookingRequest) -> AppointmentBookingResponse:
    """Executes appointment booking with strict triage safety gating."""
    triage = (request.triage_level or "LOW_RISK").upper()
    pathway = determine_care_pathway(triage)

    # 1. Strict Emergency Safety Gate
    if not pathway.booking_allowed or triage == "EMERGENCY":
        return AppointmentBookingResponse(
            status="BLOCKED_EMERGENCY",
            appointment_id=None,
            patient_id=request.patient_id,
            care_pathway="EMERGENCY_REFERRAL",
            instructions=[
                "Routine booking is strictly prohibited for critical emergency cases.",
                "Seek immediate emergency resuscitation or dial 108/112 ambulance.",
                "Emergency referral generated for nearest emergency facility."
            ]
        )

    # 2. Verify Patient Exists
    patient = db.query(Patient).filter(Patient.id == request.patient_id).first()
    if not patient:
        patient = db.query(Patient).filter(Patient.health_id == request.patient_id).first()
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found in health registry.")

    # 3. Verify Doctor Exists
    doctor = db.query(DoctorUser).filter(DoctorUser.id == request.doctor_id).first()
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor not found.")

    # 4. Verify Facility
    facility_id = request.hospital_id or doctor.facility_id
    facility = db.query(Facility).filter(Facility.id == facility_id).first() if facility_id else None
    fac_name = facility.name if facility else "Central Hospital OPD"

    # 5. Parse Slot Date & Time
    apt_datetime = datetime.utcnow()
    try:
        parts = request.slot_id.split("_")
        if len(parts) >= 4:
            date_str = parts[2]
            time_str = parts[3]
            apt_datetime = datetime.strptime(f"{date_str}_{time_str}", "%Y%m%d_%H%M")
    except Exception:
        pass

    # 6. Create Database Appointment Record
    new_apt = Appointment(
        id=str(uuid.uuid4()),
        patient_id=patient.id,
        doctor_id=doctor.id,
        facility_id=facility.id if facility else None,
        speciality=doctor.speciality or "General Medicine",
        scheduled_time=apt_datetime,
        status="booked",
        source="clinical_ai",
        notes=request.reason or f"Care Pathway: {pathway.care_pathway}"
    )
    db.add(new_apt)
    db.commit()
    db.refresh(new_apt)

    return AppointmentBookingResponse(
        status="CONFIRMED",
        appointment_id=new_apt.id,
        patient_id=patient.id,
        doctor_name=doctor.name or doctor.username,
        facility_name=fac_name,
        specialty=doctor.speciality or "General Medicine",
        appointment_date=apt_datetime.strftime("%Y-%m-%d"),
        appointment_time=apt_datetime.strftime("%H:%M"),
        care_pathway=pathway.care_pathway,
        instructions=pathway.action_instructions
    )
