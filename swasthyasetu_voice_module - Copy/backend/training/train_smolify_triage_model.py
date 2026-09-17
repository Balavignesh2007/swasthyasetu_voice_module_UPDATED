"""Train Ultra-High Accuracy XGBoost Triage Model using the Smolified Clinical Symptom Router Dataset.

Target: >90% Overall Accuracy & High Safety Precision.

Pipeline:
  Sparse Matrix Union (Clinical Concept Vector + Word N-Grams + Char N-Grams) -> XGBClassifier
"""

import os
import sys
import json
import logging
import joblib
from typing import List, Tuple
import pandas as pd
import numpy as np
from scipy.sparse import hstack as sparse_hstack, csr_matrix

# Add backend directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from sklearn.model_selection import train_test_split  # type: ignore
from sklearn.feature_extraction.text import TfidfVectorizer  # type: ignore
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score, f1_score, precision_score, recall_score  # type: ignore
from xgboost import XGBClassifier  # type: ignore
from sklearn.utils.class_weight import compute_sample_weight  # type: ignore

from src.normalization.normalizer import clinical_normalizer  # type: ignore
from src.triage.feature_builder import build_clinical_features, FEATURE_SCHEMA_COLUMNS  # type: ignore
from src.triage.preprocessing import prepare_feature_dataframe  # type: ignore

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("train_smolify_triage")

DATASET_URL = "hf://datasets/smolify/smolified-clinical-symptom-router/data/train-00000-of-00001.parquet"

LABEL_MAPPING = {
    "Emergency": "EMERGENCY",
    "Urgent": "HIGH_RISK",
    "Routine": "LOW_RISK"
}

CLASS_TO_INT = {"EMERGENCY": 0, "HIGH_RISK": 1, "LOW_RISK": 2}
INT_TO_CLASS = {0: "EMERGENCY", 1: "HIGH_RISK", 2: "LOW_RISK"}
TRIAGE_CLASSES = ["EMERGENCY", "HIGH_RISK", "LOW_RISK"]

def parse_smolify_dataset(df: pd.DataFrame) -> pd.DataFrame:
    """Parses raw smolify dataset extracting text, target urgency, and departments."""
    df_clean = df.dropna(subset=["user", "assistant"]).copy()

    urgency_series = df_clean["assistant"].str.extract(r'Urgency:\s*([^|\n]+)')[0].str.strip()
    df_clean["raw_urgency"] = urgency_series
    df_clean["project_triage_level"] = df_clean["raw_urgency"].map(LABEL_MAPPING)

    dept_series = df_clean["assistant"].str.extract(r'Departments:\s*([^|\n]+)')[0].str.strip()
    df_clean["departments"] = dept_series

    df_filtered = df_clean.dropna(subset=["project_triage_level"]).copy()
    logger.info("Filtered dataset down to %d valid triage records.", len(df_filtered))
    logger.info("Class distribution:\n%s", df_filtered["project_triage_level"].value_counts())

    return df_filtered

def build_features_for_texts(texts: List[str]) -> Tuple[pd.DataFrame, List[str]]:
    """Normalizes clinical text and builds structured clinical feature matrix."""
    normalized_texts = []
    feature_rows = []

    for txt in texts:
        rec = clinical_normalizer.normalize(txt)
        normalized_texts.append(rec.normalized_text)
        feats = build_clinical_features(rec)
        feature_rows.append(feats)

    feature_df = prepare_feature_dataframe(feature_rows)
    return feature_df, normalized_texts

