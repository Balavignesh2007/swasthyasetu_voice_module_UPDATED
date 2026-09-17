"""Doctor search querying real database records."""

from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.models import DoctorUser, Facility
from src.appointment.schemas import DoctorInfo

def search_doctors(
    db: Session,
    specialty: Optional[str] = None,
    facility_id: Optional[str] = None,
    active_only: bool = True
) -> List[DoctorInfo]:
    """Queries registered doctors from database."""
    query = db.query(DoctorUser)

    if active_only:
        query = query.filter(DoctorUser.is_active == True)

    if facility_id:
        query = query.filter(DoctorUser.facility_id == facility_id)

    if specialty:
        query = query.filter(DoctorUser.speciality.ilike(f"%{specialty}%"))

    doctors = query.all()
    results: List[DoctorInfo] = []

    # Map facility names
    facility_ids = [d.facility_id for d in doctors if d.facility_id]
    fac_map = {}
    if facility_ids:
        facs = db.query(Facility).filter(Facility.id.in_(facility_ids)).all()
        fac_map = {f.id: f.name for f in facs}

    for d in doctors:
        results.append(DoctorInfo(
            id=d.id,
            name=d.name or d.username,
            specialty=d.speciality or "General Medicine",
            facility_id=d.facility_id or "",
            facility_name=fac_map.get(d.facility_id, "Main Clinic"),
            is_active=bool(d.is_active)
        ))
    return results

def get_doctor_by_id(db: Session, doctor_id: str) -> Optional[DoctorInfo]:
    """Retrieves single doctor by ID."""
    d = db.query(DoctorUser).filter(DoctorUser.id == doctor_id).first()
    if not d:
        return None
    fac_name = "Main Clinic"
    if d.facility_id:
        f = db.query(Facility).filter(Facility.id == d.facility_id).first()
        if f:
            fac_name = f.name
    return DoctorInfo(
        id=d.id,
        name=d.name or d.username,
        specialty=d.speciality or "General Medicine",
        facility_id=d.facility_id or "",
        facility_name=fac_name,
        is_active=bool(d.is_active)
    )
