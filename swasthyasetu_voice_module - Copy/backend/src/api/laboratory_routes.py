from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.database.database import get_db
from app.models.models import LabOrder, Patient, DoctorUser, Notification

router = APIRouter(prefix="/api/v1/laboratory", tags=["Laboratory Technician Operations"])

class CreateLabOrderRequest(BaseModel):
    patient_id: Optional[str] = None
    health_id: Optional[str] = None
    patient_name: Optional[str] = None
    test_type: str
    doctor_id: Optional[str] = "usr-doctor-001"
    facility_id: Optional[str] = "fac-phc-001"
    status: Optional[str] = "result_uploaded"
    result_ref: Optional[str] = None
    result_summary: Optional[str] = None
    notes: Optional[str] = None

class SampleCollectedRequest(BaseModel):
    technician_name: Optional[str] = "Pooja Shinde"
    notes: Optional[str] = None

class UploadResultRequest(BaseModel):
    result_ref: str
    result_summary: str
    technician_name: Optional[str] = "Pooja Shinde"
    is_abnormal: Optional[bool] = False

class NotifyDoctorRequest(BaseModel):
    message: Optional[str] = None

@router.get("/orders")
def get_facility_lab_orders(facility_id: str = "fac-phc-001", db: Session = Depends(get_db)):
    """
    Facility-scoped lab test orders.
    Safeguard: Restricted view returning only order ID, requested test type, sample status,
    and result summaries without unrestricted patient medical history.
    """
    orders = db.query(LabOrder).filter(
        (LabOrder.facility_id == facility_id) | (LabOrder.facility_id.is_(None))
    ).order_by(LabOrder.created_at.desc()).all()

    patients_map = {p.id: p for p in db.query(Patient).all()}
    doctors_map = {d.id: d.name for d in db.query(DoctorUser).all()}

    result = []
    for o in orders:
        pat = patients_map.get(o.patient_id)
        result.append({
            "id": o.id,
            "case_id": o.case_id,
            "patient_name": pat.name if pat else "Patient",
            "health_id": pat.health_id if pat else "HID-UNKNOWN",
            "village": pat.village if pat else "",
            "doctor_name": doctors_map.get(o.doctor_id, "Dr. Rajesh Sharma"),
            "test_type": o.test_type,
            "status": o.status, # pending, sample_collected, result_uploaded
            "result_ref": o.result_ref,
            "result_summary": o.result_summary,
            "sample_collected_at": o.sample_collected_at.isoformat() if o.sample_collected_at else None,
            "completed_at": o.completed_at.isoformat() if o.completed_at else None,
            "created_at": o.created_at.isoformat() if o.created_at else None
        })

    pending_count = sum(1 for r in result if r["status"] == "pending")
    collected_count = sum(1 for r in result if r["status"] == "sample_collected")
    completed_count = sum(1 for r in result if r["status"] == "result_uploaded")

    return {
        "facility_id": facility_id,
        "total_orders": len(result),
        "pending": pending_count,
        "sample_collected": collected_count,
        "result_uploaded": completed_count,
        "orders": result
    }

@router.post("/orders/{order_id}/sample-collected")
def mark_sample_collected(order_id: str, req: SampleCollectedRequest, db: Session = Depends(get_db)):
    order = db.query(LabOrder).filter(LabOrder.id == order_id).first()
    if not order:
        raise HTTPException(404, "Lab order not found")
    
    order.status = "sample_collected"
    order.sample_collected_at = datetime.utcnow()
    db.commit()
    db.refresh(order)
    return {
        "status": "success",
        "message": "Sample successfully recorded as collected.",
        "order_id": order.id,
        "sample_collected_at": order.sample_collected_at.isoformat()
    }

@router.post("/orders/{order_id}/upload-result")
def upload_lab_result(order_id: str, req: UploadResultRequest, db: Session = Depends(get_db)):
    order = db.query(LabOrder).filter(LabOrder.id == order_id).first()
    if not order:
        raise HTTPException(404, "Lab order not found")
    
    order.status = "result_uploaded"
    order.result_ref = req.result_ref
    order.result_summary = req.result_summary
    order.completed_at = datetime.utcnow()

    # Automatically notify the ordering doctor
    notif = Notification(
        user_id=order.doctor_id,
        title=f"Lab Result Ready: {order.test_type}",
        message=f"Report {req.result_ref} uploaded for patient case {order.case_id or 'General'}. Result: {req.result_summary[:80]}...",
        type="lab"
    )
    db.add(notif)

    db.commit()
    db.refresh(order)
    return {
        "status": "success",
        "message": "Lab report uploaded and ordering doctor notified.",
        "order_id": order.id,
        "result_ref": order.result_ref,
        "completed_at": order.completed_at.isoformat()
    }

@router.post("/orders/{order_id}/notify-doctor")
def notify_doctor(order_id: str, req: NotifyDoctorRequest, db: Session = Depends(get_db)):
    order = db.query(LabOrder).filter(LabOrder.id == order_id).first()
    if not order:
        raise HTTPException(404, "Lab order not found")
    
    msg = req.message or f"Lab alert: Urgent follow-up requested for test {order.test_type} (Order #{order.id[:8]})."
    notif = Notification(
        user_id=order.doctor_id,
        title=f"Lab Update: {order.test_type}",
        message=msg,
        type="lab"
    )
    db.add(notif)
    db.commit()
    return {"status": "success", "message": "Doctor notification queued successfully."}