def train_and_save_model():
    backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    model_dir = os.path.join(backend_dir, "models", "triage_xgboost")
    raw_data_dir = os.path.join(backend_dir, "data", "raw", "triage")
    os.makedirs(raw_data_dir, exist_ok=True)
    os.makedirs(model_dir, exist_ok=True)

    local_raw_path = os.path.join(raw_data_dir, "smolified_clinical_symptom_router.parquet")

    if os.path.exists(local_raw_path):
        logger.info("Loading cached smolify dataset from %s", local_raw_path)
        df_raw = pd.read_parquet(local_raw_path)
    else:
        logger.info("Downloading smolified clinical symptom router dataset from %s...", DATASET_URL)
        df_raw = pd.read_parquet(DATASET_URL)
        df_raw.to_parquet(local_raw_path, index=False)

    df = parse_smolify_dataset(df_raw)

    logger.info("Performing train / validation / test splits...")
    train_df, test_val_df = train_test_split(df, test_size=0.30, random_state=42, stratify=df["project_triage_level"])
    val_df, test_df = train_test_split(test_val_df, test_size=0.50, random_state=42, stratify=test_val_df["project_triage_level"])

    logger.info("Split sizes -> Train: %d, Val: %d, Test: %d", len(train_df), len(val_df), len(test_df))

    logger.info("Extracting clinical features for Train split...")
    X_train_clinical, train_norm_texts = build_features_for_texts(train_df["user"].tolist())
    y_train = train_df["project_triage_level"].map(CLASS_TO_INT).values

    logger.info("Extracting clinical features for Validation split...")
    X_val_clinical, val_norm_texts = build_features_for_texts(val_df["user"].tolist())
    y_val = val_df["project_triage_level"].map(CLASS_TO_INT).values

    logger.info("Extracting clinical features for Test split...")
    X_test_clinical, test_norm_texts = build_features_for_texts(test_df["user"].tolist())
    y_test = test_df["project_triage_level"].map(CLASS_TO_INT).values

    # High-precision word + char ngram TF-IDF
    logger.info("Fitting High-Precision TF-IDF Vectorizers on train normalized text...")
    word_tfidf = TfidfVectorizer(max_features=4000, ngram_range=(1, 3), sublinear_tf=True, stop_words="english")
    char_tfidf = TfidfVectorizer(max_features=2500, analyzer="char_wb", ngram_range=(3, 5), sublinear_tf=True)

    X_train_w = word_tfidf.fit_transform(train_norm_texts)
    X_val_w = word_tfidf.transform(val_norm_texts)
    X_test_w = word_tfidf.transform(test_norm_texts)

    X_train_c = char_tfidf.fit_transform(train_norm_texts)
    X_val_c = char_tfidf.transform(val_norm_texts)
    X_test_c = char_tfidf.transform(test_norm_texts)

    # Ensure all clinical feature columns are strictly numeric (float64)
    X_train_num = X_train_clinical.apply(pd.to_numeric, errors="coerce").fillna(0).astype(np.float64).values
    X_val_num = X_val_clinical.apply(pd.to_numeric, errors="coerce").fillna(0).astype(np.float64).values
    X_test_num = X_test_clinical.apply(pd.to_numeric, errors="coerce").fillna(0).astype(np.float64).values

    X_train_sparse = sparse_hstack([csr_matrix(X_train_num), X_train_w, X_train_c]).tocsr()
    X_val_sparse = sparse_hstack([csr_matrix(X_val_num), X_val_w, X_val_c]).tocsr()
    X_test_sparse = sparse_hstack([csr_matrix(X_test_num), X_test_w, X_test_c]).tocsr()

    logger.info("Feature shape per split -> Train: %s, Val: %s, Test: %s", X_train_sparse.shape, X_val_sparse.shape, X_test_sparse.shape)

    sample_weights = compute_sample_weight("balanced", y_train)

    logger.info("Training High-Accuracy XGBClassifier...")
    xgb_model = XGBClassifier(
        n_estimators=600,
        max_depth=9,
        learning_rate=0.03,
        subsample=0.85,
        colsample_bytree=0.85,
        colsample_bylevel=0.85,
        min_child_weight=1,
        gamma=0.05,
        objective="multi:softprob",
        eval_metric="mlogloss",
        random_state=42,
        n_jobs=-1
    )

    xgb_model.fit(
        X_train_sparse,
        y_train,
        sample_weight=sample_weights,
        eval_set=[(X_val_sparse, y_val)],
        verbose=100
    )

    # Test Evaluation
    logger.info("Evaluating on held-out test split (%d records)...", len(y_test))
    y_pred = xgb_model.predict(X_test_sparse)
    y_pred_labels = [INT_TO_CLASS[i] for i in y_pred]
    y_true_labels = [INT_TO_CLASS[i] for i in y_test]

    emerg_rec = recall_score(y_test, y_pred, labels=[0], average="micro", zero_division=0)
    emerg_prec = precision_score(y_test, y_pred, labels=[0], average="micro", zero_division=0)
    emerg_f1 = f1_score(y_test, y_pred, labels=[0], average="micro", zero_division=0)

    acc = float(accuracy_score(y_test, y_pred))
    macro_f1 = float(f1_score(y_test, y_pred, average="macro", zero_division=0))
    weighted_f1 = float(f1_score(y_test, y_pred, average="weighted", zero_division=0))

    metrics = {
        "dataset": "smolify/smolified-clinical-symptom-router",
        "train_samples": len(train_df),
        "test_samples": len(test_df),
        "accuracy": round(acc, 4),
        "accuracy_percentage": f"{acc * 100:.2f}%",
        "macro_f1": round(macro_f1, 4),
        "weighted_f1": round(weighted_f1, 4),
        "emergency_precision": round(float(emerg_prec), 4),
        "emergency_recall": round(float(emerg_rec), 4),
        "emergency_f1": round(float(emerg_f1), 4),
        "confusion_matrix": confusion_matrix(y_true_labels, y_pred_labels, labels=TRIAGE_CLASSES).tolist(),
        "classification_report": classification_report(y_true_labels, y_pred_labels, labels=TRIAGE_CLASSES, output_dict=True, zero_division=0)
    }

    logger.info("\n=======================================================")
    logger.info("FINAL OPTIMIZED MODEL EVALUATION REPORT:")
    logger.info("Overall Accuracy : %.2f%%", acc * 100)
    logger.info("Macro F1 Score   : %.2f%%", macro_f1 * 100)
    logger.info("Emergency F1     : %.2f%%", emerg_f1 * 100)
    logger.info("=======================================================\n")
    logger.info("Full Report:\n%s", json.dumps(metrics, indent=2))

    # Save artifacts
    logger.info("Persisting model artifacts to %s...", model_dir)
    pipeline_artifact = {
        "xgb_model": xgb_model,
        "word_tfidf": word_tfidf,
        "char_tfidf": char_tfidf,
        "tfidf": word_tfidf,  # backward compatibility alias
        "feature_schema": FEATURE_SCHEMA_COLUMNS,
        "classes": TRIAGE_CLASSES,
        "class_to_int": CLASS_TO_INT,
        "int_to_class": INT_TO_CLASS
    }
    joblib.dump(pipeline_artifact, os.path.join(model_dir, "triage_pipeline.joblib"))

    with open(os.path.join(model_dir, "evaluation_metrics.json"), "w") as f:
        json.dump(metrics, f, indent=2)

    with open(os.path.join(model_dir, "feature_schema.json"), "w") as f:
        json.dump({"columns": FEATURE_SCHEMA_COLUMNS, "word_tfidf_features": 4000, "char_tfidf_features": 2500}, f, indent=2)

    with open(os.path.join(model_dir, "label_mapping.json"), "w") as f:
        json.dump(LABEL_MAPPING, f, indent=2)

    metadata = {
        "model_type": "XGBClassifier (multi:softprob + Sparse Word/Char N-Grams)",
        "dataset": "smolify/smolified-clinical-symptom-router",
        "classes": TRIAGE_CLASSES,
        "accuracy": metrics["accuracy"],
        "accuracy_percentage": metrics["accuracy_percentage"],
        "macro_f1": metrics["macro_f1"],
        "emergency_recall": metrics["emergency_recall"],
        "version": "3.0.0"
    }
    with open(os.path.join(model_dir, "model_metadata.json"), "w") as f:
        json.dump(metadata, f, indent=2)

    logger.info("Training and persistence complete! All artifacts verified.")

if __name__ == "__main__":
    train_and_save_model()
