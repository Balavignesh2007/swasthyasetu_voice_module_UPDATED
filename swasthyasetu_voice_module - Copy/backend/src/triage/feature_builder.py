"""Clinical Feature Builder.
Transforms normalized clinical text and extracted entities into structured feature dictionaries.
Maintains missing values as None without inventing clinical data.
"""

from typing import Dict, Any, List, Optional
try:
    from src.normalization.normalizer import NormalizedClinicalRecord
    from src.normalization.medical_vocabulary import get_all_canonical_concepts
    from src.nlp.multiclinner_adapter import ClinicalEntity
except ImportError:
    from backend.src.normalization.normalizer import NormalizedClinicalRecord
    from backend.src.normalization.medical_vocabulary import get_all_canonical_concepts
    from backend.src.nlp.multiclinner_adapter import ClinicalEntity

ALL_CANONICAL_BINARY_FIELDS = list(dict.fromkeys(get_all_canonical_concepts() + [
    "severe_pain", "altered_mental_status", "symptom_count"
]))

FEATURE_SCHEMA_COLUMNS = ALL_CANONICAL_BINARY_FIELDS + [
    "pain_score",
    "duration_hours",
    "temperature",
    "heart_rate",
    "respiratory_rate",
    "oxygen_saturation",
    "systolic_bp",
    "diastolic_bp"
]

def build_clinical_features(
    record: NormalizedClinicalRecord,
    entities: Optional[List[ClinicalEntity]] = None,
    override_vitals: Optional[Dict[str, Any]] = None
) -> Dict[str, Any]:
    """Constructs structured feature dictionary matching FEATURE_SCHEMA_COLUMNS.
    Missing numeric features remain None.
    """
    features: Dict[str, Any] = {}

    # Initialize all binary symptom flags to 0
    for field in ALL_CANONICAL_BINARY_FIELDS:
        features[field] = 0

    # Populate from present canonical symptoms
    present_canonicals = set(record.canonical_symptoms)
    for sym in present_canonicals:
        if sym in features:
            features[sym] = 1

    # Check for severe pain flag
    is_severe = any(sev in ("severe", "critical") for sev in record.severity_map.values())
    if is_severe or (record.pain_score is not None and record.pain_score >= 7):
        features["severe_pain"] = 1

    # Also augment from NER entities if present
    if entities:
        for ent in entities:
            concept = ent.canonical_concept or ent.text.lower()
            if concept in features:
                # Ensure not negated
                if ent.text.lower() not in [ns.lower() for ns in record.negated_symptoms]:
                    features[concept] = 1

    # Numeric metrics - keep None if missing
    features["pain_score"] = record.pain_score
    features["duration_hours"] = record.duration_hours
    features["symptom_count"] = len(record.canonical_symptoms)

    # Vital signs from parsed text or optional explicit device inputs
    vitals = record.vitals or {}
    if override_vitals:
        vitals.update({k: v for k, v in override_vitals.items() if v is not None})

    features["temperature"] = vitals.get("temperature")
    features["heart_rate"] = vitals.get("heart_rate")
    features["respiratory_rate"] = vitals.get("respiratory_rate")
    features["oxygen_saturation"] = vitals.get("oxygen_saturation")
    features["systolic_bp"] = vitals.get("systolic_bp")
    features["diastolic_bp"] = vitals.get("diastolic_bp")

    return features
