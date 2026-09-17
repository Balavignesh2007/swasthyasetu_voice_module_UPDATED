"""
Trains the LOW/HIGH triage XGBoost model.

This script ships with a synthetic training set so the pipeline is runnable
end-to-end out of the box. REPLACE `generate_synthetic_dataset()` with a loader
for your real, clinically-labeled triage dataset before production use —
the feature schema (see features.py) must stay in sync with xgboost_service.py.

Usage:
    cd backend
    python ml/xgboost/train_triage_model.py
"""
import json
import random
from pathlib import Path

import numpy as np
import pandas as pd
import xgboost as xgb
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report

from features import SYMPTOM_FEATURES, symptoms_to_feature_vector  # noqa: E402

random.seed(42)
np.random.seed(42)

HIGH_RISK_WEIGHTS = {
    "Fever": 0.15,
    "Cough": 0.05,
    "Difficulty Breathing": 0.55,
    "Chest Pain": 0.5,
    "Headache": 0.1,
    "Abdominal Pain": 0.2,
    "Vomiting": 0.15,
    "Diarrhea": 0.15,
    "Age_Over_60": 0.25,
    "Age_Under_5": 0.2,
}


def generate_synthetic_dataset(n_samples: int = 4000) -> pd.DataFrame:
    rows = []
    symptom_names = [s for s in SYMPTOM_FEATURES if not s.startswith("Age_")]

    for _ in range(n_samples):
        active_symptoms = [s for s in symptom_names if random.random() < 0.25]
        age = random.randint(1, 90)
        features = symptoms_to_feature_vector(active_symptoms, age=age)

        risk_score = sum(HIGH_RISK_WEIGHTS.get(s, 0.05) for s in active_symptoms)
        if age > 60:
            risk_score += HIGH_RISK_WEIGHTS["Age_Over_60"]
        if age < 5:
            risk_score += HIGH_RISK_WEIGHTS["Age_Under_5"]
        risk_score += np.random.normal(0, 0.08)  # label noise

        label = 1 if risk_score > 0.45 else 0  # 1 = HIGH, 0 = LOW
        row = dict(zip(SYMPTOM_FEATURES, features))
        row["label"] = label
        rows.append(row)

    return pd.DataFrame(rows)


def main():
    df = generate_synthetic_dataset()
    X = df[SYMPTOM_FEATURES]
    y = df["label"]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    model = xgb.XGBClassifier(
        n_estimators=200,
        max_depth=4,
        learning_rate=0.1,
        eval_metric="logloss",
        random_state=42,
    )
    model.fit(X_train, y_train)

    preds = model.predict(X_test)
    report = classification_report(y_test, preds, target_names=["LOW", "HIGH"])
    print(report)

    output_path = Path(__file__).parent / "triage_model.json"
    model.save_model(str(output_path))
    print(f"Saved model to {output_path}")

    metadata_path = Path(__file__).parent / "feature_schema.json"
    with open(metadata_path, "w") as f:
        json.dump({"features": SYMPTOM_FEATURES}, f, indent=2)
    print(f"Saved feature schema to {metadata_path}")


if __name__ == "__main__":
    main()
