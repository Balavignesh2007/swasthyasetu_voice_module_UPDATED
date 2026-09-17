"""Hospital and healthcare facility search querying real database records."""

from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.models import Facility
from src.appointment.schemas import HospitalInfo

def search_hospitals(
    db: Session,
    district: Optional[str] = None,
    facility_type: Optional[str] = None,
    emergency_only: bool = False
) -> List[HospitalInfo]:
    """Queries real facility database records."""
    query = db.query(Facility)

    if district:
        query = query.filter(Facility.district.ilike(f"%{district}%"))

    if facility_type:
        query = query.filter(Facility.facility_type.ilike(f"%{facility_type}%"))

    if emergency_only:
        query = query.filter(Facility.emergency_capable == True)

    facilities = query.all()
    results: List[HospitalInfo] = []
    for f in facilities:
        results.append(HospitalInfo(
            id=f.id,
            name=f.name,
            facility_type=f.facility_type,
            district=f.district,
            address=f.address,
            emergency_capable=bool(f.emergency_capable),
            phone=f.contact_phone
        ))
    return results

def get_hospital_by_id(db: Session, facility_id: str) -> Optional[HospitalInfo]:
    """Retrieves specific facility by ID."""
    f = db.query(Facility).filter(Facility.id == facility_id).first()
    if not f:
        return None
    return HospitalInfo(
        id=f.id,
        name=f.name,
        facility_type=f.facility_type,
        district=f.district,
        address=f.address,
        emergency_capable=bool(f.emergency_capable),
        phone=f.contact_phone
    )
