"""
Shared feature schema used by both training (train_triage_model.py) and
inference (app/services/xgboost_service.py). Keeping this in one place
prevents feature-order drift between training and serving.
"""

SYMPTOM_FEATURES = [
    "Fever",
    "Cough",
    "Difficulty Breathing",
    "Chest Pain",
    "Headache",
    "Abdominal Pain",
    "Vomiting",
    "Diarrhea",
    "Age_Over_60",
    "Age_Under_5",
]


def symptoms_to_feature_vector(standardized_symptoms: list[str], age: int | None = None) -> list[int]:
    """Convert a list of standardized symptom strings + age into the model's
    fixed-order binary/derived feature vector."""
    vector = []
    symptom_set = {s.strip() for s in standardized_symptoms if s}
    lower_symptom_set = {s.lower().strip() for s in standardized_symptoms if s}
    for feature in SYMPTOM_FEATURES:
        if feature == "Age_Over_60":
            vector.append(1 if age is not None and age > 60 else 0)
        elif feature == "Age_Under_5":
            vector.append(1 if age is not None and age < 5 else 0)
        else:
            is_present = (feature in symptom_set) or (feature.lower() in lower_symptom_set)
            vector.append(1 if is_present else 0)
    return vector
