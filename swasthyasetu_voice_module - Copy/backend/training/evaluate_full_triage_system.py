"""Full End-to-End System Evaluation: Safety Screening Layer + Subword ML Model.

Measures combined triage accuracy, macro F1, and emergency precision on held-out test split.
"""

import os
import sys
import json
import logging
import joblib
import pandas as pd
import numpy as np

backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, backend_dir)

from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score, f1_score, precision_score, recall_score
from sklearn.linear_model import LogisticRegression, SGDClassifier
from sklearn.svm import LinearSVC
from sklearn.calibration import CalibratedClassifierCV
from sklearn.ensemble import VotingClassifier
from scipy.sparse import hstack as sparse_hstack, vstack as sparse_vstack, csr_matrix

from src.normalization.normalizer import clinical_normalizer
from src.triage.feature_builder import build_clinical_features, FEATURE_SCHEMA_COLUMNS
from src.triage.preprocessing import prepare_feature_dataframe
from app.services.emergency_service import emergency_safety_service
from training.train_smolify_triage_model import parse_smolify_dataset, CLASS_TO_INT, INT_TO_CLASS, TRIAGE_CLASSES

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("eval_full_system")

local_raw_path = os.path.join(backend_dir, "data", "raw", "triage", "smolified_clinical_symptom_router.parquet")
df_raw = pd.read_parquet(local_raw_path)
df = parse_smolify_dataset(df_raw)

logger.info("Splitting dataset into Train (70%%), Val (15%%), Test (15%%)...")
train_df, test_val_df = train_test_split(df, test_size=0.30, random_state=42, stratify=df["project_triage_level"])
val_df, test_df = train_test_split(test_val_df, test_size=0.50, random_state=42, stratify=test_val_df["project_triage_level"])

def extract_features(data_df):
    texts = data_df["user"].tolist()
    norm_records = []
    feature_rows = []
    for txt in texts:
        rec = clinical_normalizer.normalize(txt)
        norm_records.append(rec)
        feature_rows.append(build_clinical_features(rec))
    f_df = prepare_feature_dataframe(feature_rows)
    f_num = f_df.apply(pd.to_numeric, errors="coerce").fillna(0).astype(np.float64).values
    return f_num, norm_records, texts

logger.info("Extracting clinical records for all splits...")
X_tr_num, train_recs, train_texts = extract_features(train_df)
X_va_num, val_recs, val_texts = extract_features(val_df)
X_te_num, test_recs, test_texts = extract_features(test_df)

y_train = train_df["project_triage_level"].map(CLASS_TO_INT).values
y_val = val_df["project_triage_level"].map(CLASS_TO_INT).values
y_test = test_df["project_triage_level"].map(CLASS_TO_INT).values

logger.info("Building subword TF-IDF features...")
word_vec = TfidfVectorizer(max_features=12000, ngram_range=(1, 4), sublinear_tf=True, stop_words="english")
char_vec = TfidfVectorizer(max_features=18000, analyzer="char_wb", ngram_range=(2, 6), sublinear_tf=True)

train_norm_texts = [r.normalized_text for r in train_recs]
val_norm_texts = [r.normalized_text for r in val_recs]
test_norm_texts = [r.normalized_text for r in test_recs]

X_tr_w = word_vec.fit_transform(train_norm_texts)
X_va_w = word_vec.transform(val_norm_texts)
X_te_w = word_vec.transform(test_norm_texts)

X_tr_c = char_vec.fit_transform(train_norm_texts)
X_va_c = char_vec.transform(val_norm_texts)
X_te_c = char_vec.transform(test_norm_texts)

clin_w = 5.0
X_tr_sparse = sparse_hstack([csr_matrix(X_tr_num * clin_w), X_tr_w, X_tr_c]).tocsr()
X_va_sparse = sparse_hstack([csr_matrix(X_va_num * clin_w), X_va_w, X_va_c]).tocsr()
X_te_sparse = sparse_hstack([csr_matrix(X_te_num * clin_w), X_te_w, X_te_c]).tocsr()

X_tr_va = sparse_vstack([X_tr_sparse, X_va_sparse]).tocsr()
y_tr_va = np.concatenate([y_train, y_val])

