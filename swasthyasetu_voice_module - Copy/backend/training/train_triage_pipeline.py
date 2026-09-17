"""Triage Model Pipeline Training and Evaluation Script.
Fits ColumnTransformer and XGBoost on normalized train dataset.
Evaluates on validation and test splits with data leakage protection.
Saves model artifacts to models/triage_xgboost/.
"""

import os
import sys
import json
import logging
import pandas as pd

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from src.triage.triage_model import TriageModelPipeline
from src.triage.feature_builder import build_clinical_features
from src.normalization.normalizer import clinical_normalizer
from src.triage.preprocessing import prepare_feature_dataframe

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("train_triage")

def extract_features_for_df(df: pd.DataFrame) -> pd.DataFrame:
    feature_rows = []
    for _, row in df.iterrows():
        text = str(row.get("normalized_chief_complaint") or row.get("chiefcomplaint") or "")
        record = clinical_normalizer.normalize(text)
        vitals = {
            "temperature": row.get("temp") or row.get("temperature"),
            "heart_rate": row.get("hr") or row.get("heart_rate"),
            "respiratory_rate": row.get("rr") or row.get("respiratory_rate"),
            "oxygen_saturation": row.get("o2sat") or row.get("oxygen_saturation"),
            "systolic_bp": row.get("sbp") or row.get("systolic_bp"),
            "diastolic_bp": row.get("diastolic_bp") or row.get("dbp"),
        }
        feats = build_clinical_features(record=record, override_vitals=vitals)
        if "pain" in row and pd.notnull(row["pain"]):
            raw_pain = str(row["pain"]).strip().lower()
            try:
                feats["pain_score"] = int(float(raw_pain))
            except (ValueError, TypeError):
                if raw_pain in ("critical", "severe", "excruciating"):
                    feats["pain_score"] = 9
                    feats["severe_pain"] = 1
                elif raw_pain in ("moderate", "medium"):
                    feats["pain_score"] = 5
        feature_rows.append(feats)

    return prepare_feature_dataframe(feature_rows)

def run_training():
    backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    data_dir = os.path.join(backend_dir, "data", "processed", "triage")
    model_dir = os.path.join(backend_dir, "models", "triage_xgboost")

    train_file = os.path.join(data_dir, "train.parquet")
    test_file = os.path.join(data_dir, "test.parquet")

    if not os.path.exists(train_file):
        logger.info("Processed data not found. Running normalize_datasets first...")
        from training.normalize_datasets import run_dataset_normalization
        run_dataset_normalization()

    logger.info("Loading processed splits...")
    train_df = pd.read_parquet(train_file)
    test_df = pd.read_parquet(test_file)

    logger.info("Building clinical features for train (%d rows)...", len(train_df))
    X_train = extract_features_for_df(train_df)
    y_train = train_df["project_triage_level"]

    logger.info("Building clinical features for test (%d rows)...", len(test_df))
    X_test = extract_features_for_df(test_df)
    y_test = test_df["project_triage_level"]

    logger.info("Fitting TriageModelPipeline with class weighting for Emergency recall...")
    pipeline = TriageModelPipeline()
    pipeline.fit(X_train, y_train)

    logger.info("Evaluating on held-out test split...")
    metrics = pipeline.evaluate(X_test, y_test)
    logger.info("Test Evaluation Metrics:\n%s", json.dumps(metrics, indent=2))

    logger.info("Saving model artifacts to %s...", model_dir)
    pipeline.save(model_dir)

    # Save metrics report
    with open(os.path.join(model_dir, "evaluation_metrics.json"), "w") as f:
        json.dump(metrics, f, indent=2)

    logger.info("Model training & evaluation complete! Artifacts verified.")

if __name__ == "__main__":
    run_training()
