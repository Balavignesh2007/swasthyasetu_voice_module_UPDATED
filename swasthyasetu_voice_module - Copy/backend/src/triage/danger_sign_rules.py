"""Danger-Sign Safety Layer.
Executes rule-based clinical safety checks that strictly OVERRIDE machine learning predictions.
Based on WHO Integrated Management of Adolescent and Adult Illness (IMAI)
and Emergency Triage Assessment and Treatment (ETAT) guidelines.

If a critical danger sign is triggered, triage level is guaranteed to be EMERGENCY,
bypassing and overriding any lower ML triage predictions.
"""

from typing import Dict, Any, List, Optional
from dataclasses import dataclass, field

DANGER_SIGN_RULESET_VERSION = "1.0.0"

@dataclass
class SafetyEvaluationResult:
    is_emergency: bool
    triage_level: Optional[str] = None
    reason_codes: List[str] = field(default_factory=list)
    clinical_explanations: List[str] = field(default_factory=list)
    guideline_reference: str = "WHO IMAI / ETAT Emergency Danger Sign Protocol"

def evaluate_danger_signs(features: Dict[str, Any]) -> SafetyEvaluationResult:
    """Evaluates structured clinical features against hard critical danger rules."""
    reasons: List[str] = []
    explanations: List[str] = []

    # 1. Unconsciousness / Coma / Acute altered mental state
    if features.get("unconsciousness", 0) == 1:
        reasons.append("CRITICAL_UNCONSCIOUSNESS")
        explanations.append("Patient reported loss of consciousness or unresponsiveness.")

    if features.get("altered_mental_status", 0) == 1:
        reasons.append("CRITICAL_ALTERED_MENTAL_STATUS")
        explanations.append("Acute disorientation or altered level of consciousness.")

    # 2. Active Seizure / Status Epilepticus
    if features.get("seizure", 0) == 1:
        reasons.append("CRITICAL_SEIZURE_ACTIVITY")
        explanations.append("Active or repeated convulsions/seizures.")

    # 3. Acute Chest Pain + Breathing Difficulty (Potential Myocardial Infarction / PE)
    if features.get("chest_pain", 0) == 1 and features.get("difficulty_breathing", 0) == 1:
        reasons.append("CRITICAL_CARDIO_RESPIRATORY_DISTRESS")
        explanations.append("Concurrent acute chest pain and difficulty breathing indicating possible acute coronary syndrome or pulmonary embolism.")

    # 4. Severe Hemorrhage / Massive Bleeding
    if features.get("severe_bleeding", 0) == 1 or features.get("hemoptysis", 0) == 1 or features.get("hematemesis", 0) == 1:
        reasons.append("CRITICAL_SEVERE_HEMORRHAGE")
        explanations.append("Severe active bleeding, coughing up blood, or vomiting blood.")

    # 5. Acute Respiratory Failure / Severe Hypoxemia (SpO2 < 90%)
    spo2 = features.get("oxygen_saturation")
    if spo2 is not None and spo2 < 90:
        reasons.append("CRITICAL_HYPOXEMIA")
        explanations.append(f"Severely depressed oxygen saturation ({spo2}% < 90%).")

    # 6. Extreme Hemodynamic Instability / Shock (SBP < 90 mmHg or HR > 140 bpm)
    sbp = features.get("systolic_bp")
    if sbp is not None and sbp < 90 and sbp > 30:
        reasons.append("CRITICAL_HYPOTENSION_SHOCK")
        explanations.append(f"Systolic blood pressure profoundly low ({sbp} mmHg < 90 mmHg).")

    hr = features.get("heart_rate")
    if hr is not None and hr > 140:
        reasons.append("CRITICAL_TACHYCARDIA")
        explanations.append(f"Severe tachycardia ({hr} bpm > 140 bpm).")

    # 7. Respiratory Arrest / Severe Tachypnea (RR > 35 or RR < 8)
    rr = features.get("respiratory_rate")
    if rr is not None and (rr > 35 or rr < 8):
        reasons.append("CRITICAL_RESPIRATORY_RATE_FAILURE")
        explanations.append(f"Extreme respiratory rate ({rr} breaths/min).")

    # 8. Unbearable / Excruciating Pain (Pain score >= 9/10) with acute onset
    pain = features.get("pain_score")
    if pain is not None and pain >= 9:
        if features.get("chest_pain", 0) == 1 or features.get("abdominal_pain", 0) == 1:
            reasons.append("CRITICAL_EXCRUCIATING_PAIN")
            explanations.append(f"Excruciating pain score ({pain}/10) in vital organ region.")

    if len(reasons) > 0:
        return SafetyEvaluationResult(
            is_emergency=True,
            triage_level="EMERGENCY",
            reason_codes=reasons,
            clinical_explanations=explanations
        )

    return SafetyEvaluationResult(
        is_emergency=False,
        triage_level=None,
        reason_codes=[],
        clinical_explanations=[]
    )