logger.info("Training High-Accuracy Calibrated Triage Classifier...")
lr = LogisticRegression(C=3.5, class_weight="balanced", max_iter=1000, random_state=42)
sgd = SGDClassifier(loss="modified_huber", alpha=1e-5, max_iter=1000, class_weight="balanced", random_state=42)
svc = LinearSVC(C=1.0, class_weight="balanced", max_iter=2000, random_state=42)
calibrated_svc = CalibratedClassifierCV(svc, cv=3)

ensemble = VotingClassifier(
    estimators=[("lr", lr), ("sgd", sgd), ("svc", calibrated_svc)],
    voting="soft",
    weights=[2.0, 1.5, 1.0]
)

ensemble.fit(X_tr_va, y_tr_va)

# Evaluate ML Model alone vs Full End-to-End System (Safety Layer + ML)
ml_preds_int = ensemble.predict(X_te_sparse)

full_system_preds_int = []
for idx, rec in enumerate(test_recs):
    # 1. Screen WHO IMAI Danger Signs (Safety Layer)
    screen = emergency_safety_service.screen([s.replace('_', ' ') for s in rec.canonical_symptoms])
    if screen.is_emergency:
        full_system_preds_int.append(0)  # EMERGENCY
    else:
        full_system_preds_int.append(int(ml_preds_int[idx]))

# Calculate Full System Metrics
y_pred_labels = [INT_TO_CLASS[i] for i in full_system_preds_int]
y_true_labels = [INT_TO_CLASS[i] for i in y_test]

acc = float(accuracy_score(y_test, full_system_preds_int))
macro_f1 = float(f1_score(y_test, full_system_preds_int, average="macro", zero_division=0))
weighted_f1 = float(f1_score(y_test, full_system_preds_int, average="weighted", zero_division=0))

emerg_rec = recall_score(y_test, full_system_preds_int, labels=[0], average="micro", zero_division=0)
emerg_prec = precision_score(y_test, full_system_preds_int, labels=[0], average="micro", zero_division=0)
emerg_f1 = f1_score(y_test, full_system_preds_int, labels=[0], average="micro", zero_division=0)

metrics = {
    "dataset": "smolify/smolified-clinical-symptom-router",
    "system_architecture": "WHO IMAI Safety Screening Rules + High-Dimensional Subword ML Classifier",
    "train_samples": len(train_df) + len(val_df),
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
logger.info("FULL END-TO-END SYSTEM EVALUATION REPORT:")
logger.info("Overall System Accuracy : %.2f%%", acc * 100)
logger.info("Macro F1 Score          : %.2f%%", macro_f1 * 100)
logger.info("Emergency F1 Score      : %.2f%%", emerg_f1 * 100)
logger.info("Emergency Precision     : %.2f%%", emerg_prec * 100)
logger.info("Emergency Recall        : %.2f%%", emerg_rec * 100)
logger.info("=======================================================\n")

# Persist Model Artifacts
model_dir = os.path.join(backend_dir, "models", "triage_xgboost")
os.makedirs(model_dir, exist_ok=True)

pipeline_artifact = {
    "xgb_model": ensemble,
    "word_tfidf": word_vec,
    "char_tfidf": char_vec,
    "tfidf": word_vec,
    "feature_schema": FEATURE_SCHEMA_COLUMNS,
    "classes": TRIAGE_CLASSES,
    "class_to_int": CLASS_TO_INT,
    "int_to_class": INT_TO_CLASS
}
joblib.dump(pipeline_artifact, os.path.join(model_dir, "triage_pipeline.joblib"))

with open(os.path.join(model_dir, "evaluation_metrics.json"), "w") as f:
    json.dump(metrics, f, indent=2)

with open(os.path.join(model_dir, "feature_schema.json"), "w") as f:
    json.dump({"columns": FEATURE_SCHEMA_COLUMNS, "word_tfidf": 12000, "char_tfidf": 18000}, f, indent=2)

metadata = {
    "model_type": "WHO IMAI Safety Screening Rules + High-Dimensional Subword ML Classifier",
    "dataset": "smolify/smolified-clinical-symptom-router",
    "classes": TRIAGE_CLASSES,
    "accuracy": metrics["accuracy"],
    "accuracy_percentage": metrics["accuracy_percentage"],
    "macro_f1": metrics["macro_f1"],
    "emergency_recall": metrics["emergency_recall"],
    "version": "4.0.0"
}
with open(os.path.join(model_dir, "model_metadata.json"), "w") as f:
    json.dump(metadata, f, indent=2)

logger.info("Model persistence complete! Artifacts updated successfully.")

if __name__ == "__main__":
    pass
