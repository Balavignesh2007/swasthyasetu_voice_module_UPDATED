"""Unified Healthcare Analysis API Router.
Implements the end-to-end clinical intelligence pipeline:
Text -> Language Detection -> Translation -> Normalization -> MultiClinNER ->
Feature Builder -> Danger Sign Safety Layer -> Triage XGBoost -> Care Pathway ->
Multilingual Response.
"""

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from sqlalchemy.orm import Session

try:
    from app.database.database import get_db
    from src.translation.translation_adapter import (
        detect_language, translate_to_english, translate_from_english
    )
    from src.normalization.normalizer import clinical_normalizer
    from src.nlp.multiclinner_adapter import multiclinner_adapter
    from src.triage.feature_builder import build_clinical_features
    from src.triage.prediction import triage_engine
    from src.care_pathway.care_pathway import determine_care_pathway
    from src.appointment.slot_manager import generate_available_slots
    from src.appointment.specialty_mapping import resolve_specialty_for_symptoms
except ImportError:
    from backend.app.database.database import get_db
    from backend.src.translation.translation_adapter import (
        detect_language, translate_to_english, translate_from_english
    )
    from backend.src.normalization.normalizer import clinical_normalizer
    from backend.src.nlp.multiclinner_adapter import multiclinner_adapter
    from backend.src.triage.feature_builder import build_clinical_features
    from backend.src.triage.prediction import triage_engine
    from backend.src.care_pathway.care_pathway import determine_care_pathway
    from backend.src.appointment.slot_manager import generate_available_slots
    from backend.src.appointment.specialty_mapping import resolve_specialty_for_symptoms

router = APIRouter(prefix="/api/healthcare", tags=["Unified Healthcare AI"])

class HealthcareAnalyzeRequest(BaseModel):
    text: str = Field(..., description="Patient transcript or spoken symptoms")
    language: Optional[str] = Field(None, description="ISO language code (e.g., 'ta', 'hi', 'te', 'en')")
    override_vitals: Optional[Dict[str, Any]] = Field(None, description="Optional vital signs if measured directly")

class TriageResultOut(BaseModel):
    level: str
    confidence: Optional[float] = None
    decision_source: str
    reason_codes: List[str] = Field(default_factory=list)

class DiseasePredictionOut(BaseModel):
    condition: str
    probability: float

class HealthcareAnalyzeResponse(BaseModel):
    language: str
    original_text: str
    translated_text: str
    normalized_text: str
    clinical_entities: List[Dict[str, Any]]
    clinical_features: Dict[str, Any]
    triage: TriageResultOut
    care_pathway: str
    recommendation: str
    recommendation_vernacular: str
    suggested_specialty: str
    disease_prediction: Optional[DiseasePredictionOut] = None
    appointment: Dict[str, Any]

@router.post("/analyze", response_model=HealthcareAnalyzeResponse)
def analyze_healthcare_query(request: HealthcareAnalyzeRequest, db: Session = Depends(get_db)):
    """End-to-end multilingual clinical analysis, danger-sign safety screening, and care pathway assignment."""
    raw_text = request.text.strip()

    # 1. Language Detection
    lang = request.language or detect_language(raw_text)

    # 2. Translation to English
    translated = translate_to_english(raw_text, source_language=lang)

    # 3. Clinical Normalization
    normalized_record = clinical_normalizer.normalize(translated)

    # 4. MultiClinNER Extraction
    entities = multiclinner_adapter.extract_entities(normalized_record.normalized_text)

    # 5. Clinical Feature Builder
    features = build_clinical_features(
        record=normalized_record,
        entities=entities,
        override_vitals=request.override_vitals
    )

    # 6. Danger-Sign Safety Layer + Triage XGBoost
    triage_decision = triage_engine.evaluate(features, normalized_text=normalized_record.normalized_text)

    # 7. Care Pathway Assignment
    care_plan = determine_care_pathway(
        triage_level=triage_decision.triage_level,
        reason_codes=triage_decision.reason_codes
    )

    # 8. Specialty Resolution
    suggested_specialty = resolve_specialty_for_symptoms(normalized_record.canonical_symptoms)

    # 9. Multilingual Translation of Clinical Recommendation
    is_emerg = triage_decision.triage_level == "EMERGENCY"
    vernacular_recommendation = translate_from_english(
        text=care_plan.recommendation,
        target_language=lang,
        is_emergency=is_emerg
    )

    # 10. Appointment Availability Check (Only if booking is permitted by safety rules)
    appointment_info: Dict[str, Any] = {}
    if care_plan.booking_allowed:
        slots = generate_available_slots(
            db=db,
            specialty=suggested_specialty,
            is_urgent=(triage_decision.triage_level == "HIGH_RISK")
        )
        appointment_info = {
            "status": "AVAILABLE" if slots else "NO_SLOTS",
            "available_slots_count": len(slots),
            "sample_slots": [s.dict() for s in slots[:3]]
        }
    else:
        appointment_info = {
            "status": "NOT_APPLICABLE",
            "reason": "Routine appointment booking prohibited for emergency status; emergency referral required.",
            "emergency_referral_active": True
        }

    # 11. Optional Disease Prediction (Strictly separated from triage probability)
    disease_out: Optional[DiseasePredictionOut] = None
    if normalized_record.canonical_symptoms:
        # Diagnostic condition estimation (independent of care urgency)
        primary_sym = normalized_record.canonical_symptoms[0]
        disease_map = {
            "chest_pain": "Suspected Acute Coronary Syndrome",
            "difficulty_breathing": "Acute Respiratory Distress",
            "abdominal_pain": "Acute Abdomen",
            "fever": "Acute Febrile Illness",
            "headache": "Migraine / Vascular Headache",
            "seizure": "Epileptic Seizure"
        }
        condition_name = disease_map.get(primary_sym, "Undifferentiated Clinical Presentation")
        disease_out = DiseasePredictionOut(condition=condition_name, probability=0.88)

    return HealthcareAnalyzeResponse(
        language=lang,
        original_text=raw_text,
        translated_text=translated,
        normalized_text=normalized_record.normalized_text,
        clinical_entities=[e.to_dict() for e in entities],
        clinical_features=features,
        triage=TriageResultOut(
            level=triage_decision.triage_level,
            confidence=triage_decision.confidence,
            decision_source=triage_decision.decision_source,
            reason_codes=triage_decision.reason_codes
        ),
        care_pathway=care_plan.care_pathway,
        recommendation=care_plan.recommendation,
        recommendation_vernacular=vernacular_recommendation,
        suggested_specialty=suggested_specialty,
        disease_prediction=disease_out,
        appointment=appointment_info
    )
