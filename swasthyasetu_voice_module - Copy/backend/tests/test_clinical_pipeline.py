"""Comprehensive Clinical Pipeline Test Suite.
Tests normalization, entity extraction, feature building, safety layer overrides,
care pathways, appointment management, and the unified healthcare API.
"""

import pytest
from fastapi.testclient import TestClient
from app.main import app
from src.normalization.normalizer import clinical_normalizer
from src.triage.danger_sign_rules import evaluate_danger_signs
from src.triage.prediction import triage_engine
from src.care_pathway.care_pathway import determine_care_pathway

@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client

def test_normalization_and_negation_preservation():
    # Test case from spec: "I don't have fever but I have severe chest pain."
    record = clinical_normalizer.normalize("I don't have fever but I have severe chest pain.")
    assert "chest pain" in record.present_symptoms or "chest_pain" in record.canonical_symptoms
    assert "fever" in record.negated_symptoms
    # Crucial safety check: fever must NOT be present in present_symptoms
    assert "fever" not in record.present_symptoms
    assert record.severity_map.get("chest pain") == "severe"

def test_normalization_spelling_and_duration():
    # Test case from spec: "I hav seveer chest pain frm 2 hrs n brethless"
    record = clinical_normalizer.normalize("I hav seveer chest pain frm 2 hrs n brethless")
    assert "severe" in record.normalized_text.lower()
    assert "for 2 hours" in record.normalized_text.lower()
    assert record.duration_hours == 2.0

def test_danger_sign_safety_layer_overrides_all():
    # Concurrent chest pain + breathing difficulty is a critical danger sign
    features = {
        "chest_pain": 1,
        "difficulty_breathing": 1,
        "fever": 0,
        "unconsciousness": 0,
        "seizure": 0
    }
    safety_res = evaluate_danger_signs(features)
    assert safety_res.is_emergency is True
    assert "CRITICAL_CARDIO_RESPIRATORY_DISTRESS" in safety_res.reason_codes

    # Ensure triage engine yields EMERGENCY with decision_source="SAFETY_RULE"
    decision = triage_engine.evaluate(features)
    assert decision.triage_level == "EMERGENCY"
    assert decision.decision_source == "SAFETY_RULE"

def test_care_pathway_emergency_gate():
    pathway = determine_care_pathway("EMERGENCY")
    assert pathway.care_pathway == "EMERGENCY_REFERRAL"
    assert pathway.booking_allowed is False

    pathway_routine = determine_care_pathway("LOW_RISK")
    assert pathway_routine.care_pathway == "ROUTINE_CONSULTATION"
    assert pathway_routine.booking_allowed is True

def test_unified_healthcare_analyze_endpoint(client):
    # 1. Critical Emergency Query
    payload = {
        "text": "I hav seveer chest pain frm 2 hrs n brethless",
        "language": "en"
    }
    response = client.post("/api/healthcare/analyze", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["triage"]["level"] == "EMERGENCY"
    assert data["triage"]["decision_source"] == "SAFETY_RULE"
    assert data["care_pathway"] == "EMERGENCY_REFERRAL"
    assert data["appointment"]["status"] == "NOT_APPLICABLE"

    # 2. Routine Mild Query
    routine_payload = {
        "text": "Mild headache since yesterday, no fever, no chest pain",
        "language": "en"
    }
    routine_resp = client.post("/api/healthcare/analyze", json=routine_payload)
    assert routine_resp.status_code == 200
    r_data = routine_resp.json()
    assert r_data["triage"]["level"] in ("LOW_RISK", "HIGH_RISK")
    assert r_data["care_pathway"] in ("ROUTINE_CONSULTATION", "URGENT_CONSULTATION")
    assert r_data["appointment"]["status"] in ("AVAILABLE", "NO_SLOTS")

def test_appointment_emergency_booking_safety_check(client):
    # Attempting to book a routine appointment with EMERGENCY triage must be blocked
    booking_payload = {
        "patient_id": "test_patient_id",
        "hospital_id": "test_hosp_id",
        "doctor_id": "test_doc_id",
        "slot_id": "SLOT_test_20260905_1000",
        "triage_level": "EMERGENCY"
    }
    res = client.post("/api/appointments/book", json=booking_payload)
    assert res.status_code == 200
    assert res.json()["status"] == "BLOCKED_EMERGENCY"
    assert res.json()["care_pathway"] == "EMERGENCY_REFERRAL"

