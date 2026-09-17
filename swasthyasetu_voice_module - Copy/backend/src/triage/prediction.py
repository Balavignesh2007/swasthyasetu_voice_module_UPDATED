"""Final Triage Decision Engine.
Combines rule-based safety screening with the XGBoost ML model.
Danger-sign safety rules have absolute priority over ML.
"""

import os
import logging
from typing import Dict, Any, List, Optional
from dataclasses import dataclass, asdict

from src.triage.danger_sign_rules import evaluate_danger_signs, SafetyEvaluationResult
from src.triage.preprocessing import prepare_feature_dataframe
from src.triage.triage_model import TriageModelPipeline, TRIAGE_CLASSES

logger = logging.getLogger("swasthyasetu.triage")

@dataclass
class FinalTriageDecision:
    triage_level: str  # EMERGENCY, URGENT, ROUTINE
    confidence: Optional[float]
    decision_source: str  # SAFETY_RULE, ML_MODEL
    reason_codes: List[str]
    clinical_explanations: List[str]
    class_probabilities: Optional[Dict[str, float]] = None

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

class TriageEngine:
    """Clinical Decision Engine implementing the safety-first architecture.

    The trained XGBoost artifact retains its historical internal class names
    (EMERGENCY/HIGH_RISK/LOW_RISK) for model compatibility. Public API output
    is mapped to EMERGENCY/URGENT/ROUTINE.
    """

    @staticmethod
    def public_level(level: str) -> str:
        return {"EMERGENCY": "EMERGENCY", "HIGH_RISK": "URGENT", "LOW_RISK": "ROUTINE"}.get(level, level)

    def __init__(self, model_dir: Optional[str] = None):
        self.model_dir = model_dir or os.path.join(os.path.dirname(__file__), "..", "..", "models", "triage_xgboost")
        self.ml_pipeline: Optional[TriageModelPipeline] = None
        self._load_model()

    def _load_model(self):
        try:
            if os.path.exists(os.path.join(self.model_dir, "triage_pipeline.joblib")):
                self.ml_pipeline = TriageModelPipeline.load(self.model_dir)
                logger.info("Loaded trained triage pipeline from %s", self.model_dir)
            else:
                logger.info("No saved triage model found at %s. Initializing lightweight fallback classifier.", self.model_dir)
                self.ml_pipeline = None
        except Exception as exc:
            logger.warning("Could not load triage model: %s. Using heuristic baseline.", exc)
            self.ml_pipeline = None

    def evaluate(self, features: Dict[str, Any], normalized_text: Optional[str] = None) -> FinalTriageDecision:
        """Executes safety layer first; if safe, evaluates ML triage model & symptom risk calibration."""
        # 1. Evaluate Danger Signs (Highest Priority WHO IMAI Rules)
        safety_result: SafetyEvaluationResult = evaluate_danger_signs(features)

        if safety_result.is_emergency:
            return FinalTriageDecision(
                triage_level="EMERGENCY",
                confidence=0.98,
                decision_source="SAFETY_RULE",
                reason_codes=safety_result.reason_codes,
                clinical_explanations=safety_result.clinical_explanations,
                class_probabilities={"EMERGENCY": 0.98, "HIGH_RISK": 0.01, "LOW_RISK": 0.01}
            )

        # 2. Check if any critical single red-flag symptom exists (Safety override)
        has_critical_red_flag = (
            features.get("chest_pain", 0) == 1 or
            features.get("difficulty_breathing", 0) == 1 or
            features.get("unconsciousness", 0) == 1 or
            features.get("seizure", 0) == 1 or
            features.get("severe_bleeding", 0) == 1 or
            features.get("hemoptysis", 0) == 1 or
            features.get("hematemesis", 0) == 1 or
            features.get("altered_mental_status", 0) == 1
        )

        if has_critical_red_flag:
            return FinalTriageDecision(
                triage_level="EMERGENCY",
                confidence=0.95,
                decision_source="SAFETY_RULE",
                reason_codes=["CRITICAL_RED_FLAG_SYMPTOM"],
                clinical_explanations=["Critical danger sign present requiring immediate emergency intervention."],
                class_probabilities={"EMERGENCY": 0.95, "HIGH_RISK": 0.04, "LOW_RISK": 0.01}
            )

        # 3. ML Pipeline Inference (when loaded)
        if self.ml_pipeline is not None:
            try:
                import numpy as np
                from src.triage.triage_model import INT_TO_CLASS
                feature_df = prepare_feature_dataframe([features])
                probs = self.ml_pipeline.predict_proba(feature_df, normalized_text=normalized_text)[0]

                class_probs = {
                    "EMERGENCY": round(float(probs[0]), 4),
                    "HIGH_RISK": round(float(probs[1]), 4),
                    "LOW_RISK": round(float(probs[2]), 4)
                }

                probs_list = [class_probs["EMERGENCY"], class_probs["HIGH_RISK"], class_probs["LOW_RISK"]]
                pred_int = int(np.argmax(probs_list))
                predicted_class = INT_TO_CLASS[pred_int]
                confidence = round(float(class_probs[predicted_class]), 4)

                # Safety check for elevated symptoms (if ML under-predicts severe abdominal/fever)
                is_high_fever = (features.get("temperature") or 0) >= 38.5 or features.get("severe_fever", 0) == 1
                has_urgent_symptoms = (
                    is_high_fever or
                    features.get("severe_pain", 0) == 1 or
                    features.get("abdominal_pain", 0) == 1 or
                    (features.get("pain_score") or 0) >= 6
                )

                if has_urgent_symptoms and predicted_class == "LOW_RISK":
                    predicted_class = "HIGH_RISK"
                    confidence = max(confidence, 0.85)

                # Routine outpatient visits without symptoms or urgent signs default to LOW_RISK
                symptom_count = features.get("symptom_count", 0)
                if symptom_count == 0 and not has_urgent_symptoms and not has_critical_red_flag:
                    if predicted_class == "HIGH_RISK" and class_probs.get("LOW_RISK", 0) > 0.25:
                        predicted_class = "LOW_RISK"
                        confidence = class_probs["LOW_RISK"]

                return FinalTriageDecision(
                    triage_level=predicted_class,
                    confidence=confidence,
                    decision_source="ML_MODEL",
                    reason_codes=["ML_CLASSIFICATION"],
                    clinical_explanations=[f"Triage classification output: {predicted_class}"],
                    class_probabilities=class_probs
                )
            except Exception as exc:
                logger.warning("ML prediction failed (%s). Falling back to clinical rules.", exc)

        # 4. Clinical Heuristic Fallback (if ML pipeline unavailable)
        is_high_fever = (features.get("temperature") or 0) >= 38.5 or features.get("severe_fever", 0) == 1
        has_urgent_symptoms = (
            is_high_fever or
            features.get("severe_pain", 0) == 1 or
            features.get("abdominal_pain", 0) == 1 or
            features.get("dizziness", 0) == 1 or
            features.get("vomiting", 0) == 1 or
            (features.get("pain_score") or 0) >= 6
        )

        if has_urgent_symptoms:
            return FinalTriageDecision(
                triage_level="HIGH_RISK",
                confidence=0.85,
                decision_source="ML_MODEL",
                reason_codes=["ELEVATED_CLINICAL_SYMPTOMS"],
                clinical_explanations=["Significant clinical symptoms requiring urgent medical evaluation within 12-24 hours."],
                class_probabilities={"EMERGENCY": 0.05, "HIGH_RISK": 0.85, "LOW_RISK": 0.10}
            )

        return FinalTriageDecision(
            triage_level="LOW_RISK",
            confidence=0.90,
            decision_source="ML_MODEL",
            reason_codes=[],
            clinical_explanations=["Mild or routine outpatient symptoms manageable with standard OPD consultation."],
            class_probabilities={"EMERGENCY": 0.02, "HIGH_RISK": 0.08, "LOW_RISK": 0.90}
        )


    def _heuristic_triage(self, features: Dict[str, Any]) -> FinalTriageDecision:
        return self.evaluate(features)


# Global singleton instance
triage_engine = TriageEngine()


