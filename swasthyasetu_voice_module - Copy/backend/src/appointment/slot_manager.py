"""Real consultation slot manager linked to active doctors and existing bookings."""

from datetime import date, datetime, timedelta
from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.models import DoctorUser, Facility, Appointment
from src.appointment.schemas import AvailableSlot

SLOT_HOURS = [
    ("09:00", "09:30"),
    ("09:30", "10:00"),
    ("10:00", "10:30"),
    ("10:30", "11:00"),
    ("11:30", "12:00"),
    ("14:00", "14:30"),
    ("14:30", "15:00"),
    ("15:00", "15:30"),
    ("16:00", "16:30")
]

def generate_available_slots(
    db: Session,
    doctor_id: Optional[str] = None,
    specialty: Optional[str] = None,
    target_date: Optional[date] = None,
    is_urgent: bool = False
) -> List[AvailableSlot]:
    """Computes real available slots for active doctors, excluding already booked appointment slots."""
    if target_date is None:
        target_date = date.today() if is_urgent else (date.today() + timedelta(days=1))

    date_str = target_date.isoformat()

    # Query doctors
    query = db.query(DoctorUser).filter(DoctorUser.is_active == True)
    if doctor_id:
        query = query.filter(DoctorUser.id == doctor_id)
    if specialty:
        query = query.filter(DoctorUser.speciality.ilike(f"%{specialty}%"))

    doctors = query.all()
    if not doctors:
        return []

    # Map facilities
    facility_ids = [d.facility_id for d in doctors if d.facility_id]
    fac_map = {}
    if facility_ids:
        facs = db.query(Facility).filter(Facility.id.in_(facility_ids)).all()
        fac_map = {f.id: f.name for f in facs}

    # Query already scheduled appointments on this date
    start_dt = datetime.combine(target_date, datetime.min.time())
    end_dt = datetime.combine(target_date, datetime.max.time())

    booked_appointments = db.query(Appointment).filter(
        Appointment.scheduled_time >= start_dt,
        Appointment.scheduled_time <= end_dt,
        Appointment.status.in_(["booked", "completed"])
    ).all()

    booked_slot_keys = {
        f"{apt.doctor_id}_{apt.scheduled_time.strftime('%H:%M')}"
        for apt in booked_appointments
        if apt.doctor_id and apt.scheduled_time
    }

    available_slots: List[AvailableSlot] = []

    for d in doctors:
        f_name = fac_map.get(d.facility_id, "Central Hospital OPD")
        for start_t, end_t in SLOT_HOURS:
            slot_key = f"{d.id}_{start_t}"
            if slot_key not in booked_slot_keys:
                clean_slot_id = f"SLOT_{d.id[:8]}_{target_date.strftime('%Y%m%d')}_{start_t.replace(':', '')}"
                available_slots.append(AvailableSlot(
                    slot_id=clean_slot_id,
                    doctor_id=d.id,
                    doctor_name=d.name or d.username,
                    facility_id=d.facility_id or "",
                    facility_name=f_name,
                    specialty=d.speciality or "General Medicine",
                    date=date_str,
                    start_time=start_t,
                    end_time=end_t,
                    urgency_tier="urgent" if is_urgent else "routine"
                ))

    return available_slots
