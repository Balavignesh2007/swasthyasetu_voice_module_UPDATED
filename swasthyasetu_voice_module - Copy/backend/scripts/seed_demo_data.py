"""
Seeds complete multi-role demo data: areas, facilities, ASHA workers,
patients, role-based accounts (Doctor, Facility Admin, Helpline, System Admin),
and realistic clinical follow-ups.

Run after database initialization:
    python scripts/seed_demo_data.py
"""
import sys
from datetime import datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.database.database import SessionLocal, init_db
from app.models.models import (
    Area, Facility, AshaWorker, Patient, PatientAshaAssignment,
    DoctorUser, PatientFollowUp, ClinicalVoiceNote
)
from app.utils.security import hash_phone, hash_password, normalize_to_e164


def main():
    init_db()
    db = SessionLocal()
    try:
        # Clear existing seed test records to avoid duplicate key errors
        db.query(PatientFollowUp).delete()
        db.query(ClinicalVoiceNote).delete()
        db.query(PatientAshaAssignment).delete()
        db.query(DoctorUser).delete()
        db.query(Patient).delete()
        db.query(AshaWorker).delete()
        db.query(Facility).delete()
        db.query(Area).delete()
        db.commit()

        # 1. Area
        area = Area(name="Anantapur Rural Block")
        db.add(area)
        db.flush()

        # 2. Facilities
        phc = Facility(
            name="Anantapur PHC",
            facility_type="PHC",
            specialities="General Medicine, Pediatrics, Maternal Care",
            services_description="Primary health center offering general consultations, maternal care, and basic diagnostics.",
            area_id=area.id,
        )
        district_hospital = Facility(
            name="Anantapur District Hospital",
            facility_type="District Hospital",
            specialities="Cardiology, Pulmonology, General Medicine, Neurology, Emergency",
            services_description="Multi-speciality district hospital with emergency, cardiology, pulmonology, and neurology departments.",
            area_id=area.id,
        )
        db.add_all([phc, district_hospital])
        db.flush()

        # 3. ASHA Worker
        asha = AshaWorker(
            name="Lakshmi Devi",
            phone="+919876543210",
            facility_id=phc.id,
            area_id=area.id,
            status="active",
        )
        asha2 = AshaWorker(
            name="Ananya Sharma",
            phone="+919876543211",
            facility_id=phc.id,
            area_id=area.id,
            status="active",
        )
        db.add_all([asha, asha2])
        db.flush()

        # 4. Patients
        p1 = Patient(
            name="Demo Patient",
            health_id="HID10001",
            phone_hash=hash_phone(normalize_to_e164("+919000000001")),
            village="Anantapur Central",
            area_id=area.id,
            facility_id=phc.id,
            preferred_language="te",
        )
        p2 = Patient(
            name="Ramesh Kumar",
            health_id="HID10002",
            phone_hash=hash_phone(normalize_to_e164("+919000000002")),
            village="Kalyandurg Village",
            area_id=area.id,
            facility_id=phc.id,
            preferred_language="hi",
        )
        p3 = Patient(
            name="Sunita Devi",
            health_id="HID10003",
            phone_hash=hash_phone(normalize_to_e164("+919000000003")),
            village="Singanamala Village",
            area_id=area.id,
            facility_id=phc.id,
            preferred_language="te",
        )
        db.add_all([p1, p2, p3])
        db.flush()

        # Assign patients to ASHA workers
        for p in [p1, p2, p3]:
            db.add(PatientAshaAssignment(patient_id=p.id, asha_id=asha.id, status="active"))
            db.add(PatientAshaAssignment(patient_id=p.id, asha_id=asha2.id, status="active"))

        # 5. Role-based Logins
        # Doctor
        doc = DoctorUser(
            name="Dr. Anjali Sharma",
            username="dr.sharma",
            phone="+919812345678",
            hashed_password=hash_password("doctor123"),
            role="doctor",
            speciality="General Medicine",
            facility_id=district_hospital.id,
        )
        # Facility Admin
        fac_admin = DoctorUser(
            name="Facility Operations Admin",
            username="fac.admin",
            phone="+919811122233",
            hashed_password=hash_password("admin123"),
            role="facility_admin",
            speciality="Administration",
            facility_id=phc.id,
        )
        # Helpline Worker
        helpline_worker = DoctorUser(
            name="Helpline Officer Rajesh",
            username="helpline.worker",
            phone="+919844455566",
            hashed_password=hash_password("helpline123"),
            role="helpline_worker",
            speciality="Triage & Tele-Support",
            facility_id=district_hospital.id,
        )
        # System Admin
        sys_admin = DoctorUser(
            name="System Administrator",
            username="admin",
            phone="+919800000000",
            hashed_password=hash_password("admin12345"),
            role="system_admin",
            facility_id=district_hospital.id,
        )
        db.add_all([doc, fac_admin, helpline_worker, sys_admin])
        db.flush()

        # 6. Follow-up Tasks for ASHA Worker
        now = datetime.utcnow()
        f1 = PatientFollowUp(
            patient_id=p2.id,
            asha_id=asha.id,
            facility_id=phc.id,
            doctor_id=doc.id,
            title="Post-discharge breathing & medication check",
            due_date=now,  # Due today
            status="pending",
            priority="HIGH",
            notes="Patient had severe cough and breathlessness. Check inhaler usage and oxygen levels.",
        )
        f2 = PatientFollowUp(
            patient_id=p3.id,
            asha_id=asha.id,
            facility_id=phc.id,
            doctor_id=doc.id,
            title="Maternal iron & calcium supplementation",
            due_date=now - timedelta(days=2),  # Overdue
            status="overdue",
            priority="NORMAL",
            notes="24-week antenatal check. Confirm tablet consumption and schedule next scan.",
        )
        f3 = PatientFollowUp(
            patient_id=p1.id,
            asha_id=asha.id,
            facility_id=phc.id,
            doctor_id=doc.id,
            title="Hypertension routine BP recording",
            due_date=now + timedelta(days=3),  # Upcoming
            status="pending",
            priority="NORMAL",
            notes="Check morning blood pressure and record values.",
        )
        # 7. Clinical Voice Notes
        vn1 = ClinicalVoiceNote(
            patient_id=p2.id,
            asha_id=asha.id,
            doctor_id=doc.id,
            author_role="asha",
            raw_transcript="मरीज को दो दिन से तेज बुखार और सांस फूलने की शिकायत है।",
            translated_text="Patient reports high fever and breathlessness for the past two days.",
            language="hi",
            extracted_symptoms='["Fever", "Difficulty Breathing"]',
            confirmed_symptoms='["Fever", "Difficulty Breathing"]',
            is_emergency=True,
            red_flag_type="Severe Difficulty Breathing",
            clinical_summary="Field assessment: High respiratory rate observed. Advised immediate oxygen saturation monitoring at PHC.",
            sync_status="synced",
        )
        vn2 = ClinicalVoiceNote(
            patient_id=p1.id,
            asha_id=asha.id,
            author_role="asha",
            raw_transcript="नियमित रक्तचाप परीक्षण: बीपी 130/84 सामान्य पाया गया।",
            translated_text="Routine blood pressure check: BP found normal at 130/84.",
            language="hi",
            extracted_symptoms='[]',
            confirmed_symptoms='[]',
            is_emergency=False,
            clinical_summary="Patient advised to maintain low-sodium diet and continue prescribed morning medication.",
            sync_status="synced",
        )
        db.add_all([f1, f2, f3, vn1, vn2])
        db.commit()

        print("==========================================================")
        print(" SwasthyaSetu Demo Database Successfully Initialized! ")
        print("==========================================================")
        print(" Seeded Accounts & Logins:")
        print("  1. [Patient] Health ID 'HID10001', Phone '+919000000001'")
        print("  2. [ASHA Worker] Phone '9876543210' or '+919876543210'")
        print("  3. [Doctor] User 'dr.sharma' / Pass 'doctor123'")
        print("  4. [Facility Admin] User 'fac.admin' / Pass 'admin123'")
        print("  5. [Helpline Worker] User 'helpline.worker' / Pass 'helpline123'")
        print("  6. [System Admin] User 'admin' / Pass 'admin12345'")
        print(" Seeded 3 Patients, 3 Assigned Follow-ups, and 2 Clinical Voice Notes.")
        print("==========================================================")
    finally:
        db.close()


if __name__ == "__main__":
    main()
