"""Automated Tests for SwasthyaSetu Twilio Telephony & Voice IVR Routes."""

from fastapi.testclient import TestClient
from app.main import app
from app.database.database import get_db, SessionLocal
from app.models.models import CallSession, Patient, EmergencyEvent
from app.utils.security import hash_phone

client = TestClient(app)


def test_incoming_call_unknown_caller():
    """Incoming call from unknown caller should prompt for 5-digit patient ID or speech."""
    response = client.post(
        "/api/voice/incoming",
        data={"CallSid": "CA_test_unknown_001", "From": "+919999900001"}
    )
    assert response.status_code == 200
    assert "xml" in response.headers.get("content-type", "")
    content = response.text
    assert "<Response>" in content
    assert "Gather" in content
    assert "verify-patient" in content or "process-speech" in content

    # Verify session was created in DB
    db = SessionLocal()
    session = db.query(CallSession).filter(CallSession.call_sid == "CA_test_unknown_001").first()
    assert session is not None
    assert session.status == "INCOMING_CALL_ACTIVE"
    db.close()


def test_incoming_call_known_caller():
    """Incoming call from recognized patient phone should greet directly."""
    db = SessionLocal()
    phone = "+919876543210"
    p_hash = hash_phone(phone)
    existing = db.query(Patient).filter(Patient.phone_hash == p_hash).first()
    if not existing:
        pat = Patient(name="Rani Devi", phone_hash=p_hash, health_id="HID99999", village="Rampur")
        db.add(pat)
        db.commit()
    db.close()

    response = client.post(
        "/api/voice/incoming",
        data={"CallSid": "CA_test_known_002", "From": phone}
    )
    assert response.status_code == 200
    content = response.text
    assert "<Response>" in content
    assert "process-speech" in content
    assert "Rani Devi" in content or "नमस्ते" in content


def test_verify_patient_dtmf():
    """Verify patient ID through DTMF digits."""
    db = SessionLocal()
    # Ensure session exists
    session = db.query(CallSession).filter(CallSession.call_sid == "CA_test_dtmf_003").first()
    if not session:
        session = CallSession(call_sid="CA_test_dtmf_003", status="INCOMING_CALL_ACTIVE")
        db.add(session)
        db.commit()
    db.close()

    response = client.post(
        "/api/voice/verify-patient",
        data={"CallSid": "CA_test_dtmf_003", "Digits": "HID99999"}
    )
    assert response.status_code == 200
    content = response.text
    assert "<Response>" in content
    assert "process-speech" in content


def test_process_speech_emergency():
    """Process speech indicating severe emergency (chest pain and breathlessness)."""
    response = client.post(
        "/api/voice/process-speech",
        data={
            "CallSid": "CA_test_emer_004",
            "SpeechResult": "सीने में बहुत तेज़ दर्द है और सांस लेने में तकलीफ हो रही है"
        }
    )
    assert response.status_code == 200
    content = response.text
    assert "<Response>" in content
    assert "108" in content

    # Verify session persisted emergency
    db = SessionLocal()
    session = db.query(CallSession).filter(CallSession.call_sid == "CA_test_emer_004").first()
    assert session is not None
    assert session.triage_level == "EMERGENCY"
    assert session.risk_score >= 80
    assert session.status == "COMPLETED"
    db.close()


def test_process_speech_routine():
    """Process speech with mild symptoms."""
    response = client.post(
        "/api/voice/process-speech",
        data={
            "CallSid": "CA_test_routine_005",
            "SpeechResult": "हल्का सिरदर्द और जुकाम है"
        }
    )
    assert response.status_code == 200
    content = response.text
    assert "<Response>" in content

    db = SessionLocal()
    session = db.query(CallSession).filter(CallSession.call_sid == "CA_test_routine_005").first()
    assert session is not None
    assert session.triage_level in ("ROUTINE", "URGENT")
    assert session.status == "COMPLETED"
    db.close()


def test_list_calls_endpoint():
    """Verify GET /api/voice/calls returns session history."""
    response = client.get("/api/voice/calls?limit=200")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert any(c["call_sid"] == "CA_test_emer_004" for c in data)

    # Also verify specific call lookup
    resp_single = client.get("/api/voice/calls/CA_test_emer_004")
    assert resp_single.status_code == 200
    assert resp_single.json()["call_sid"] == "CA_test_emer_004"


def test_acknowledge_alert_endpoint():
    """Verify POST /api/voice/alerts/{id}/acknowledge."""
    db = SessionLocal()
    event = EmergencyEvent(
        red_flag_type="Test Alert",
        severity="HIGH",
        status="UNACKNOWLEDGED"
    )
    db.add(event)
    db.commit()
    db.refresh(event)
    event_id = event.id
    db.close()

    response = client.post(f"/api/voice/alerts/{event_id}/acknowledge")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["alert_id"] == event_id

    db = SessionLocal()
    updated = db.query(EmergencyEvent).filter(EmergencyEvent.id == event_id).first()
    assert updated.status == "ACKNOWLEDGED"
    assert updated.acknowledged_at is not None
    db.close()
