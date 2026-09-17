from datetime import datetime, timedelta
import json
import uuid
from typing import Optional, List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.database.database import get_db
from app.models.models import (
    ConsentRecord, SyncQueue, Case, Appointment, Consult, PrescriptionOrder,
    LabOrder, Referral, FollowUp, Patient, DoctorUser, EmergencyEvent, Notification
)

router = APIRouter(prefix="/api/v1", tags=["Consent, Interoperability, Telemedicine & Offline Sync"])

# -------------------------------------------------------------
# 1. CONSENT MANAGEMENT
# -------------------------------------------------------------
class ConsentCheckRequest(BaseModel):
    patient_id: str
    requested_by: str
    required_scope: str = "tier_2_records" # tier_1_consent, tier_2_records, tier_3_clinical_history

class ConsentGrantRequest(BaseModel):
    patient_id: str
    requested_by: str
    scope: str = "tier_2_records"
    duration_days: int = 30

@router.post("/consent/check")
def check_consent(req: ConsentCheckRequest, db: Session = Depends(get_db)):
    """
    Tier 1 -> Current Care / Basic Access
    Tier 2 -> Patient Records
    Tier 3 -> Clinical History
    """
    now = datetime.utcnow()
    record = db.query(ConsentRecord).filter(
        ConsentRecord.patient_id == req.patient_id,
        ConsentRecord.scope == req.required_scope,
        ConsentRecord.status == "active",
        ConsentRecord.expires_at > now
    ).first()

    if not record:
        return {
            "authorized": False,
            "error": "consent_required",
            "action": "request_consent",
            "patient_id": req.patient_id,
            "requested_scope": req.required_scope,
            "message": "Patient consent required before clinical history can be displayed."
        }

    return {
        "authorized": True,
        "consent_id": record.id,
        "scope": record.scope,
        "expires_at": record.expires_at.isoformat()
    }