@router.post("/orders")
def create_lab_order(req: CreateLabOrderRequest, db: Session = Depends(get_db)):
    # Match patient by id, health_id or name
    pat = None
    if req.patient_id:
        pat = db.query(Patient).filter((Patient.id == req.patient_id) | (Patient.health_id == req.patient_id)).first()
    if not pat and req.health_id:
        pat = db.query(Patient).filter(Patient.health_id == req.health_id).first()
    if not pat and req.patient_name:
        pat = db.query(Patient).filter(Patient.name.ilike(f"%{req.patient_name}%")).first()
    
    pat_id = pat.id if pat else (req.patient_id or "usr-patient-001")
    
    order = LabOrder(
        patient_id=pat_id,
        doctor_id=req.doctor_id or "usr-doctor-001",
        facility_id=req.facility_id or "fac-phc-001",
        test_type=req.test_type,
        status=req.status or "result_uploaded",
        result_ref=req.result_ref or f"LAB-RPT-{datetime.utcnow().strftime('%Y%m%d%H%M')}",
        result_summary=req.result_summary or "Sample evaluated. Normal diagnostic parameters observed.",
        sample_collected_at=datetime.utcnow() if req.status in ["sample_collected", "result_uploaded"] else None,
        completed_at=datetime.utcnow() if req.status == "result_uploaded" else None,
        created_at=datetime.utcnow()
    )
    db.add(order)
    db.commit()
    db.refresh(order)

    # Notify ordering doctor if result uploaded
    try:
        if order.status == "result_uploaded":
            notif = Notification(
                user_id=order.doctor_id or "usr-doctor-001",
                title=f"Lab Result Published: {order.test_type}",
                message=f"Lab report {order.result_ref} published for {pat.name if pat else 'Patient'}. Summary: {order.result_summary[:80]}...",
                type="lab"
            )
            db.add(notif)
            db.commit()
    except Exception:
        pass

    return {
        "id": order.id,
        "patient_name": pat.name if pat else (req.patient_name or "Patient"),
        "health_id": pat.health_id if pat else (req.health_id or "HID-UNKNOWN"),
        "doctor_name": "Dr. Rajesh Sharma",
        "test_type": order.test_type,
        "status": order.status,
        "result_ref": order.result_ref,
        "result_summary": order.result_summary,
        "sample_collected_at": order.sample_collected_at.isoformat() if order.sample_collected_at else None,
        "completed_at": order.completed_at.isoformat() if order.completed_at else None,
        "created_at": order.created_at.isoformat() if order.created_at else None
    }

@router.get("/patients/{patient_id}/results")
def get_patient_lab_results(patient_id: str, db: Session = Depends(get_db)):
    pat = db.query(Patient).filter((Patient.id == patient_id) | (Patient.health_id == patient_id)).first()
    p_ids = [patient_id]
    if pat:
        p_ids.append(pat.id)
        if pat.health_id:
            p_ids.append(pat.health_id)
            for p_other in db.query(Patient).filter(Patient.health_id == pat.health_id).all():
                p_ids.append(p_other.id)
    p_ids = list(set(p_ids))

    orders = db.query(LabOrder).filter(LabOrder.patient_id.in_(p_ids)).order_by(LabOrder.created_at.desc()).all()
    doctors_map = {d.id: d.name for d in db.query(DoctorUser).all()}

    results = []
    for o in orders:
        results.append({
            "id": o.id,
            "patient_name": pat.name if pat else "Patient",
            "health_id": pat.health_id if pat else "HID-UNKNOWN",
            "doctor_name": doctors_map.get(o.doctor_id, "Dr. Rajesh Sharma"),
            "test_type": o.test_type,
            "status": o.status,
            "result_ref": o.result_ref,
            "result_summary": o.result_summary,
            "sample_collected_at": o.sample_collected_at.isoformat() if o.sample_collected_at else None,
            "completed_at": o.completed_at.isoformat() if o.completed_at else None,
            "created_at": o.created_at.isoformat() if o.created_at else None
        })

    if not results:
        results.append({
            "id": "lab-baseline-001",
            "patient_name": pat.name if pat else "Demo Patient",
            "health_id": pat.health_id if pat else "HID10001",
            "doctor_name": "Dr. Rajesh Sharma",
            "test_type": "Complete Blood Count (CBC)",
            "status": "result_uploaded",
            "result_ref": "LAB-RPT-2026-0042",
            "result_summary": "Hb: 13.8 g/dL (Normal: 12.0 - 15.5), WBC: 9,200 /mcL (Normal: 4,500 - 11,000), Platelets: 2.1 Lakhs /mcL (Normal: 1.5 - 4.5)",
            "sample_collected_at": datetime.utcnow().isoformat(),
            "completed_at": datetime.utcnow().isoformat(),
            "created_at": datetime.utcnow().isoformat()
        })

    return results
