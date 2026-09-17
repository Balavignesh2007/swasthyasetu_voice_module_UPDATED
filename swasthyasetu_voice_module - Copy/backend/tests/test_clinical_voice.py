import unittest
from datetime import datetime, timedelta
from fastapi.testclient import TestClient

from app.main import app
from app.database.database import SessionLocal
from app.models.models import AshaWorker, Patient, PatientAshaAssignment


class ClinicalVoiceAndAshaWorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)
        db = SessionLocal()
        try:
            # Ensure at least one demo ASHA worker exists
            worker = db.query(AshaWorker).filter(AshaWorker.phone == "+919876543210").first()
            if not worker:
                worker = AshaWorker(
                    name="Lakshmi Devi",
                    phone="+919876543210",
                    is_active=True,
                )
                db.add(worker)
                db.commit()
                db.refresh(worker)
            cls.asha_id = worker.id

            # Ensure at least one demo patient exists
            patient = db.query(Patient).first()
            if not patient:
                patient = Patient(
                    name="Ramesh Kumar",
                    phone_hash="hash_dummy",
                    health_id="ABHA-1234-5678-9012",
                    village="Rampur",
                    preferred_language="hi",
                )
                db.add(patient)
                db.commit()
                db.refresh(patient)
            cls.patient_id = patient.id

            # Ensure assignment exists
            assign = db.query(PatientAshaAssignment).filter(
                PatientAshaAssignment.asha_id == cls.asha_id,
                PatientAshaAssignment.patient_id == cls.patient_id,
            ).first()
            if not assign:
                assign = PatientAshaAssignment(
                    asha_id=cls.asha_id,
                    patient_id=cls.patient_id,
                    status="active",
                )
                db.add(assign)
                db.commit()
        finally:
            db.close()

    def test_01_process_voice_hindi_emergency(self):
        """Hindi speech with chest pain and breathing difficulty triggers immediate emergency."""
        response = self.client.post(
            "/api/v1/clinical/process-voice",
            json={"transcript": "सीने में बहुत तेज़ दर्द है और सांस लेने में तकलीफ हो रही है"},
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["detected_language"], "hi")
        self.assertTrue(data["emergency"]["is_emergency"])
        self.assertIn("Severe", data["emergency"]["red_flag_type"])
        self.assertEqual(data["triage_level"], "EMERGENCY")
        self.assertIn("CRITICAL RED FLAG", data["suggested_action"])

    def test_02_process_voice_telugu_emergency(self):
        """Telugu speech with severe chest pain triggers immediate emergency."""
        response = self.client.post(
            "/api/v1/clinical/process-voice",
            json={"transcript": "గుండె నొప్పి మరియు శ్వాస ఆడటం లేదు"},
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["detected_language"], "te")
        self.assertTrue(data["emergency"]["is_emergency"])
        self.assertEqual(data["triage_level"], "EMERGENCY")

    def test_03_process_voice_tamil_emergency(self):
        """Tamil speech with chest pain triggers emergency."""
        response = self.client.post(
            "/api/v1/clinical/process-voice",
            json={"transcript": "நெஞ்சு வலி மற்றும் மூச்சு விடுவதில் சிரமம்"},
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["detected_language"], "ta")
        self.assertTrue(data["emergency"]["is_emergency"])

    def test_04_process_voice_routine_care_low_risk(self):
        """Mild symptoms without red flags trigger standard low-risk classification."""
        response = self.client.post(
            "/api/v1/clinical/process-voice",
            json={"transcript": "हल्का सिरदर्द है और दो दिन से हल्की खांसी है"},
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertFalse(data["emergency"]["is_emergency"])
        self.assertEqual(data["triage_level"], "ROUTINE")

    def test_05_voice_note_creation_triggers_emergency_event(self):
        """Saving a clinical voice note marked with an emergency automatically creates an unacknowledged alert."""
        payload = {
            "patient_id": self.patient_id,
            "asha_id": self.asha_id,
            "raw_transcript": "Patient collapsed and has severe chest pain",
            "translated_text": "Patient collapsed and has severe chest pain",
            "language": "en",
            "extracted_symptoms": ["Chest Pain", "Loss of Consciousness"],
            "confirmed_symptoms": ["Chest Pain"],
            "is_emergency": True,
            "red_flag_type": "Severe Chest Pain",
            "clinical_summary": "Urgent attention needed for adult male with sudden chest pain.",
        }
        res = self.client.post("/api/v1/asha/voice-notes", json=payload)
        self.assertEqual(res.status_code, 200)
        note_data = res.json()
        self.assertEqual(note_data["is_emergency"], True)
        self.assertEqual(note_data["red_flag_type"], "Severe Chest Pain")

        # Verify an emergency alert was created
        alerts_res = self.client.get(f"/api/v1/asha/alerts?asha_id={self.asha_id}&status=UNACKNOWLEDGED")
        self.assertEqual(alerts_res.status_code, 200)
        alerts = alerts_res.json()
        self.assertTrue(any(a["red_flag_type"] == "Severe Chest Pain" for a in alerts))

    def test_06_follow_up_lifecycle(self):
        """ASHA follow-up task creation, retrieval, and status completion."""
        due = (datetime.utcnow() + timedelta(days=2)).isoformat()
        payload = {
            "patient_id": self.patient_id,
            "asha_id": self.asha_id,
            "title": "Maternal health iron-folic acid replenishment",
            "due_date": due,
            "priority": "HIGH",
            "notes": "Ensure 30 days IFA tablet supply is handed over and compliance verified.",
        }
        create_res = self.client.post("/api/v1/asha/follow-ups", json=payload)
        self.assertEqual(create_res.status_code, 200)
        created = create_res.json()
        fu_id = created["id"]
        self.assertEqual(created["status"], "pending")

        # List follow-ups
        list_res = self.client.get(f"/api/v1/asha/{self.asha_id}/follow-ups")
        self.assertEqual(list_res.status_code, 200)
        self.assertTrue(any(f["id"] == fu_id for f in list_res.json()))

        # Mark completed
        patch_res = self.client.patch(
            f"/api/v1/asha/follow-ups/{fu_id}",
            json={"status": "completed", "notes": "Tablets delivered and taken."},
        )
        self.assertEqual(patch_res.status_code, 200)
        self.assertEqual(patch_res.json()["status"], "completed")

    def test_07_offline_sync_batch_reconciliation(self):
        """Reconciliation of offline queued voice notes, follow-up updates, and alert acknowledgements."""
        # Create an event to acknowledge
        event_res = self.client.post(
            "/api/v1/emergency-events",
            json={
                "call_session_id": "session-offline-test",
                "red_flag_type": "Severe Bleeding",
                "severity": "HIGH",
            },
        )
        self.assertEqual(event_res.status_code, 200)
        event_id = event_res.json()["id"]

        sync_payload = {
            "asha_id": self.asha_id,
            "items": [
                {
                    "client_id": "queue_item_1",
                    "type": "voice_note",
                    "data": {
                        "patient_id": self.patient_id,
                        "raw_transcript": "Field recording offline: blood pressure 118/76 normal",
                        "is_emergency": False,
                        "clinical_summary": "Routine vitals recorded offline.",
                    },
                },
                {
                    "client_id": "queue_item_2",
                    "type": "alert_ack",
                    "data": {
                        "event_id": event_id,
                        "status": "ACKNOWLEDGED",
                    },
                },
            ],
        }

        sync_res = self.client.post("/api/v1/asha/sync", json=sync_payload)
        self.assertEqual(sync_res.status_code, 200)
        result = sync_res.json()
        self.assertEqual(result["synced_count"], 2)
        self.assertEqual(result["failed_count"], 0)
        self.assertTrue(all(r["status"] == "success" for r in result["results"]))


if __name__ == "__main__":
    unittest.main()
