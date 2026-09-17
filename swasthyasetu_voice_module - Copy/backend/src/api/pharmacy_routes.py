from datetime import datetime
import json
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.database.database import get_db
from app.models.models import PrescriptionOrder, MedicineInventory, Patient, DoctorUser

router = APIRouter(prefix="/api/v1/pharmacy", tags=["Pharmacy Staff Operations"])

class DispenseRequest(BaseModel):
    dispensed_by: Optional[str] = "pharma_demo"
    notes: Optional[str] = None

class StockUpdateRequest(BaseModel):
    facility_id: str = "fac-phc-001"
    medicine_name: str
    stock_quantity: int
    unit: Optional[str] = "tablets"
    min_threshold: Optional[int] = 20
    status: Optional[str] = None  # available, low_stock, out_of_stock

class StockReportRequest(BaseModel):
    facility_id: str = "fac-phc-001"
    medicine_name: str
    status: str  # low_stock, out_of_stock

@router.get("/orders")
def get_facility_prescriptions(facility_id: str = "fac-phc-001", db: Session = Depends(get_db)):
    """
    Facility-scoped prescription orders.
    Safeguard: Returns only prescription information and patient demographics/identity
    required for dispensing, with NO unrestricted clinical history.
    """
    orders = db.query(PrescriptionOrder).filter(
        (PrescriptionOrder.facility_id == facility_id) | (PrescriptionOrder.facility_id.is_(None))
    ).order_by(PrescriptionOrder.created_at.desc()).all()

    patients_map = {p.id: p for p in db.query(Patient).all()}
    doctors_map = {d.id: d.name for d in db.query(DoctorUser).all()}

    result = []
    for o in orders:
        pat = patients_map.get(o.patient_id)
        # Parse medicine list
        meds = []
        try:
            meds = json.loads(o.medicine_list) if o.medicine_list.startswith("[") or o.medicine_list.startswith("{") else [{"medicine": o.medicine_list}]
        except Exception:
            meds = [{"medicine": o.medicine_list}]

        result.append({
            "id": o.id,
            "case_id": o.case_id,
            "patient_name": pat.name if pat else "Patient",
            "health_id": pat.health_id if pat else "HID-UNKNOWN",
            "village": pat.village if pat else "",
            "doctor_name": doctors_map.get(o.doctor_id, "Dr. Rajesh Sharma"),
            "medicines": meds,
            "instructions": o.instructions,
            "status": o.status,
            "dispensed_at": o.dispensed_at.isoformat() if o.dispensed_at else None,
            "created_at": o.created_at.isoformat() if o.created_at else None
        })

    pending_count = sum(1 for r in result if r["status"] == "pending")
    return {
        "facility_id": facility_id,
        "total_orders": len(result),
        "pending_orders": pending_count,
        "orders": result
    }

@router.post("/orders/{order_id}/dispense")
def dispense_prescription(order_id: str, req: DispenseRequest, db: Session = Depends(get_db)):
    order = db.query(PrescriptionOrder).filter(PrescriptionOrder.id == order_id).first()
    if not order:
        raise HTTPException(404, "Prescription order not found")
    
    if order.status == "dispensed":
        return {"status": "already_dispensed", "order_id": order.id, "dispensed_at": order.dispensed_at.isoformat()}

    order.status = "dispensed"
    order.dispensed_at = datetime.utcnow()

    # Automatically deduct matching inventory items
    try:
        med_data = json.loads(order.medicine_list)
        if isinstance(med_data, list):
            for item in med_data:
                med_name = item.get("medicine", "")
                qty_to_deduct = int(item.get("quantity", 1))
                # Search inventory for medicine
                for inv in db.query(MedicineInventory).filter(MedicineInventory.facility_id == (order.facility_id or "fac-phc-001")).all():
                    if inv.medicine_name.lower() in med_name.lower() or med_name.lower() in inv.medicine_name.lower():
                        inv.stock_quantity = max(0, inv.stock_quantity - qty_to_deduct)
                        if inv.stock_quantity == 0:
                            inv.status = "out_of_stock"
                        elif inv.stock_quantity <= inv.min_threshold:
                            inv.status = "low_stock"
                        else:
                            inv.status = "available"
    except Exception:
        pass

    db.commit()
    db.refresh(order)
    return {
        "status": "success",
        "message": "Prescription successfully dispensed and inventory updated.",
        "order_id": order.id,
        "dispensed_at": order.dispensed_at.isoformat()
    }

@router.get("/inventory")
def get_inventory(facility_id: str = "fac-phc-001", db: Session = Depends(get_db)):
    items = db.query(MedicineInventory).filter(MedicineInventory.facility_id == facility_id).all()
    result = []
    for item in items:
        # Determine live status
        cur_status = item.status
        if item.stock_quantity <= 0:
            cur_status = "out_of_stock"
        elif item.stock_quantity <= item.min_threshold:
            cur_status = "low_stock"
        else:
            cur_status = "available"

        result.append({
            "id": item.id,
            "facility_id": item.facility_id,
            "medicine_name": item.medicine_name,
            "stock_quantity": item.stock_quantity,
            "unit": item.unit,
            "min_threshold": item.min_threshold,
            "status": cur_status,
            "updated_at": item.updated_at.isoformat() if item.updated_at else None
        })
    
    return {
        "facility_id": facility_id,
        "inventory": result,
        "out_of_stock_count": sum(1 for i in result if i["status"] == "out_of_stock"),
        "low_stock_count": sum(1 for i in result if i["status"] == "low_stock")
    }

@router.post("/inventory/update")
def update_stock(req: StockUpdateRequest, db: Session = Depends(get_db)):
    item = db.query(MedicineInventory).filter(
        MedicineInventory.facility_id == req.facility_id,
        MedicineInventory.medicine_name == req.medicine_name
    ).first()

    status = req.status
    if not status:
        if req.stock_quantity <= 0:
            status = "out_of_stock"
        elif req.stock_quantity <= req.min_threshold:
            status = "low_stock"
        else:
            status = "available"

    if not item:
        item = MedicineInventory(
            facility_id=req.facility_id,
            medicine_name=req.medicine_name,
            stock_quantity=req.stock_quantity,
            unit=req.unit or "tablets",
            min_threshold=req.min_threshold,
            status=status
        )
        db.add(item)
    else:
        item.stock_quantity = req.stock_quantity
        item.status = status
        if req.unit:
            item.unit = req.unit
        if req.min_threshold:
            item.min_threshold = req.min_threshold
    
    db.commit()
    db.refresh(item)
    return {"status": "success", "medicine": item.medicine_name, "quantity": item.stock_quantity, "stock_status": item.status}

@router.post("/inventory/report-status")
def report_stock_status(req: StockReportRequest, db: Session = Depends(get_db)):
    item = db.query(MedicineInventory).filter(
        MedicineInventory.facility_id == req.facility_id,
        MedicineInventory.medicine_name == req.medicine_name
    ).first()
    if not item:
        raise HTTPException(404, "Medicine not found in inventory")
    
    item.status = req.status
    if req.status == "out_of_stock":
        item.stock_quantity = 0
    db.commit()
    db.refresh(item)
    return {"status": "success", "medicine": item.medicine_name, "reported_status": item.status}
