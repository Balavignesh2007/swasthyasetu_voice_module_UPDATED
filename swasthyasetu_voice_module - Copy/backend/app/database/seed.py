from datetime import datetime, timedelta
import json
from app.database.database import SessionLocal, init_db
from app.models.models import (
    User, DoctorUser, Facility, Patient, AshaWorker, PatientAshaAssignment,
    Case, Appointment, Consult, Referral, FollowUp, PrescriptionOrder,
    LabOrder, ConsentRecord, FacilityStatus, DoctorRoster, MedicineInventory,
    DiagnosticService, EmergencyEvent, TwoFactorChallenge, Notification
)
from app.utils.security import hash_password

def seed_database():
    init_db()
    db = SessionLocal()
    try:
        # 1. FACILITIES
        phc = db.query(Facility).filter(Facility.id == "fac-phc-001").first()
        if not phc:
            phc = Facility(
                id="fac-phc-001",
                name="Shivaji Nagar PHC",
                facility_type="PHC",
                district="Pune Rural",
                address="Shivaji Nagar, Sector 4",
                emergency_capable=True,
                phone="+91-20-25501001",
                beds_total=20,
                beds_available=14
            )
            db.add(phc)

        rh = db.query(Facility).filter(Facility.id == "fac-rh-001").first()
        if not rh:
            rh = Facility(
                id="fac-rh-001",
                name="Taluka Rural Hospital",
                facility_type="Rural Hospital",
                district="Pune Rural",
                address="Taluka Headquarter Road",
                emergency_capable=True,
                phone="+91-20-25502002",
                beds_total=50,
                beds_available=28
            )
            db.add(rh)

        dh = db.query(Facility).filter(Facility.id == "fac-dh-001").first()
        if not dh:
            dh = Facility(
                id="fac-dh-001",
                name="District General Hospital",
                facility_type="District Hospital",
                district="Pune",
                address="Civil Lines, Pune Central",
                emergency_capable=True,
                phone="+91-20-25503003",
                beds_total=250,
                beds_available=85
            )
            db.add(dh)
        db.commit()

        # 2. SEED USERS (All 6 Roles)
        users_data = [
            # 1. Patient Demo
            {"id": "usr-patient-001", "username": "patient_demo", "password": "patient123", "name": "Ramesh Patil", "role": "patient", "fac": "fac-phc-001", "2fa": False},
            # 2. Health Worker Demo (ASHA)
            {"id": "usr-asha-001", "username": "asha_demo", "password": "asha123", "name": "Sunita Kamble (ASHA)", "role": "health_worker", "fac": "fac-phc-001", "2fa": False},
            # 3. Doctor Demo
            {"id": "usr-doctor-001", "username": "dr.sharma", "password": "doctor123", "name": "Dr. Rajesh Sharma", "role": "doctor", "fac": "fac-phc-001", "2fa": True},
            # 4. Pharmacy Staff Demo
            {"id": "usr-pharma-001", "username": "pharma_demo", "password": "pharma123", "name": "Anil Deshmukh (Pharmacist)", "role": "pharmacy", "fac": "fac-phc-001", "2fa": True},
            # 5. Lab Technician Demo
            {"id": "usr-lab-001", "username": "lab_demo", "password": "lab123", "name": "Pooja Shinde (Lab Tech)", "role": "lab", "fac": "fac-phc-001", "2fa": True},
            # 6. PHC Administration Demo
            {"id": "usr-admin-001", "username": "phc_admin", "password": "admin123", "name": "Shivaji Nagar PHC Admin", "role": "phc_admin", "fac": "fac-phc-001", "2fa": True},
        ]

        for u in users_data:
            existing = db.query(User).filter(User.username == u["username"]).first()
            if not existing:
                nu = User(
                    id=u["id"],
                    username=u["username"],
                    hashed_password=hash_password(u["password"]),
                    name=u["name"],
                    role=u["role"],
                    facility_id=u["fac"],
                    two_factor_enabled=u["2fa"],
                    is_active=True
                )
                db.add(nu)

            # Doctor compatibility record
            if u["role"] == "doctor":
                doc = db.query(DoctorUser).filter(DoctorUser.username == u["username"]).first()
                if not doc:
                    doc = DoctorUser(
                        id=u["id"],
                        name=u["name"],
                        username=u["username"],
                        hashed_password=hash_password(u["password"]),
                        role="doctor",
                        speciality="General Medicine",
                        facility_id=u["fac"],
                        is_active=True
                    )
                    db.add(doc)
            elif u["role"] == "phc_admin":
                # Legacy admin entry
                adm = db.query(DoctorUser).filter(DoctorUser.username == "admin").first()
                if not adm:
                    adm = DoctorUser(
                        id="doc-legacy-admin",
                        name="PHC Medical Officer Admin",
                        username="admin",
                        hashed_password=hash_password("admin123"),
                        role="admin",
                        speciality="Administration",
                        facility_id="fac-phc-001",
                        is_active=True
                    )
                    db.add(adm)

        # 3. PATIENTS (Identity separate from clinical case)
        patients_data = [
            {"id": "pat-001", "name": "Ramesh Patil", "health_id": "HID10001", "phone_hash": "hash_9000000001", "cid": "CID-PATIL-001", "village": "Shivaji Nagar", "lang": "mr"},
            {"id": "pat-002", "name": "Priya Jadhav", "health_id": "HID10002", "phone_hash": "hash_9000000002", "cid": "CID-JADHAV-002", "village": "Wadgaon", "lang": "hi"},
            {"id": "pat-003", "name": "Kavita Shinde", "health_id": "HID10003", "phone_hash": "hash_9000000003", "cid": "CID-SHINDE-003", "village": "Khed", "lang": "mr"},
            {"id": "pat-004", "name": "Balavignesh", "health_id": "HID2602008", "phone_hash": "hash_9121458655", "cid": "CID-BALA-004", "village": "Shivaji Nagar", "lang": "en"},
            {"id": "pat-005", "name": "Harsha datta", "health_id": "HID903025", "phone_hash": "hash_9030252566", "cid": "CID-HARSHA-005", "village": "Shivaji Nagar", "lang": "te"},
        ]
        for p in patients_data:
            existing = db.query(Patient).filter(Patient.id == p["id"]).first()
            if not existing:
                db.add(Patient(
                    id=p["id"],
                    name=p["name"],
                    health_id=p["health_id"],
                    phone_hash=p["phone_hash"],
                    controlled_identity_key=p["cid"],
                    village=p["village"],
                    preferred_language=p["lang"]
                ))
        db.commit()

        # ASHA Worker entity
        asha = db.query(AshaWorker).filter((AshaWorker.id == "asha-001") | (AshaWorker.phone == "9876543210")).first()
        if not asha:
            asha = AshaWorker(id="asha-001", name="Sunita Kamble", phone="9876543210", is_active=True)
            db.add(asha)
            db.commit()

        # 4. CASES (1 Routine, 1 Review, 1 Urgent)
        cases_data = [
            {
                "id": "case-001",
                "patient_id": "pat-001",
                "symptom_text": "Mild fever and sore throat for 2 days. No breathing difficulty.",
                "language": "en",
                "severity": "routine",
                "status": "in_consultation",
                "source": "patient_app",
                "created_at": datetime.utcnow() - timedelta(hours=2)
            },
            {
                "id": "case-002",
                "patient_id": "pat-002",
                "symptom_text": "Severe persistent headache, blurred vision, and high blood pressure check needed (known hypertension).",
                "language": "en",
                "severity": "review",
                "status": "open",
                "source": "health_worker_app",
                "created_at": datetime.utcnow() - timedelta(hours=1)
            },
            {
                "id": "case-003",
                "patient_id": "pat-003",
                "symptom_text": "Crushing chest pain radiating to left arm, profuse sweating, extreme shortness of breath.",
                "language": "en",
                "severity": "urgent",
                "status": "closed",
                "source": "patient_app",
                "created_at": datetime.utcnow() - timedelta(days=1, hours=3)
            }
        ]
        for c in cases_data:
            if not db.query(Case).filter(Case.id == c["id"]).first():
                db.add(Case(**c))
        db.commit()

        # 5. APPOINTMENTS (Multiple queue numbers, available doctor, completed, no-show)
        now = datetime.utcnow()
        appts_data = [
            {
                "id": "appt-001",
                "case_id": "case-001",
                "patient_id": "pat-001",
                "doctor_id": "usr-doctor-001",
                "facility_id": "fac-phc-001",
                "scheduled_time": now - timedelta(minutes=45),
                "slot_time": "10:00 AM",
                "status": "checked_in",
                "queue_number": 1,
                "check_in_time": now - timedelta(minutes=24),
                "notes": "Patient checked in and waiting in OPD Lobby.",
                "speciality": "General Medicine"
            },
            {
                "id": "appt-002",
                "case_id": "case-002",
                "patient_id": "pat-002",
                "doctor_id": "usr-doctor-001",
                "facility_id": "fac-phc-001",
                "scheduled_time": now + timedelta(minutes=30),
                "slot_time": "10:30 AM",
                "status": "booked",
                "queue_number": 2,
                "notes": "Hypertension review slot booked via ASHA worker.",
                "speciality": "General Medicine"
            },
            {
                "id": "appt-003",
                "case_id": "case-003",
                "patient_id": "pat-003",
                "doctor_id": "usr-doctor-001",
                "facility_id": "fac-phc-001",
                "scheduled_time": now - timedelta(days=1, hours=2),
                "slot_time": "09:30 AM",
                "status": "completed",
                "queue_number": 1,
                "check_in_time": now - timedelta(days=1, hours=2, minutes=20),
                "start_service_time": now - timedelta(days=1, hours=2),
                "completed_at": now - timedelta(days=1, hours=1, minutes=30),
                "diagnosis": "Acute Anginal Syndrome / Urgent Cardiac Triage",
                "prescription": "Aspirin 300mg stat, Sorbitrate 5mg SL, Immediate 108 Cardiac Ambulance referral",
                "speciality": "General Medicine"
            },
            {
                "id": "appt-004",
                "case_id": None,
                "patient_id": "pat-004",
                "doctor_id": "usr-doctor-001",
                "facility_id": "fac-phc-001",
                "scheduled_time": now - timedelta(days=2),
                "slot_time": "11:00 AM",
                "status": "no_show",
                "queue_number": 4,
                "notes": "Patient did not report to PHC during grace period.",
                "speciality": "General Medicine"
            }
        ]
        for a in appts_data:
            if not db.query(Appointment).filter(Appointment.id == a["id"]).first():
                db.add(Appointment(**a))
        db.commit()

        # 6. REFERRALS (1 Completed, 1 Pending)
        referrals_data = [
            {
                "id": "ref-001",
                "case_id": "case-003",
                "patient_id": "pat-003",
                "from_facility_id": "fac-phc-001",
                "to_facility_id": "fac-dh-001",
                "status": "completed",
                "urgency": "EMERGENCY",
                "reason": "Emergency cardiac evaluation and Cath Lab intervention required."
            },
            {
                "id": "ref-002",
                "case_id": "case-002",
                "patient_id": "pat-002",
                "from_facility_id": "fac-phc-001",
                "to_facility_id": "fac-rh-001",
                "status": "requested",
                "urgency": "URGENT",
                "reason": "Specialist ultrasound Doppler and neurological assessment for persistent hypertension."
            }
        ]
        for r in referrals_data:
            if not db.query(Referral).filter(Referral.id == r["id"]).first():
                db.add(Referral(**r))
        db.commit()

        # 7. PRESCRIPTIONS (1 Pending, 1 Dispensed)
        rx_data = [
            {
                "id": "rx-001",
                "case_id": "case-001",
                "doctor_id": "usr-doctor-001",
                "patient_id": "pat-001",
                "facility_id": "fac-phc-001",
                "medicine_list": json.dumps([
                    {"medicine": "Paracetamol 500mg", "dosage": "1 tablet TDS", "duration": "3 days", "quantity": 9},
                    {"medicine": "Cetirizine 10mg", "dosage": "1 tablet HS", "duration": "3 days", "quantity": 3}
                ]),
                "instructions": "Take after meals. Drink warm water.",
                "status": "pending"
            },
            {
                "id": "rx-002",
                "case_id": "case-003",
                "doctor_id": "usr-doctor-001",
                "patient_id": "pat-003",
                "facility_id": "fac-phc-001",
                "medicine_list": json.dumps([
                    {"medicine": "Aspirin 300mg (Dispersible)", "dosage": "Stat", "duration": "1 day", "quantity": 1},
                    {"medicine": "Sorbitrate 5mg", "dosage": "Sublingual stat", "duration": "1 day", "quantity": 1}
                ]),
                "instructions": "Administered under emergency supervision during ambulance transfer.",
                "status": "dispensed",
                "dispensed_at": now - timedelta(days=1, hours=2)
            }
        ]
        for rx in rx_data:
            if not db.query(PrescriptionOrder).filter(PrescriptionOrder.id == rx["id"]).first():
                db.add(PrescriptionOrder(**rx))
        db.commit()

        # 8. LAB ORDERS (1 Completed, 1 Pending)
        lab_data = [
            {
                "id": "lab-001",
                "case_id": "case-001",
                "doctor_id": "usr-doctor-001",
                "patient_id": "pat-001",
                "facility_id": "fac-phc-001",
                "test_type": "Rapid Malaria Antigen Test",
                "status": "pending",
                "result_ref": None,
                "result_summary": None
            },
            {
                "id": "lab-002",
                "case_id": "case-003",
                "doctor_id": "usr-doctor-001",
                "patient_id": "pat-003",
                "facility_id": "fac-phc-001",
                "test_type": "Complete Blood Count (CBC) & Trop-I",
                "status": "result_uploaded",
                "result_ref": "LAB-RPT-2026-0042",
                "result_summary": "Hb: 13.8 g/dL, WBC: 9,200/mcL, Platelets: 2.1 Lakhs, Troponin-I: Elevated (0.85 ng/mL - Critical).",
                "sample_collected_at": now - timedelta(days=1, hours=2, minutes=15),
                "completed_at": now - timedelta(days=1, hours=1, minutes=45)
            }
        ]
        for l in lab_data:
            if not db.query(LabOrder).filter(LabOrder.id == l["id"]).first():
                db.add(LabOrder(**l))
        db.commit()

        # 9. MEDICINE INVENTORY (Available, Low Stock, Out of Stock)
        medicines = [
            {"name": "Paracetamol 500mg", "qty": 450, "unit": "tablets", "min": 50, "status": "available"},
            {"name": "Amoxicillin 500mg", "qty": 180, "unit": "capsules", "min": 40, "status": "available"},
            {"name": "ORS Packets", "qty": 18, "unit": "pouches", "min": 25, "status": "low_stock"},
            {"name": "Iron & Folic Acid", "qty": 15, "unit": "strips", "min": 30, "status": "low_stock"},
            {"name": "Insulin Regular 100IU", "qty": 0, "unit": "vials", "min": 10, "status": "out_of_stock"},
            {"name": "Anti-Rabies Vaccine (ARV)", "qty": 0, "unit": "vials", "min": 5, "status": "out_of_stock"},
            {"name": "Amlodipine 5mg", "qty": 320, "unit": "tablets", "min": 50, "status": "available"},
        ]
        for m in medicines:
            existing = db.query(MedicineInventory).filter(
                MedicineInventory.facility_id == "fac-phc-001",
                MedicineInventory.medicine_name == m["name"]
            ).first()
            if not existing:
                db.add(MedicineInventory(
                    facility_id="fac-phc-001",
                    medicine_name=m["name"],
                    stock_quantity=m["qty"],
                    unit=m["unit"],
                    min_threshold=m["min"],
                    status=m["status"]
                ))
        db.commit()

        # 10. DIAGNOSTIC SERVICES (Available vs Unavailable)
        diagnostics = [
            {"name": "Complete Blood Count (CBC)", "avail": True, "tat": 2},
            {"name": "Blood Glucose (Random/Fasting)", "avail": True, "tat": 1},
            {"name": "Urine Routine & Microscopy", "avail": True, "tat": 2},
            {"name": "Rapid Malaria Antigen", "avail": True, "tat": 1},
            {"name": "Sputum AFB (Tuberculosis)", "avail": True, "tat": 24},
            {"name": "Rapid Dengue NS1/IgM", "avail": True, "tat": 1},
            {"name": "Digital Chest X-Ray", "avail": False, "tat": 12},  # Unavailable at PHC -> Referred
            {"name": "Ultrasound Sonography (USG)", "avail": False, "tat": 24}, # Unavailable at PHC
        ]
        for d in diagnostics:
            existing = db.query(DiagnosticService).filter(
                DiagnosticService.facility_id == "fac-phc-001",
                DiagnosticService.test_name == d["name"]
            ).first()
            if not existing:
                db.add(DiagnosticService(
                    facility_id="fac-phc-001",
                    test_name=d["name"],
                    available=d["avail"],
                    turn_around_hours=d["tat"]
                ))
        db.commit()

        # 11. FOLLOW-UPS (Maternal, Chronic, Child, Elderly)
        followups = [
            {
                "id": "fu-001",
                "patient_id": "pat-002",
                "asha_id": "usr-asha-001",
                "facility_id": "fac-phc-001",
                "doctor_id": "usr-doctor-001",
                "category": "maternal",
                "title": "ANC 3rd Trimester Blood Pressure & Hemoglobin Check",
                "due_date": now + timedelta(days=2),
                "next_checkin_date": now + timedelta(days=2),
                "status": "pending",
                "priority": "HIGH",
                "notes": "Monitor for pre-eclampsia symptoms. Check pedal edema."
            },
            {
                "id": "fu-002",
                "patient_id": "pat-001",
                "asha_id": "usr-asha-001",
                "facility_id": "fac-phc-001",
                "doctor_id": "usr-doctor-001",
                "category": "chronic",
                "title": "Monthly Hypertension & Sugar Control Follow-up",
                "due_date": now - timedelta(days=5),
                "next_checkin_date": now - timedelta(days=5),
                "status": "completed",
                "completed_at": now - timedelta(days=5, hours=2),
                "priority": "NORMAL",
                "notes": "BP stable at 126/82 mmHg. Advised low salt diet."
            },
            {
                "id": "fu-003",
                "patient_id": "pat-003",
                "asha_id": "usr-asha-001",
                "facility_id": "fac-phc-001",
                "doctor_id": "usr-doctor-001",
                "category": "child",
                "title": "Pentavalent-3 Vaccine & Growth Monitoring Check",
                "due_date": now + timedelta(days=4),
                "next_checkin_date": now + timedelta(days=4),
                "status": "pending",
                "priority": "NORMAL",
                "notes": "Child weight 8.2 kg, check immunization card."
            }
        ]
        for f in followups:
            if not db.query(FollowUp).filter(FollowUp.id == f["id"]).first():
                db.add(FollowUp(**f))
        db.commit()

        # 12. FACILITY STATUS & DOCTOR ROSTER
        fac_stat = db.query(FacilityStatus).filter(FacilityStatus.facility_id == "fac-phc-001").first()
        if not fac_stat:
            fac_stat = FacilityStatus(
                facility_id="fac-phc-001",
                doctor_id="usr-doctor-001",
                available=True,
                manually_toggled=False,
                roster_shift_start="09:00",
                roster_shift_end="17:00",
                beds_available=14
            )
            db.add(fac_stat)

        roster = db.query(DoctorRoster).filter(DoctorRoster.doctor_id == "usr-doctor-001").first()
        if not roster:
            roster = DoctorRoster(
                doctor_id="usr-doctor-001",
                facility_id="fac-phc-001",
                shift_start="09:00",
                shift_end="17:00",
                day_of_week="Monday-Saturday",
                is_on_duty=True
            )
            db.add(roster)
        db.commit()

        # 13. EMERGENCY EVENT
        emer = db.query(EmergencyEvent).filter(EmergencyEvent.id == "emer-001").first()
        if not emer:
            emer = EmergencyEvent(
                id="emer-001",
                case_id="case-003",
                patient_id="pat-003",
                asha_id="usr-asha-001",
                red_flag_type="ACUTE_CHEST_PAIN_CARDIAC",
                severity="HIGH",
                status="RESOLVED",
                triggered_via="app_trigger",
                connected_to_108_at=now - timedelta(days=1, hours=3),
                asha_notified_at=now - timedelta(days=1, hours=2, minutes=58),
                phc_notified_at=now - timedelta(days=1, hours=2, minutes=55),
                acknowledged_at=now - timedelta(days=1, hours=2, minutes=50),
                resolved_at=now - timedelta(days=1, hours=1)
            )
            db.add(emer)
        db.commit()

        # 14. CONSENT RECORD (Tiered)
        consent = db.query(ConsentRecord).filter(ConsentRecord.id == "con-001").first()
        if not consent:
            consent = ConsentRecord(
                id="con-001",
                patient_id="pat-001",
                requested_by="usr-doctor-001",
                scope="tier_2_records",
                status="active",
                expires_at=now + timedelta(days=30)
            )
            db.add(consent)
        db.commit()

        print("SwasthyaSetu AI: Seed data successfully initialized for all 6 roles and PHC administration.")
    finally:
        db.close()

if __name__ == "__main__":
    seed_database()