@router.post("/consent/grant")
def grant_consent(req: ConsentGrantRequest, db: Session = Depends(get_db)):
    expires_at = datetime.utcnow() + timedelta(days=req.duration_days)
    record = ConsentRecord(
        patient_id=req.patient_id,
        requested_by=req.requested_by,
        scope=req.scope,
        status="active",
        expires_at=expires_at
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return {
        "status": "granted",
        "consent_id": record.id,
        "scope": record.scope,
        "expires_at": record.expires_at.isoformat(),
        "message": f"Consent granted successfully for {req.scope}."
    }

# -------------------------------------------------------------
# 2. GOVERNMENT INTEROPERABILITY (Mock ABDM & FHIR R4)
# -------------------------------------------------------------
class AbhaVerifyRequest(BaseModel):
    health_id: str
    auth_mode: str = "DEMO_AUTH"

@router.post("/interop/abdm/verify-abha")
def verify_abha(req: AbhaVerifyRequest, db: Session = Depends(get_db)):
    """
    Mock ABDM / ABHA Integration Service.
    Clearly labeled Mock/Demo mode for government health system compliance.
    """
    pat = db.query(Patient).filter(Patient.health_id == req.health_id).first()
    return {
        "service": "Mock ABDM / ABHA Gateway (Sandbox Mode)",
        "status": "VERIFIED",
        "health_id": req.health_id,
        "name": pat.name if pat else "Verified ABHA User",
        "kyc_status": "SUCCESS",
        "abha_address": f"{req.health_id.lower()}@abdm",
        "disclaimer": "DEMO / MOCK ABDM gateway response for Smart India Hackathon prototype."
    }

@router.get("/interop/fhir/patient/{patient_id}")
def get_fhir_r4_bundle(patient_id: str, db: Session = Depends(get_db)):
    """
    Mock FHIR R4 Bundle conversion service.
    Converts patient records and encounters to HL7 FHIR R4 JSON format.
    """
    pat = db.query(Patient).filter(Patient.id == patient_id).first()
    if not pat:
        raise HTTPException(404, "Patient not found")

    cases = db.query(Case).filter(Case.patient_id == patient_id).all()
    appts = db.query(Appointment).filter(Appointment.patient_id == patient_id).all()

    fhir_bundle = {
        "resourceType": "Bundle",
        "id": f"bundle-{patient_id}",
        "type": "collection",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "meta": {
            "profile": ["http://hl7.org/fhir/StructureDefinition/Bundle"]
        },
        "entry": [
            {
                "fullUrl": f"urn:uuid:Patient/{pat.id}",
                "resource": {
                    "resourceType": "Patient",
                    "id": pat.id,
                    "identifier": [
                        {"system": "https://healthid.abdm.gov.in", "value": pat.health_id or "HID-DEMO"}
                    ],
                    "name": [{"text": pat.name or "Unknown"}],
                    "address": [{"city": pat.village or "Pune Rural", "country": "India"}]
                }
            }
        ]
    }

    for c in cases:
        fhir_bundle["entry"].append({
            "fullUrl": f"urn:uuid:Condition/{c.id}",
            "resource": {
                "resourceType": "Condition",
                "id": c.id,
                "subject": {"reference": f"Patient/{pat.id}"},
                "clinicalStatus": {"coding": [{"code": "active"}]},
                "note": [{"text": c.symptom_text}],
                "recordedDate": c.created_at.isoformat() if c.created_at else None
            }
        })

    return {
        "service": "Mock FHIR R4 Interoperability Gateway",
        "standard": "HL7 FHIR Release 4",
        "bundle": fhir_bundle
    }

# -------------------------------------------------------------
# 3. OFFLINE QUEUE & AUTOMATIC SYNCHRONIZATION
# -------------------------------------------------------------
class SyncItem(BaseModel):
    idempotency_key: str
    operation: str  # create_case, create_appointment, record_emergency
    payload: Dict[str, Any]

class BatchSyncRequest(BaseModel):
    client_id: str
    items: List[SyncItem]

@router.post("/sync")
def process_sync_queue(req: BatchSyncRequest, db: Session = Depends(get_db)):
    """
    Offline sync processor with Idempotency Key deduplication.
    Enables low-bandwidth / no-internet offline reporting.
    """
    processed = []
    skipped = []

    for item in req.items:
        # Check idempotency
        existing_sync = db.query(SyncQueue).filter(SyncQueue.idempotency_key == item.idempotency_key).first()
        if existing_sync:
            skipped.append({
                "idempotency_key": item.idempotency_key,
                "status": "already_processed",
                "synced_at": existing_sync.synced_at.isoformat()
            })
            continue

        # Execute operation
        try:
            if item.operation == "create_case":
                p = item.payload
                nc = Case(
                    id=str(uuid.uuid4()),
                    patient_id=p.get("patient_id", "pat-001"),
                    symptom_text=p.get("symptom_text", ""),
                    language=p.get("language", "en"),
                    severity=p.get("severity", "routine"),
                    source=p.get("source", "patient_app")
                )
                db.add(nc)
            elif item.operation == "create_appointment":
                p = item.payload
                na = Appointment(
                    id=str(uuid.uuid4()),
                    patient_id=p.get("patient_id", "pat-001"),
                    doctor_id=p.get("doctor_id", "usr-doctor-001"),
                    facility_id=p.get("facility_id", "fac-phc-001"),
                    scheduled_time=datetime.utcnow() + timedelta(hours=1),
                    slot_time=p.get("slot_time", "11:00 AM"),
                    queue_number=int(p.get("queue_number", 3)),
                    status="booked",
                    notes=p.get("notes", "Booked via offline sync.")
                )
                db.add(na)
            
            # Record in SyncQueue
            sq = SyncQueue(
                idempotency_key=item.idempotency_key,
                operation=item.operation,
                payload=json.dumps(item.payload),
                sync_status="synced",
                synced_at=datetime.utcnow()
            )
            db.add(sq)
            db.commit()
            processed.append({
                "idempotency_key": item.idempotency_key,
                "operation": item.operation,
                "status": "synced"
            })
        except Exception as ex:
            db.rollback()
            skipped.append({
                "idempotency_key": item.idempotency_key,
                "error": str(ex),
                "status": "failed"
            })

    return {
        "status": "success",
        "processed_count": len(processed),
        "skipped_count": len(skipped),
        "processed": processed,
        "skipped": skipped
    }

# -------------------------------------------------------------
# 4. TELEMEDICINE & DOCTOR CONSULTATION END WORKFLOW
# -------------------------------------------------------------
class TelemedicineSignal(BaseModel):
    session_id: str
    sender_role: str
    signal_type: str  # offer, answer, ice-candidate, join
    data: Dict[str, Any]

class EndConsultationRequest(BaseModel):
    appointment_id: Optional[str] = None
    case_id: Optional[str] = None
    doctor_id: str
    clinical_notes: str
    close_case: bool = False
    prescription_medicines: Optional[List[Dict[str, Any]]] = None
    prescription_instructions: Optional[str] = None
    lab_test_type: Optional[str] = None
    referral_to_facility: Optional[str] = None
    referral_reason: Optional[str] = None
    followup_category: Optional[str] = None # maternal, child, chronic, elderly
    followup_due_days: Optional[int] = None
    followup_notes: Optional[str] = None

# In-memory signaling cache for WebRTC
SIGNALING_CHANNELS: Dict[str, List[Dict[str, Any]]] = {}

@router.post("/telemedicine/signal")
def post_signal(req: TelemedicineSignal):
    """FastAPI WebRTC signaling endpoint for exchange of SDP Offer/Answer and ICE Candidates."""
    if req.session_id not in SIGNALING_CHANNELS:
        SIGNALING_CHANNELS[req.session_id] = []
    
    SIGNALING_CHANNELS[req.session_id].append({
        "sender": req.sender_role,
        "type": req.signal_type,
        "data": req.data,
        "timestamp": datetime.utcnow().isoformat()
    })
    return {"status": "relayed", "session_id": req.session_id}

@router.get("/telemedicine/signal/{session_id}")
def get_signals(session_id: str):
    signals = SIGNALING_CHANNELS.get(session_id, [])
    return {
        "session_id": session_id,
        "mode": "WebRTC Peer Signaling (STUN/TURN Active)",
        "signals": signals
    }

@router.post("/doctor/consultation/complete")
def complete_doctor_consultation(req: EndConsultationRequest, db: Session = Depends(get_db)):
    """
    On consultation end, doctor enters notes and chooses:
    - Close Case
    - Create Prescription
    - Create Lab Order
    - Create Referral
    - Create Follow-up
    """
    now = datetime.utcnow()
    patient_id = "pat-001"

    # 1. Update Appointment
    if req.appointment_id:
        appt = db.query(Appointment).filter(Appointment.id == req.appointment_id).first()
        if appt:
            appt.status = "completed"
            appt.completed_at = now
            appt.notes = req.clinical_notes
            if not appt.start_service_time:
                appt.start_service_time = now - timedelta(minutes=15)
            patient_id = appt.patient_id

    # 2. Record Consult
    consult = Consult(
        case_id=req.case_id or "case-gen-001",
        doctor_id=req.doctor_id,
        notes=req.clinical_notes,
        started_at=now - timedelta(minutes=15),
        ended_at=now
    )
    db.add(consult)

    # 3. Close Case if selected
    if req.close_case and req.case_id:
        c = db.query(Case).filter(Case.id == req.case_id).first()
        if c:
            c.status = "closed"

    # 4. Create Prescription Order if provided
    created_rx_id = None
    if req.prescription_medicines:
        rx = PrescriptionOrder(
            case_id=req.case_id,
            doctor_id=req.doctor_id,
            patient_id=patient_id,
            facility_id="fac-phc-001",
            medicine_list=json.dumps(req.prescription_medicines),
            instructions=req.prescription_instructions or "Take as directed by doctor.",
            status="pending"
        )
        db.add(rx)
        db.flush()
        created_rx_id = rx.id

    # 5. Create Lab Order if requested
    created_lab_id = None
    if req.lab_test_type:
        lab = LabOrder(
            case_id=req.case_id,
            doctor_id=req.doctor_id,
            patient_id=patient_id,
            facility_id="fac-phc-001",
            test_type=req.lab_test_type,
            status="pending"
        )
        db.add(lab)
        db.flush()
        created_lab_id = lab.id

    # 6. Create Referral if requested
    created_ref_id = None
    if req.referral_to_facility:
        ref = Referral(
            case_id=req.case_id,
            patient_id=patient_id,
            from_facility_id="fac-phc-001",
            to_facility_id=req.referral_to_facility,
            reason=req.referral_reason or "Specialist evaluation required.",
            status="requested",
            urgency="ROUTINE"
        )
        db.add(ref)
        db.flush()
        created_ref_id = ref.id

    # 7. Create Follow-up if requested
    created_fu_id = None
    if req.followup_category and req.followup_due_days:
        fu = FollowUp(
            case_id=req.case_id,
            patient_id=patient_id,
            doctor_id=req.doctor_id,
            facility_id="fac-phc-001",
            category=req.followup_category,
            title=f"{req.followup_category.capitalize()} Consultation Check-in",
            due_date=now + timedelta(days=req.followup_due_days),
            next_checkin_date=now + timedelta(days=req.followup_due_days),
            notes=req.followup_notes or "Review response to current treatment.",
            status="pending"
        )
        db.add(fu)
        db.flush()
        created_fu_id = fu.id

    db.commit()
    return {
        "status": "success",
        "message": "Consultation successfully completed and clinical orders recorded.",
        "appointment_status": "completed",
        "prescription_id": created_rx_id,
        "lab_order_id": created_lab_id,
        "referral_id": created_ref_id,
        "followup_id": created_fu_id
    }

# -------------------------------------------------------------
# 5. ABDM AADHAAR & ABHA OTP VERIFICATION & HEALTH ID GENERATION
# -------------------------------------------------------------
import random

class AadhaarOTPRequest(BaseModel):
    aadhaar_number: str

class AadhaarVerifyRequest(BaseModel):
    txn_id: str
    otp: str
    aadhaar_number: Optional[str] = None

class AbhaOTPRequest(BaseModel):
    abha_id: str

class AbhaVerifyRequest(BaseModel):
    txn_id: str
    otp: str
    abha_id: Optional[str] = None

@router.get("/abdm/health-id/generate")
def generate_health_id():
    now_year = datetime.utcnow().year
    rand_suffix = random.randint(10000, 99999)
    return {
        "status": "success",
        "health_id": f"HID-{now_year}-{rand_suffix}",
        "timestamp": datetime.utcnow().isoformat()
    }

@router.post("/abdm/aadhaar/generate-otp")
def generate_aadhaar_otp(req: AadhaarOTPRequest):
    num = req.aadhaar_number.replace(" ", "").replace("-", "")
    if len(num) < 4:
        raise HTTPException(400, "Valid 12-digit Aadhaar number required.")
    last4 = num[-4:]
    txn_id = f"txn-uidai-{uuid.uuid4().hex[:8]}"
    return {
        "status": "otp_sent",
        "txn_id": txn_id,
        "masked_aadhaar": f"XXXX-XXXX-{last4}",
        "message": f"UIDAI OTP successfully dispatched to Aadhaar linked mobile ending with ***{last4}",
        "demo_otp": "123456"
    }

@router.post("/abdm/aadhaar/verify-otp")
def verify_aadhaar_otp(req: AadhaarVerifyRequest):
    if req.otp != "123456" and len(req.otp) != 6:
        raise HTTPException(400, "Invalid or expired Aadhaar OTP. Please enter valid 6-digit OTP (Demo: 123456).")
    
    # Generate linked ABHA and Health ID
    rand_abha = f"{random.randint(10, 99)}-{random.randint(1000, 9999)}-{random.randint(1000, 9999)}-{random.randint(1000, 9999)}"
    rand_hid = f"HID-{datetime.utcnow().year}-{random.randint(10000, 99999)}"
    return {
        "status": "verified",
        "kyc_verified": True,
        "txn_id": req.txn_id,
        "name": "Savitri Jadhav",
        "health_id": rand_hid,
        "generated_abha": rand_abha,
        "gender": "Female",
        "yob": "1988",
        "message": "Aadhaar e-KYC verified via UIDAI. Health ID & ABHA generated."
    }

@router.post("/abdm/abha/generate-otp")
def generate_abha_otp(req: AbhaOTPRequest):
    val = req.abha_id.strip()
    if not val:
        raise HTTPException(400, "Valid ABHA Number or ABHA Address required.")
    txn_id = f"txn-abdm-{uuid.uuid4().hex[:8]}"
    return {
        "status": "otp_sent",
        "txn_id": txn_id,
        "abha_id": val,
        "message": f"ABDM OTP successfully dispatched to mobile linked with ABHA ID {val}",
        "demo_otp": "123456"
    }

@router.post("/abdm/abha/verify-otp")
def verify_abha_otp(req: AbhaVerifyRequest):
    if req.otp != "123456" and len(req.otp) != 6:
        raise HTTPException(400, "Invalid ABHA OTP. Please enter valid 6-digit OTP (Demo: 123456).")
    
    return {
        "status": "verified",
        "abha_verified": True,
        "txn_id": req.txn_id,
        "abha_id": req.abha_id or "91-1234-5678-9012",
        "health_id": f"HID-{datetime.utcnow().year}-{random.randint(10000, 99999)}",
        "name": "Ramesh Patil",
        "message": "ABHA ID successfully authenticated & linked with SwasthyaSetu Health Grid."
    }

# -------------------------------------------------------------
# 9. NEARBY PHARMACIES — MEDICINE AVAILABILITY (Patient Portal)
#    Maharashtra Government Health Grid — PHC / CHC / District Hospital
#    Covers: Pune, Nashik, Nagpur, Aurangabad, Kolhapur, Thane,
#             Amravati, Solapur, Raigad, Satara districts
# -------------------------------------------------------------

@router.get("/patient/nearby-pharmacies")
def get_nearby_pharmacies(
    lat: float = 18.5204,
    lng: float = 73.8567,
    radius_km: float = 15.0,
    medicine: Optional[str] = None,
    city: Optional[str] = "Pune",
    db: Session = Depends(get_db),
):
    """
    Location-based nearby pharmacy / medicine availability across Maharashtra.
    Returns PHC, CHC, Sub-District & District Hospital dispensaries + Jan Aushadhi stores
    across major Maharashtra districts under NHM Maharashtra / Aarogya Maharashtra.
    """
    pharmacies = [
        # ─── PUNE DISTRICT ───
        {
            "id": "pharm-pune-phc-001",
            "name": "Shivajinagar PHC Pharmacy (प्राथमिक आरोग्य केंद्र)",
            "type": "PHC Pharmacy — NHM Maharashtra",
            "tier": "PHC",
            "district": "Pune",
            "taluka": "Haveli",
            "address": "PHC Campus, Near Shivajinagar Railway Station, Pune — 411005",
            "city": "Pune",
            "lat": 18.5314,
            "lng": 73.8446,
            "distance_km": 0.6,
            "phone": "+91-020-25531234",
            "timings": "8:00 AM – 6:00 PM (Mon–Sat)",
            "is_open": True,
            "medicines": [
                {"name": "Paracetamol 500mg", "stock": 420, "unit": "tablets", "status": "available", "price": "Free (NHM Maha)"},
                {"name": "Cetirizine 10mg", "stock": 210, "unit": "tablets", "status": "available", "price": "Free (NHM Maha)"},
                {"name": "Amoxicillin 500mg", "stock": 65, "unit": "capsules", "status": "low_stock", "price": "Free (NHM Maha)"},
                {"name": "ORS Sachets", "stock": 380, "unit": "sachets", "status": "available", "price": "Free (NHM Maha)"},
                {"name": "Iron + Folic Acid", "stock": 600, "unit": "tablets", "status": "available", "price": "Free (NHM Maha)"},
                {"name": "Metformin 500mg", "stock": 180, "unit": "tablets", "status": "available", "price": "Free (NHM Maha)"},
                {"name": "Albendazole 400mg", "stock": 300, "unit": "tablets", "status": "available", "price": "Free (NHM Maha)"},
            ],
        },
        {
            "id": "pharm-pune-chc-001",
            "name": "Hadapsar CHC Pharmacy (सामुदायिक आरोग्य केंद्र)",
            "type": "CHC Pharmacy — Maharashtra",
            "tier": "CHC",
            "district": "Pune",
            "taluka": "Haveli",
            "address": "CHC Building, Pune–Solapur Road, Hadapsar, Pune — 411028",
            "city": "Pune",
            "lat": 18.5089,
            "lng": 73.9260,
            "distance_km": 5.2,
            "phone": "+91-020-26895012",
            "timings": "8:00 AM – 8:00 PM (Daily)",
            "is_open": True,
            "medicines": [
                {"name": "Paracetamol 500mg", "stock": 800, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Metformin 500mg", "stock": 350, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Amlodipine 5mg", "stock": 220, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Insulin Glargine", "stock": 28, "unit": "vials", "status": "low_stock", "price": "Free (MJPJAY)"},
                {"name": "Amoxicillin 500mg", "stock": 400, "unit": "capsules", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Atorvastatin 20mg", "stock": 180, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
            ],
        },
        {
            "id": "pharm-pune-dh-001",
            "name": "Sassoon General Hospital Pharmacy (ससून जिल्हा रुग्णालय)",
            "type": "District Hospital Pharmacy — Govt of Maharashtra",
            "tier": "District Hospital",
            "district": "Pune",
            "taluka": "Pune City",
            "address": "B.J. Govt Medical College, Station Road, Near Pune Railway Station, Pune — 411001",
            "city": "Pune",
            "lat": 18.5262,
            "lng": 73.8735,
            "distance_km": 2.8,
            "phone": "+91-020-26128000",
            "timings": "24 Hours (Emergency & OPD)",
            "is_open": True,
            "medicines": [
                {"name": "Paracetamol 500mg", "stock": 1500, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Metformin 500mg", "stock": 800, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Insulin Glargine", "stock": 85, "unit": "vials", "status": "available", "price": "Free (MJPJAY)"},
                {"name": "Atorvastatin 20mg", "stock": 350, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Amlodipine 5mg", "stock": 420, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Azithromycin 500mg", "stock": 200, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Tramadol 50mg", "stock": 120, "unit": "tablets", "status": "available", "price": "Free (MJPJAY)"},
            ],
        },
        {
            "id": "pharm-pune-ja-001",
            "name": "PM Jan Aushadhi Kendra — Kothrud (जन औषधि केंद्र)",
            "type": "Jan Aushadhi Kendra — PMBJK",
            "tier": "Jan Aushadhi",
            "district": "Pune",
            "taluka": "Kothrud",
            "address": "Shop No. 4, Paud Road, Near Vanaz Metro Station, Kothrud, Pune — 411038",
            "city": "Pune",
            "lat": 18.5074,
            "lng": 73.8077,
            "distance_km": 3.4,
            "phone": "+91-020-25445678",
            "timings": "9:00 AM – 8:30 PM (Daily)",
            "is_open": True,
            "medicines": [
                {"name": "Paracetamol 500mg", "stock": 650, "unit": "tablets", "status": "available", "price": "₹1.50/strip"},
                {"name": "Metformin 500mg", "stock": 300, "unit": "tablets", "status": "available", "price": "₹3.20/strip"},
                {"name": "Amlodipine 5mg", "stock": 220, "unit": "tablets", "status": "available", "price": "₹2.80/strip"},
                {"name": "Azithromycin 500mg", "stock": 110, "unit": "tablets", "status": "available", "price": "₹8.50/strip"},
                {"name": "Insulin Glargine", "stock": 18, "unit": "vials", "status": "low_stock", "price": "₹126/vial"},
                {"name": "Cetirizine 10mg", "stock": 400, "unit": "tablets", "status": "available", "price": "₹1.20/strip"},
            ],
        },

        # ─── NASHIK DISTRICT ───
        {
            "id": "pharm-nashik-phc-001",
            "name": "Dindori PHC Pharmacy — Nashik (प्राथमिक आरोग्य केंद्र, दिंडोरी)",
            "type": "PHC Pharmacy — NHM Maharashtra",
            "tier": "PHC",
            "district": "Nashik",
            "taluka": "Dindori",
            "address": "PHC Campus, Dindori Town, Nashik — 422202",
            "city": "Nashik",
            "lat": 20.2117,
            "lng": 73.8363,
            "distance_km": 12.5,
            "phone": "+91-02557-222401",
            "timings": "8:00 AM – 4:00 PM (Mon–Sat)",
            "is_open": True,
            "medicines": [
                {"name": "Paracetamol 500mg", "stock": 350, "unit": "tablets", "status": "available", "price": "Free (NHM Maha)"},
                {"name": "ORS Sachets", "stock": 280, "unit": "sachets", "status": "available", "price": "Free (NHM Maha)"},
                {"name": "Iron + Folic Acid", "stock": 500, "unit": "tablets", "status": "available", "price": "Free (NHM Maha)"},
                {"name": "Chloroquine 250mg", "stock": 120, "unit": "tablets", "status": "available", "price": "Free (NVBDCP)"},
                {"name": "Albendazole 400mg", "stock": 200, "unit": "tablets", "status": "available", "price": "Free (NHM Maha)"},
            ],
        },
        {
            "id": "pharm-nashik-dh-001",
            "name": "Nashik Civil Hospital Pharmacy (नाशिक सिव्हिल रुग्णालय)",
            "type": "District Hospital Pharmacy — Govt of Maharashtra",
            "tier": "District Hospital",
            "district": "Nashik",
            "taluka": "Nashik",
            "address": "Civil Hospital Road, Nashik City, Nashik — 422001",
            "city": "Nashik",
            "lat": 19.9975,
            "lng": 73.7898,
            "distance_km": 14.2,
            "phone": "+91-0253-2316131",
            "timings": "24 Hours",
            "is_open": True,
            "medicines": [
                {"name": "Paracetamol 500mg", "stock": 1200, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Metformin 500mg", "stock": 600, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Insulin Glargine", "stock": 50, "unit": "vials", "status": "available", "price": "Free (MJPJAY)"},
                {"name": "Amlodipine 5mg", "stock": 350, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Amoxicillin 500mg", "stock": 480, "unit": "capsules", "status": "available", "price": "Free (Govt MH)"},
            ],
        },

        # ─── NAGPUR DISTRICT ───
        {
            "id": "pharm-nagpur-chc-001",
            "name": "Kamptee CHC Pharmacy — Nagpur (सामुदायिक आरोग्य केंद्र, कामठी)",
            "type": "CHC Pharmacy — Maharashtra",
            "tier": "CHC",
            "district": "Nagpur",
            "taluka": "Kamptee",
            "address": "CHC Building, Kamptee Road, Nagpur — 441002",
            "city": "Nagpur",
            "lat": 21.2223,
            "lng": 79.1917,
            "distance_km": 9.8,
            "phone": "+91-0712-2621001",
            "timings": "8:00 AM – 8:00 PM (Daily)",
            "is_open": True,
            "medicines": [
                {"name": "Paracetamol 500mg", "stock": 700, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "ORS Sachets", "stock": 450, "unit": "sachets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Metformin 500mg", "stock": 280, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Amoxicillin 500mg", "stock": 180, "unit": "capsules", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Cetirizine 10mg", "stock": 320, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
            ],
        },
        {
            "id": "pharm-nagpur-dh-001",
            "name": "Nagpur Government Medical College & Hospital Pharmacy (GMCH नागपूर)",
            "type": "District Hospital / Medical College Pharmacy",
            "tier": "District Hospital",
            "district": "Nagpur",
            "taluka": "Nagpur City",
            "address": "GMCH Campus, Hanuman Nagar, Nagpur — 440003",
            "city": "Nagpur",
            "lat": 21.1530,
            "lng": 79.0882,
            "distance_km": 11.0,
            "phone": "+91-0712-2701400",
            "timings": "24 Hours",
            "is_open": True,
            "medicines": [
                {"name": "Paracetamol 500mg", "stock": 2000, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Insulin Glargine", "stock": 100, "unit": "vials", "status": "available", "price": "Free (MJPJAY)"},
                {"name": "Metformin 500mg", "stock": 900, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Amlodipine 5mg", "stock": 500, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Azithromycin 500mg", "stock": 300, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Tramadol 50mg", "stock": 150, "unit": "tablets", "status": "available", "price": "Free (MJPJAY)"},
            ],
        },

        # ─── AURANGABAD (CHHATRAPATI SAMBHAJINAGAR) DISTRICT ───
        {
            "id": "pharm-aurangabad-phc-001",
            "name": "Gangapur PHC Pharmacy — Aurangabad (प्राथमिक आरोग्य केंद्र, गंगापूर)",
            "type": "PHC Pharmacy — NHM Maharashtra",
            "tier": "PHC",
            "district": "Chhatrapati Sambhajinagar",
            "taluka": "Gangapur",
            "address": "PHC Campus, Gangapur, Aurangabad — 431109",
            "city": "Aurangabad",
            "lat": 19.7201,
            "lng": 75.0118,
            "distance_km": 8.3,
            "phone": "+91-02431-232101",
            "timings": "8:00 AM – 4:00 PM (Mon–Sat)",
            "is_open": True,
            "medicines": [
                {"name": "Paracetamol 500mg", "stock": 300, "unit": "tablets", "status": "available", "price": "Free (NHM Maha)"},
                {"name": "Iron + Folic Acid", "stock": 450, "unit": "tablets", "status": "available", "price": "Free (NHM Maha)"},
                {"name": "ORS Sachets", "stock": 220, "unit": "sachets", "status": "available", "price": "Free (NHM Maha)"},
                {"name": "Metformin 500mg", "stock": 0, "unit": "tablets", "status": "out_of_stock", "price": "Free (NHM Maha)"},
                {"name": "Albendazole 400mg", "stock": 180, "unit": "tablets", "status": "available", "price": "Free (NHM Maha)"},
            ],
        },
        {
            "id": "pharm-aurangabad-dh-001",
            "name": "Government Medical College Aurangabad Pharmacy (शासकीय वैद्यकीय महाविद्यालय)",
            "type": "District Hospital / Medical College Pharmacy",
            "tier": "District Hospital",
            "district": "Chhatrapati Sambhajinagar",
            "taluka": "Aurangabad City",
            "address": "Govt Medical College Campus, Near DYANESHWAR CHOWK, Aurangabad — 431001",
            "city": "Aurangabad",
            "lat": 19.8762,
            "lng": 75.3433,
            "distance_km": 13.5,
            "phone": "+91-0240-2331600",
            "timings": "24 Hours",
            "is_open": True,
            "medicines": [
                {"name": "Paracetamol 500mg", "stock": 1800, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Metformin 500mg", "stock": 700, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Insulin Glargine", "stock": 60, "unit": "vials", "status": "available", "price": "Free (MJPJAY)"},
                {"name": "Amlodipine 5mg", "stock": 400, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Azithromycin 500mg", "stock": 250, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
            ],
        },

        # ─── KOLHAPUR DISTRICT ───
        {
            "id": "pharm-kolhapur-chc-001",
            "name": "Hatkanangale CHC Pharmacy — Kolhapur (सामुदायिक आरोग्य केंद्र)",
            "type": "CHC Pharmacy — Maharashtra",
            "tier": "CHC",
            "district": "Kolhapur",
            "taluka": "Hatkanangale",
            "address": "CHC Building, Hatkanangale, Kolhapur — 416109",
            "city": "Kolhapur",
            "lat": 16.8110,
            "lng": 74.1026,
            "distance_km": 10.2,
            "phone": "+91-0230-2466200",
            "timings": "8:00 AM – 8:00 PM (Daily)",
            "is_open": True,
            "medicines": [
                {"name": "Paracetamol 500mg", "stock": 600, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "ORS Sachets", "stock": 380, "unit": "sachets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Iron + Folic Acid", "stock": 520, "unit": "tablets", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Amoxicillin 500mg", "stock": 250, "unit": "capsules", "status": "available", "price": "Free (Govt MH)"},
                {"name": "Metformin 500mg", "stock": 90, "unit": "tablets", "status": "low_stock", "price": "Free (Govt MH)"},
            ],
        },

        # ─── THANE DISTRICT ───
        {
            "id": "pharm-thane-phc-001",
            "name": "Shahapur PHC Pharmacy — Thane (प्राथमिक आरोग्य केंद्र, शहापूर)",
            "type": "PHC Pharmacy — NHM Maharashtra",
            "tier": "PHC",
            "district": "Thane",
            "taluka": "Shahapur",
            "address": "PHC Campus, Shahapur Naka, Thane — 421601",
            "city": "Thane",
            "lat": 19.4562,
            "lng": 73.3253,
            "distance_km": 6.8,
            "phone": "+91-02527-223001",
            "timings": "8:00 AM – 4:00 PM (Mon–Sat)",
            "is_open": True,
            "medicines": [
                {"name": "Paracetamol 500mg", "stock": 410, "unit": "tablets", "status": "available", "price": "Free (NHM Maha)"},
                {"name": "ORS Sachets", "stock": 310, "unit": "sachets", "status": "available", "price": "Free (NHM Maha)"},
                {"name": "Chloroquine 250mg", "stock": 150, "unit": "tablets", "status": "available", "price": "Free (NVBDCP)"},
                {"name": "Iron + Folic Acid", "stock": 480, "unit": "tablets", "status": "available", "price": "Free (NHM Maha)"},
                {"name": "Amoxicillin 500mg", "stock": 0, "unit": "capsules", "status": "out_of_stock", "price": "Free (NHM Maha)"},
            ],
        },
    ]

    # Optional: filter by medicine name search
    if medicine:
        med_lower = medicine.strip().lower()
        filtered = []
        for p in pharmacies:
            matching_meds = [m for m in p["medicines"] if med_lower in m["name"].lower()]
            if matching_meds:
                p_copy = dict(p)
                p_copy["medicines"] = matching_meds
                filtered.append(p_copy)
        pharmacies = filtered

    return {
        "status": "success",
        "state": "Maharashtra",
        "grid": "Aarogya Maharashtra — NHM Public Health Grid",
        "patient_location": {"lat": lat, "lng": lng, "area": "Maharashtra"},
        "radius_km": radius_km,
        "total_pharmacies": len(pharmacies),
        "medicine_filter": medicine,
        "pharmacies": pharmacies,
        "timestamp": datetime.utcnow().isoformat(),
    }


# -------------------------------------------------------------
# 10. NEARBY DIAGNOSTIC CENTRES — Maharashtra Govt Health Grid
#     PHC Lab / CHC Lab / Sub-District Hospital / District Hospital
#     Covers: Pune, Nashik, Nagpur, Aurangabad, Kolhapur, Thane,
#              Amravati, Solapur, Raigad, Satara
# -------------------------------------------------------------

@router.get("/patient/nearby-diagnostics")
def get_nearby_diagnostics(
    lat: float = 18.5204,
    lng: float = 73.8567,
    radius_km: float = 20.0,
    test_type: Optional[str] = None,
    city: Optional[str] = "Pune",
    db: Session = Depends(get_db),
):
    """
    Location-based nearby diagnostic centre availability in Maharashtra.
    Returns PHC labs, CHC labs, Sub-District & District Hospital radiology/pathology units,
    and NABL-accredited private chains under Mahatma Phule Jan Arogya Yojana (MJPJAY).
    """
    centres = [
        # ─── PUNE DISTRICT ───
        {
            "id": "diag-pune-phc-001",
            "name": "Shivajinagar PHC Diagnostic Laboratory (प्राथमिक आरोग्य केंद्र प्रयोगशाळा)",
            "type": "PHC Lab — NHM Maharashtra",
            "tier": "PHC",
            "district": "Pune",
            "taluka": "Haveli",
            "address": "PHC Campus, Shivajinagar, Pune — 411005",
            "city": "Pune",
            "lat": 18.5314,
            "lng": 73.8446,
            "distance_km": 0.6,
            "phone": "+91-020-25531234",
            "timings": "8:00 AM – 4:30 PM (Mon–Sat)",
            "is_open": True,
            "nabl_accredited": False,
            "tests": [
                {"name": "CBC (Complete Blood Count)", "price": "Free (NHM Maha)", "turnaround": "2 hours", "available": True},
                {"name": "Rapid Malaria Test (RDT)", "price": "Free (NHM Maha)", "turnaround": "30 min", "available": True},
                {"name": "Urine Routine & Microscopy", "price": "Free (NHM Maha)", "turnaround": "1 hour", "available": True},
                {"name": "Blood Glucose (Fasting/PP)", "price": "Free (NHM Maha)", "turnaround": "1 hour", "available": True},
                {"name": "Hemoglobin (Hb)", "price": "Free (NHM Maha)", "turnaround": "30 min", "available": True},
                {"name": "Pregnancy Test (UPT)", "price": "Free (NHM Maha)", "turnaround": "15 min", "available": True},
            ],
        },
        {
            "id": "diag-pune-chc-001",
            "name": "Hadapsar CHC Pathology & Radiology Unit (सामुदायिक आरोग्य केंद्र प्रयोगशाळा)",
            "type": "CHC Lab — Maharashtra",
            "tier": "CHC",
            "district": "Pune",
            "taluka": "Haveli",
            "address": "CHC Building, Pune–Solapur Road, Hadapsar, Pune — 411028",
            "city": "Pune",
            "lat": 18.5089,
            "lng": 73.9260,
            "distance_km": 5.2,
            "phone": "+91-020-26895012",
            "timings": "8:00 AM – 6:00 PM (Daily)",
            "is_open": True,
            "nabl_accredited": False,
            "tests": [
                {"name": "CBC (Complete Blood Count)", "price": "Free (Govt MH)", "turnaround": "2 hours", "available": True},
                {"name": "Blood Glucose (Fasting/PP)", "price": "Free (Govt MH)", "turnaround": "1 hour", "available": True},
                {"name": "Urine Routine & Microscopy", "price": "Free (Govt MH)", "turnaround": "1 hour", "available": True},
                {"name": "Hemoglobin (Hb)", "price": "Free (Govt MH)", "turnaround": "30 min", "available": True},
                {"name": "X-Ray (Chest PA)", "price": "Free (Govt MH)", "turnaround": "1 hour", "available": True},
                {"name": "Rapid Dengue NS1", "price": "Free (Govt MH)", "turnaround": "45 min", "available": True},
                {"name": "Sputum AFB (TB)", "price": "Free (RNTCP)", "turnaround": "24 hours", "available": True},
            ],
        },
        {
            "id": "diag-pune-dh-001",
            "name": "Sassoon General Hospital Central Pathology & Radiology (ससून जिल्हा रुग्णालय)",
            "type": "District Hospital Lab — 24×7 NABL",
            "tier": "District Hospital",
            "district": "Pune",
            "taluka": "Pune City",
            "address": "B.J. Govt Medical College & Sassoon Hospital, Pune — 411001",
            "city": "Pune",
            "lat": 18.5262,
            "lng": 73.8735,
            "distance_km": 2.8,
            "phone": "+91-020-26128000",
            "timings": "24 Hours (Emergency Diagnostic Unit)",
            "is_open": True,
            "nabl_accredited": True,
            "tests": [
                {"name": "CBC (Complete Blood Count)", "price": "Free (Govt MH)", "turnaround": "2.5 hours", "available": True},
                {"name": "Blood Culture & Sensitivity", "price": "Free (Govt MH)", "turnaround": "48 hours", "available": True},
                {"name": "Dengue NS1 + IgM/IgG", "price": "Free (Govt MH)", "turnaround": "3 hours", "available": True},
                {"name": "CT Scan (Brain/Abdomen)", "price": "Free (MJPJAY) / ₹800", "turnaround": "2 hours", "available": True},
                {"name": "Ultrasound (Obstetric/Abdominal)", "price": "Free (Govt MH)", "turnaround": "1 hour", "available": True},
                {"name": "X-Ray (Chest/Orthopedic)", "price": "Free (Govt MH)", "turnaround": "45 min", "available": True},
                {"name": "2D Echo (Cardiac)", "price": "Free (MJPJAY) / ₹500", "turnaround": "2 hours", "available": True},
                {"name": "MRI Brain/Spine", "price": "Free (MJPJAY) / ₹2800", "turnaround": "4 hours", "available": True},
            ],
        },
        {
            "id": "diag-pune-sdh-001",
            "name": "Aundh Sub-District Hospital Lab (उपजिल्हा रुग्णालय, औंध)",
            "type": "Sub-District Hospital Lab — Maharashtra",
            "tier": "Sub-District Hospital",
            "district": "Pune",
            "taluka": "Haveli",
            "address": "Chest Hospital Campus, Aundh Camp, Pune — 411027",
            "city": "Pune",
            "lat": 18.5772,
            "lng": 73.8066,
            "distance_km": 7.5,
            "phone": "+91-020-27282000",
            "timings": "24 Hours (Aarogya Maharashtra)",
            "is_open": True,
            "nabl_accredited": True,
            "tests": [
                {"name": "CBC (Complete Blood Count)", "price": "Free (Govt)", "turnaround": "3 hours", "available": True},
                {"name": "Blood Glucose (Fasting/PP)", "price": "Free (Govt)", "turnaround": "1 hour", "available": True},
                {"name": "X-Ray (Any Region)", "price": "Free (Govt)", "turnaround": "1 hour", "available": True},
                {"name": "Ultrasound (Sonography)", "price": "Free (Govt)", "turnaround": "2 hours", "available": True},
                {"name": "Lipid Profile", "price": "Free (Govt)", "turnaround": "6 hours", "available": True},
                {"name": "LFT (Liver Function Test)", "price": "Free (Govt)", "turnaround": "6 hours", "available": True},
            ],
        },

        # ─── NASHIK DISTRICT ───
        {
            "id": "diag-nashik-phc-001",
            "name": "Dindori PHC Laboratory — Nashik (PHC प्रयोगशाळा, दिंडोरी)",
            "type": "PHC Lab — NHM Maharashtra",
            "tier": "PHC",
            "district": "Nashik",
            "taluka": "Dindori",
            "address": "PHC Campus, Dindori, Nashik — 422202",
            "city": "Nashik",
            "lat": 20.2117,
            "lng": 73.8363,
            "distance_km": 12.5,
            "phone": "+91-02557-222401",
            "timings": "8:00 AM – 3:30 PM (Mon–Sat)",
            "is_open": True,
            "nabl_accredited": False,
            "tests": [
                {"name": "Hemoglobin (Hb)", "price": "Free (NHM Maha)", "turnaround": "30 min", "available": True},
                {"name": "Rapid Malaria Test (RDT)", "price": "Free (NHM Maha)", "turnaround": "30 min", "available": True},
                {"name": "Urine Routine & Microscopy", "price": "Free (NHM Maha)", "turnaround": "1 hour", "available": True},
                {"name": "Pregnancy Test (UPT)", "price": "Free (NHM Maha)", "turnaround": "15 min", "available": True},
                {"name": "Sputum AFB (TB)", "price": "Free (RNTCP)", "turnaround": "24 hours", "available": True},
            ],
        },
        {
            "id": "diag-nashik-dh-001",
            "name": "Nashik Civil Hospital Pathology & Radiology (नाशिक सिव्हिल रुग्णालय)",
            "type": "District Hospital Lab — Govt of Maharashtra",
            "tier": "District Hospital",
            "district": "Nashik",
            "taluka": "Nashik",
            "address": "Civil Hospital Road, Nashik — 422001",
            "city": "Nashik",
            "lat": 19.9975,
            "lng": 73.7898,
            "distance_km": 14.2,
            "phone": "+91-0253-2316131",
            "timings": "24 Hours",
            "is_open": True,
            "nabl_accredited": True,
            "tests": [
                {"name": "CBC (Complete Blood Count)", "price": "Free (Govt MH)", "turnaround": "2 hours", "available": True},
                {"name": "Dengue NS1 + IgM/IgG", "price": "Free (Govt MH)", "turnaround": "3 hours", "available": True},
                {"name": "X-Ray (Chest PA)", "price": "Free (Govt MH)", "turnaround": "1 hour", "available": True},
                {"name": "Ultrasound (Obstetric/Abdominal)", "price": "Free (Govt MH)", "turnaround": "2 hours", "available": True},
                {"name": "CT Scan (Brain)", "price": "Free (MJPJAY)", "turnaround": "3 hours", "available": True},
                {"name": "HbA1c", "price": "Free (Govt MH)", "turnaround": "6 hours", "available": True},
            ],
        },

        # ─── NAGPUR DISTRICT ───
        {
            "id": "diag-nagpur-chc-001",
            "name": "Kamptee CHC Laboratory — Nagpur (CHC प्रयोगशाळा, कामठी)",
            "type": "CHC Lab — Maharashtra",
            "tier": "CHC",
            "district": "Nagpur",
            "taluka": "Kamptee",
            "address": "CHC Building, Kamptee Road, Nagpur — 441002",
            "city": "Nagpur",
            "lat": 21.2223,
            "lng": 79.1917,
            "distance_km": 9.8,
            "phone": "+91-0712-2621001",
            "timings": "8:00 AM – 6:00 PM (Daily)",
            "is_open": True,
            "nabl_accredited": False,
            "tests": [
                {"name": "CBC (Complete Blood Count)", "price": "Free (Govt MH)", "turnaround": "2 hours", "available": True},
                {"name": "Blood Glucose (Fasting/PP)", "price": "Free (Govt MH)", "turnaround": "1 hour", "available": True},
                {"name": "Hemoglobin (Hb)", "price": "Free (Govt MH)", "turnaround": "30 min", "available": True},
                {"name": "Urine Routine & Microscopy", "price": "Free (Govt MH)", "turnaround": "1 hour", "available": True},
                {"name": "Rapid Malaria Test", "price": "Free (NVBDCP)", "turnaround": "30 min", "available": True},
            ],
        },
        {
            "id": "diag-nagpur-dh-001",
            "name": "GMCH Nagpur — Pathology, Radiology & Imaging (शासकीय वैद्यकीय महाविद्यालय, नागपूर)",
            "type": "District Hospital / Medical College Lab — 24×7 NABL",
            "tier": "District Hospital",
            "district": "Nagpur",
            "taluka": "Nagpur City",
            "address": "GMCH Campus, Hanuman Nagar, Nagpur — 440003",
            "city": "Nagpur",
            "lat": 21.1530,
            "lng": 79.0882,
            "distance_km": 11.0,
            "phone": "+91-0712-2701400",
            "timings": "24 Hours",
            "is_open": True,
            "nabl_accredited": True,
            "tests": [
                {"name": "CBC (Complete Blood Count)", "price": "Free (Govt MH)", "turnaround": "2 hours", "available": True},
                {"name": "CT Scan (Brain/Chest/Abdomen)", "price": "Free (MJPJAY)", "turnaround": "2 hours", "available": True},
                {"name": "MRI (Brain/Spine)", "price": "Free (MJPJAY)", "turnaround": "4 hours", "available": True},
                {"name": "Ultrasound (All Types)", "price": "Free (Govt MH)", "turnaround": "1 hour", "available": True},
                {"name": "Blood Culture & Sensitivity", "price": "Free (Govt MH)", "turnaround": "48 hours", "available": True},
                {"name": "Thyroid Panel (T3, T4, TSH)", "price": "Free (Govt MH)", "turnaround": "8 hours", "available": True},
                {"name": "ECG (12-Lead)", "price": "Free (Govt MH)", "turnaround": "30 min", "available": True},
            ],
        },

        # ─── AURANGABAD (CHHATRAPATI SAMBHAJINAGAR) ───
        {
            "id": "diag-aurangabad-dh-001",
            "name": "GMC Aurangabad — Pathology & Radiology (शासकीय वैद्यकीय महाविद्यालय, औरंगाबाद)",
            "type": "District Hospital / Medical College Lab",
            "tier": "District Hospital",
            "district": "Chhatrapati Sambhajinagar",
            "taluka": "Aurangabad City",
            "address": "Govt Medical College, Aurangabad — 431001",
            "city": "Aurangabad",
            "lat": 19.8762,
            "lng": 75.3433,
            "distance_km": 13.5,
            "phone": "+91-0240-2331600",
            "timings": "24 Hours",
            "is_open": True,
            "nabl_accredited": True,
            "tests": [
                {"name": "CBC (Complete Blood Count)", "price": "Free (Govt MH)", "turnaround": "2 hours", "available": True},
                {"name": "X-Ray (Chest PA)", "price": "Free (Govt MH)", "turnaround": "1 hour", "available": True},
                {"name": "Ultrasound (Obstetric/Abdominal)", "price": "Free (Govt MH)", "turnaround": "2 hours", "available": True},
                {"name": "CT Scan (Brain)", "price": "Free (MJPJAY)", "turnaround": "3 hours", "available": True},
                {"name": "Dengue NS1 + IgM/IgG", "price": "Free (Govt MH)", "turnaround": "3 hours", "available": True},
                {"name": "HbA1c", "price": "Free (Govt MH)", "turnaround": "6 hours", "available": True},
            ],
        },

        # ─── SOLAPUR DISTRICT ───
        {
            "id": "diag-solapur-sdh-001",
            "name": "Barshi Sub-District Hospital Lab — Solapur (उपजिल्हा रुग्णालय, बार्शी)",
            "type": "Sub-District Hospital Lab — Maharashtra",
            "tier": "Sub-District Hospital",
            "district": "Solapur",
            "taluka": "Barshi",
            "address": "Sub-District Hospital, Barshi, Solapur — 413401",
            "city": "Solapur",
            "lat": 18.2342,
            "lng": 75.6940,
            "distance_km": 15.8,
            "phone": "+91-02184-222100",
            "timings": "8:00 AM – 8:00 PM (Daily)",
            "is_open": True,
            "nabl_accredited": False,
            "tests": [
                {"name": "CBC (Complete Blood Count)", "price": "Free (Govt)", "turnaround": "3 hours", "available": True},
                {"name": "Blood Glucose (Fasting/PP)", "price": "Free (Govt)", "turnaround": "1 hour", "available": True},
                {"name": "X-Ray (Chest PA)", "price": "Free (Govt)", "turnaround": "1 hour", "available": True},
                {"name": "Urine Routine & Microscopy", "price": "Free (Govt)", "turnaround": "1 hour", "available": True},
                {"name": "Hemoglobin (Hb)", "price": "Free (Govt)", "turnaround": "30 min", "available": True},
            ],
        },

        # ─── AMRAVATI DISTRICT ───
        {
            "id": "diag-amravati-dh-001",
            "name": "Amravati District Hospital Pathology & Radiology (जिल्हा रुग्णालय, अमरावती)",
            "type": "District Hospital Lab — Govt of Maharashtra",
            "tier": "District Hospital",
            "district": "Amravati",
            "taluka": "Amravati",
            "address": "District Hospital Campus, Amravati — 444601",
            "city": "Amravati",
            "lat": 20.9374,
            "lng": 77.7796,
            "distance_km": 17.0,
            "phone": "+91-0721-2662503",
            "timings": "24 Hours",
            "is_open": True,
            "nabl_accredited": True,
            "tests": [
                {"name": "CBC (Complete Blood Count)", "price": "Free (Govt MH)", "turnaround": "2 hours", "available": True},
                {"name": "Blood Culture & Sensitivity", "price": "Free (Govt MH)", "turnaround": "48 hours", "available": True},
                {"name": "X-Ray (Any Region)", "price": "Free (Govt MH)", "turnaround": "1 hour", "available": True},
                {"name": "Ultrasound (Sonography)", "price": "Free (Govt MH)", "turnaround": "2 hours", "available": True},
                {"name": "Blood Glucose (Fasting/PP)", "price": "Free (Govt MH)", "turnaround": "1 hour", "available": True},
                {"name": "Thyroid Panel (T3, T4, TSH)", "price": "Free (Govt MH)", "turnaround": "8 hours", "available": True},
            ],
        },
    ]

    # Optional: filter by test type
    if test_type:
        test_lower = test_type.strip().lower()
        filtered = []
        for c in centres:
            matching_tests = [t for t in c["tests"] if test_lower in t["name"].lower()]
            if matching_tests:
                c_copy = dict(c)
                c_copy["tests"] = matching_tests
                filtered.append(c_copy)
        centres = filtered

    return {
        "status": "success",
        "state": "Maharashtra",
        "grid": "Aarogya Maharashtra — NHM Public Health Grid",
        "patient_location": {"lat": lat, "lng": lng},
        "radius_km": radius_km,
        "total_centres": len(centres),
        "test_filter": test_type,
        "diagnostic_centres": centres,
        "timestamp": datetime.utcnow().isoformat(),
    }


@router.get("/patient/nearby-pharmacies")
def get_nearby_pharmacies(
    lat: float = 18.5204,
    lng: float = 73.8567,
    radius_km: float = 10.0,
    medicine: Optional[str] = None,
    city: Optional[str] = "Pune",
    db: Session = Depends(get_db),
):
    """
    Location-based nearby pharmacy / medicine availability across Maharashtra.
    Returns PHC pharmacies, Jan Aushadhi stores, and Govt Hospital dispensaries
    with real-time stock status in Pune and Maharashtra healthcare grid.
    """
    pharmacies = [
        {
            "id": "pharm-maha-001",
            "name": "Shivajinagar PHC Pharmacy (सार्वजनिक आरोग्य विभाग)",
            "type": "PHC Pharmacy (NHM Maha)",
            "address": "PHC Campus, Near Shivajinagar Railway Station, Pune - 411005",
            "city": "Pune",
            "lat": 18.5314,
            "lng": 73.8446,
            "distance_km": 0.6,
            "phone": "+91-020-25531234",
            "timings": "8:00 AM – 6:00 PM (सोम-शनि)",
            "is_open": True,
            "medicines": [
                {"name": "Paracetamol 500mg", "stock": 420, "unit": "tablets", "status": "available", "price": "Free (NHM Maha)"},
                {"name": "Cetirizine 10mg", "stock": 210, "unit": "tablets", "status": "available", "price": "Free (NHM Maha)"},
                {"name": "Amoxicillin 500mg", "stock": 65, "unit": "capsules", "status": "low_stock", "price": "Free (NHM Maha)"},
                {"name": "ORS Sachets", "stock": 380, "unit": "sachets", "status": "available", "price": "Free (NHM Maha)"},
                {"name": "Iron + Folic Acid", "stock": 600, "unit": "tablets", "status": "available", "price": "Free (NHM Maha)"},
                {"name": "Metformin 500mg", "stock": 180, "unit": "tablets", "status": "available", "price": "Free (NHM Maha)"},
            ],
        },
        {
            "id": "pharm-maha-002",
            "name": "Sassoon General Hospital Pharmacy (शासकीय ससून रुग्णालय)",
            "type": "Govt Hospital Pharmacy (Maha Health)",
            "address": "Station Road, Near Pune Railway Station, Pune - 411001",
            "city": "Pune",
            "lat": 18.5262,
            "lng": 73.8735,
            "distance_km": 2.8,
            "phone": "+91-020-26128000",
            "timings": "24 Hours (Emergency & OPD)",
            "is_open": True,
            "medicines": [
                {"name": "Paracetamol 500mg", "stock": 1500, "unit": "tablets", "status": "available", "price": "Free (Govt of Maharashtra)"},
                {"name": "Metformin 500mg", "stock": 800, "unit": "tablets", "status": "available", "price": "Free (Govt of Maharashtra)"},
                {"name": "Insulin Glargine", "stock": 85, "unit": "vials", "status": "available", "price": "Free (MJPJAY Scheme)"},
                {"name": "Atorvastatin 20mg", "stock": 350, "unit": "tablets", "status": "available", "price": "Free (Govt of Maharashtra)"},
                {"name": "Amlodipine 5mg", "stock": 420, "unit": "tablets", "status": "available", "price": "Free (Govt of Maharashtra)"},
            ],
        },
        {
            "id": "pharm-maha-003",
            "name": "Pradhan Mantri Jan Aushadhi Kendra — Kothrud",
            "type": "Jan Aushadhi Kendra",
            "address": "Shop No. 4, Paud Road, Near Vanaz Metro Station, Kothrud, Pune - 411038",
            "city": "Pune",
            "lat": 18.5074,
            "lng": 73.8077,
            "distance_km": 3.4,
            "phone": "+91-020-25445678",
            "timings": "9:00 AM – 8:30 PM (Daily)",
            "is_open": True,
            "medicines": [
                {"name": "Paracetamol 500mg", "stock": 650, "unit": "tablets", "status": "available", "price": "₹1.50/strip"},
                {"name": "Metformin 500mg", "stock": 300, "unit": "tablets", "status": "available", "price": "₹3.20/strip"},
                {"name": "Amlodipine 5mg", "stock": 220, "unit": "tablets", "status": "available", "price": "₹2.80/strip"},
                {"name": "Azithromycin 500mg", "stock": 110, "unit": "tablets", "status": "available", "price": "₹8.50/strip"},
                {"name": "Insulin Glargine", "stock": 18, "unit": "vials", "status": "low_stock", "price": "₹126/vial"},
            ],
        },
        {
            "id": "pharm-maha-004",
            "name": "Mauli Medical & General Store — Hadapsar",
            "type": "Private Medical Shop",
            "address": "Pune-Solapur Road, Near Gadital, Hadapsar, Pune - 411028",
            "city": "Pune",
            "lat": 18.5089,
            "lng": 73.9260,
            "distance_km": 5.2,
            "phone": "+91-9822-123456",
            "timings": "7:30 AM – 10:00 PM (Daily)",
            "is_open": True,
            "medicines": [
                {"name": "Paracetamol 500mg", "stock": 500, "unit": "tablets", "status": "available", "price": "₹15/strip"},
                {"name": "Cetirizine 10mg", "stock": 250, "unit": "tablets", "status": "available", "price": "₹12/strip"},
                {"name": "Metformin 500mg", "stock": 220, "unit": "tablets", "status": "available", "price": "₹35/strip"},
                {"name": "Amoxicillin 500mg", "stock": 120, "unit": "capsules", "status": "available", "price": "₹45/strip"},
                {"name": "Insulin Glargine", "stock": 8, "unit": "vials", "status": "low_stock", "price": "₹280/vial"},
            ],
        },
        {
            "id": "pharm-maha-005",
            "name": "Aundh District Hospital Pharmacy (जिल्हा रुग्णालय, औंध)",
            "type": "District Hospital Pharmacy",
            "address": "Chest Hospital Campus, Aundh Camp, Pune - 411027",
            "city": "Pune",
            "lat": 18.5772,
            "lng": 73.8066,
            "distance_km": 7.5,
            "phone": "+91-020-27282000",
            "timings": "24 Hours (Maha Arogya)",
            "is_open": True,
            "medicines": [
                {"name": "Paracetamol 500mg", "stock": 800, "unit": "tablets", "status": "available", "price": "Free (Govt)"},
                {"name": "Amoxicillin 500mg", "stock": 350, "unit": "capsules", "status": "available", "price": "Free (Govt)"},
                {"name": "ORS Sachets", "stock": 500, "unit": "sachets", "status": "available", "price": "Free (Govt)"},
                {"name": "Metformin 500mg", "stock": 400, "unit": "tablets", "status": "available", "price": "Free (Govt)"},
            ],
        },
    ]

    # Optional: filter by medicine name search
    if medicine:
        med_lower = medicine.strip().lower()
        filtered = []
        for p in pharmacies:
            matching_meds = [m for m in p["medicines"] if med_lower in m["name"].lower()]
            if matching_meds:
                p_copy = dict(p)
                p_copy["medicines"] = matching_meds
                filtered.append(p_copy)
        pharmacies = filtered

    return {
        "status": "success",
        "state": "Maharashtra",
        "patient_location": {"lat": lat, "lng": lng, "area": "Shivajinagar, Pune, Maharashtra"},
        "radius_km": radius_km,
        "total_pharmacies": len(pharmacies),
        "medicine_filter": medicine,
        "pharmacies": pharmacies,
        "timestamp": datetime.utcnow().isoformat(),
    }


# -------------------------------------------------------------
# 10. NEARBY DIAGNOSTIC CENTRES (Patient Portal — Maharashtra)
# -------------------------------------------------------------

@router.get("/patient/nearby-diagnostics")
def get_nearby_diagnostics(
    lat: float = 18.5204,
    lng: float = 73.8567,
    radius_km: float = 15.0,
    test_type: Optional[str] = None,
    city: Optional[str] = "Pune",
    db: Session = Depends(get_db),
):
    """
    Location-based nearby diagnostic centre / laboratory availability in Maharashtra.
    Returns PHC labs, Sassoon / District Hospital labs, and NABL private centres
    with available test types, pricing, and turnaround times in Pune & Maharashtra grid.
    """
    centres = [
        {
            "id": "diag-maha-001",
            "name": "Shivajinagar PHC Diagnostic Laboratory (प्राथमिक आरोग्य केंद्र)",
            "type": "PHC Lab (Maha Health Grid)",
            "address": "PHC Campus, Shivajinagar, Pune - 411005",
            "city": "Pune",
            "lat": 18.5314,
            "lng": 73.8446,
            "distance_km": 0.6,
            "phone": "+91-020-25531234",
            "timings": "8:00 AM – 4:30 PM (सोम-शनि)",
            "is_open": True,
            "nabl_accredited": False,
            "tests": [
                {"name": "CBC (Complete Blood Count)", "price": "Free (NHM Maha)", "turnaround": "2 hours", "available": True},
                {"name": "Rapid Malaria Test (RDT)", "price": "Free (NHM Maha)", "turnaround": "30 min", "available": True},
                {"name": "Urine Routine & Microscopy", "price": "Free (NHM Maha)", "turnaround": "1 hour", "available": True},
                {"name": "Blood Glucose (Fasting/PP)", "price": "Free (NHM Maha)", "turnaround": "1 hour", "available": True},
                {"name": "Hemoglobin (Hb)", "price": "Free (NHM Maha)", "turnaround": "30 min", "available": True},
                {"name": "Pregnancy Test (UPT)", "price": "Free (NHM Maha)", "turnaround": "15 min", "available": True},
            ],
        },
        {
            "id": "diag-maha-002",
            "name": "Sassoon General Hospital Central Pathology Lab (ससून रुग्णालय)",
            "type": "Govt Medical College Lab (24x7)",
            "address": "B.J. Govt Medical College & Sassoon Hospital, Pune - 411001",
            "city": "Pune",
            "lat": 18.5262,
            "lng": 73.8735,
            "distance_km": 2.8,
            "phone": "+91-020-26128000",
            "timings": "24 Hours (Emergency Diagnostic Unit)",
            "is_open": True,
            "nabl_accredited": True,
            "tests": [
                {"name": "CBC (Complete Blood Count)", "price": "Free (Govt of Maharashtra)", "turnaround": "2.5 hours", "available": True},
                {"name": "Blood Culture & Sensitivity", "price": "Free (Govt of Maharashtra)", "turnaround": "48 hours", "available": True},
                {"name": "Dengue NS1 + IgM/IgG", "price": "Free (Govt of Maharashtra)", "turnaround": "3 hours", "available": True},
                {"name": "CT Scan (Brain/Abdomen)", "price": "Free (MJPJAY) / ₹800", "turnaround": "2 hours", "available": True},
                {"name": "Ultrasound (Obstetric/Abdominal)", "price": "Free (Govt of Maharashtra)", "turnaround": "1 hour", "available": True},
                {"name": "X-Ray (Chest/Orthopedic)", "price": "Free (Govt of Maharashtra)", "turnaround": "45 min", "available": True},
                {"name": "2D Echo (Cardiac)", "price": "Free (MJPJAY) / ₹500", "turnaround": "2 hours", "available": True},
            ],
        },
        {
            "id": "diag-maha-003",
            "name": "Metropolis Healthcare / Dr. Lal PathLabs — FC Road Branch",
            "type": "Private Diagnostic Chain",
            "address": "Fergusson College Road, Deccan Gymkhana, Pune - 411004",
            "city": "Pune",
            "lat": 18.5196,
            "lng": 73.8415,
            "distance_km": 1.8,
            "phone": "+91-020-41008000",
            "timings": "7:00 AM – 8:30 PM (Daily)",
            "is_open": True,
            "nabl_accredited": True,
            "tests": [
                {"name": "CBC (Complete Blood Count)", "price": "₹280", "turnaround": "4 hours", "available": True},
                {"name": "Lipid Profile", "price": "₹450", "turnaround": "6 hours", "available": True},
                {"name": "Thyroid Panel (T3, T4, TSH)", "price": "₹620", "turnaround": "24 hours", "available": True},
                {"name": "HbA1c (Glycated Hemoglobin)", "price": "₹380", "turnaround": "6 hours", "available": True},
                {"name": "Liver Function Test (LFT)", "price": "₹520", "turnaround": "8 hours", "available": True},
                {"name": "Kidney Function Test (KFT)", "price": "₹480", "turnaround": "8 hours", "available": True},
                {"name": "ECG (12-Lead)", "price": "₹250", "turnaround": "30 min", "available": True},
            ],
        },
        {
            "id": "diag-maha-004",
            "name": "Sahyadri Diagnostic & Imaging Centre — Karve Road",
            "type": "Speciality Diagnostic Centre",
            "address": "Plot No. 30-C, Karve Road, Erandwane, Pune - 411004",
            "city": "Pune",
            "lat": 18.5085,
            "lng": 73.8340,
            "distance_km": 3.5,
            "phone": "+91-020-67213000",
            "timings": "6:30 AM – 9:30 PM (Daily)",
            "is_open": True,
            "nabl_accredited": True,
            "tests": [
                {"name": "Full Body Health Package (Maha Grid)", "price": "₹1,899", "turnaround": "24 hours", "available": True},
                {"name": "CBC + ESR + CRP", "price": "₹420", "turnaround": "4 hours", "available": True},
                {"name": "Thyroid Panel (T3, T4, TSH)", "price": "₹520", "turnaround": "12 hours", "available": True},
                {"name": "Vitamin D + B12", "price": "₹950", "turnaround": "24 hours", "available": True},
                {"name": "MRI Brain/Spine", "price": "₹4,200", "turnaround": "6 hours", "available": True},
                {"name": "CT Angiography", "price": "₹5,500", "turnaround": "4 hours", "available": True},
                {"name": "X-Ray (Chest PA)", "price": "₹350", "turnaround": "1 hour", "available": True},
            ],
        },
        {
            "id": "diag-maha-005",
            "name": "Aundh District Hospital Pathology & Radiology (जिल्हा रुग्णालय, औंध)",
            "type": "District Hospital Lab (Maha Health)",
            "address": "District Hospital Campus, Aundh Camp, Pune - 411027",
            "city": "Pune",
            "lat": 18.5772,
            "lng": 73.8066,
            "distance_km": 7.5,
            "phone": "+91-020-27282000",
            "timings": "24 Hours (Maha Arogya)",
            "is_open": True,
            "nabl_accredited": True,
            "tests": [
                {"name": "CBC (Complete Blood Count)", "price": "Free (Govt)", "turnaround": "3 hours", "available": True},
                {"name": "Blood Glucose (Fasting/PP)", "price": "Free (Govt)", "turnaround": "1 hour", "available": True},
                {"name": "X-Ray (Any Region)", "price": "Free (Govt)", "turnaround": "1 hour", "available": True},
                {"name": "Ultrasound (Sonography)", "price": "Free (Govt)", "turnaround": "2 hours", "available": True},
            ],
        },
    ]

    # Optional: filter by test type
    if test_type:
        test_lower = test_type.strip().lower()
        filtered = []
        for c in centres:
            matching_tests = [t for t in c["tests"] if test_lower in t["name"].lower()]
            if matching_tests:
                c_copy = dict(c)
                c_copy["tests"] = matching_tests
                filtered.append(c_copy)
        centres = filtered

    return {
        "status": "success",
        "patient_location": {"lat": lat, "lng": lng},
        "radius_km": radius_km,
        "total_centres": len(centres),
        "test_filter": test_type,
        "diagnostic_centres": centres,
        "timestamp": datetime.utcnow().isoformat(),
    }

