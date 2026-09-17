"""Triage XGBoost Model Pipeline.
Trains, evaluates, and persists clinical triage model (EMERGENCY / HIGH_RISK / LOW_RISK).
Supports both structured clinical features and TF-IDF clinical vocabulary features.
"""

import os
import joblib  # type: ignore
import numpy as np  # type: ignore
import pandas as pd  # type: ignore
from typing import Dict, Any, Optional, List, Union
from xgboost import XGBClassifier  # type: ignore
from sklearn.pipeline import Pipeline  # type: ignore
from sklearn.metrics import classification_report, confusion_matrix, f1_score, precision_score, recall_score, accuracy_score  # type: ignore
from sklearn.utils.class_weight import compute_sample_weight  # type: ignore

try:
    from src.triage.preprocessing import build_clinical_preprocessor, prepare_feature_dataframe  # type: ignore
    from src.triage.feature_builder import FEATURE_SCHEMA_COLUMNS  # type: ignore
except ImportError:
    from backend.src.triage.preprocessing import build_clinical_preprocessor, prepare_feature_dataframe  # type: ignore
    from backend.src.triage.feature_builder import FEATURE_SCHEMA_COLUMNS  # type: ignore

TRIAGE_CLASSES = ["EMERGENCY", "HIGH_RISK", "LOW_RISK"]
CLASS_TO_INT = {"EMERGENCY": 0, "HIGH_RISK": 1, "LOW_RISK": 2}
INT_TO_CLASS = {0: "EMERGENCY", 1: "HIGH_RISK", 2: "LOW_RISK"}

class TriageModelPipeline:
    """End-to-end clinical triage pipeline supporting structured features + TF-IDF."""

    def __init__(self, pipeline: Optional[Union[Pipeline, Dict[str, Any]]] = None):
        self.xgb_model = None
        self.ensemble_model = None
        self.tfidf = None
        self.word_tfidf = None
        self.char_tfidf = None
        self.clin_weight = 5.0
        self.pipeline = None

        if isinstance(pipeline, dict):
            self.ensemble_model = pipeline.get("ensemble_model") or pipeline.get("xgb_model")
            self.xgb_model = pipeline.get("xgb_model") or self.ensemble_model
            self.tfidf = pipeline.get("tfidf")
            self.word_tfidf = pipeline.get("word_tfidf")
            self.char_tfidf = pipeline.get("char_tfidf")
            self.clin_weight = pipeline.get("clin_weight", 5.0)
        elif isinstance(pipeline, Pipeline):
            self.pipeline = pipeline
        else:
            preprocessor = build_clinical_preprocessor()
            xgb = XGBClassifier(
                n_estimators=300,
                max_depth=6,
                learning_rate=0.05,
                subsample=0.8,
                colsample_bytree=0.8,
                objective="multi:softprob",
                eval_metric="mlogloss",
                random_state=42
            )
            self.pipeline = Pipeline([
                ("preprocessor", preprocessor),
                ("classifier", xgb)
            ])

    def fit(self, X_train: pd.DataFrame, y_train: pd.Series, sample_weight: Optional[np.ndarray] = None):
        """Fits preprocessing and XGBoost strictly on training data."""
        y_int = y_train.map(CLASS_TO_INT).values
        if sample_weight is None:
            sample_weight = compute_sample_weight("balanced", y_int)

        if self.pipeline is not None:
            self.pipeline.fit(X_train, y_int, classifier__sample_weight=sample_weight)
        return self

    def predict_proba(self, X: pd.DataFrame, normalized_text: Optional[Union[str, List[str], pd.Series]] = None) -> np.ndarray:
        """Returns predicted probability distribution over [EMERGENCY, HIGH_RISK, LOW_RISK]."""
        X_df = prepare_feature_dataframe(X)
        if self.ensemble_model is not None or self.xgb_model is not None:
            model = self.ensemble_model if self.ensemble_model is not None else self.xgb_model
            if isinstance(normalized_text, (list, pd.Series, np.ndarray)):
                txts = [str(t or "") for t in normalized_text]
            elif isinstance(normalized_text, str):
                txts = [normalized_text] * len(X_df)
            else:
                txts = [""] * len(X_df)

            if self.word_tfidf is not None and self.char_tfidf is not None:
                from scipy.sparse import hstack as sparse_hstack, csr_matrix
                w_feat = self.word_tfidf.transform(txts)
                c_feat = self.char_tfidf.transform(txts)
                clin_w = getattr(self, "clin_weight", 5.0)
                f_num = X_df.apply(pd.to_numeric, errors="coerce").fillna(0).astype(np.float64).values
                combined = sparse_hstack([csr_matrix(f_num * clin_w), w_feat, c_feat]).tocsr()
            elif self.tfidf is not None:
                tfidf_feat = self.tfidf.transform(txts).toarray()
                f_num = X_df.apply(pd.to_numeric, errors="coerce").fillna(0).astype(np.float64).values
                combined = np.hstack([f_num, tfidf_feat])
            else:
                f_num = X_df.apply(pd.to_numeric, errors="coerce").fillna(0).astype(np.float64).values
                combined = f_num
            return model.predict_proba(combined)

        if self.pipeline is not None:
            return self.pipeline.predict_proba(X_df)

        raise RuntimeError("No fitted model pipeline available.")

    def predict(self, X: pd.DataFrame, normalized_text: Optional[Union[str, List[str], pd.Series]] = None) -> List[str]:
        """Predicts triage class names."""
        probs = self.predict_proba(X, normalized_text)
        pred_ints = np.argmax(probs, axis=1)
        return [INT_TO_CLASS[i] for i in pred_ints]

    def evaluate(self, X_test: pd.DataFrame, y_test: pd.Series, normalized_texts: Optional[List[str]] = None) -> Dict[str, Any]:
        """Generates comprehensive test evaluation metrics."""
        y_true_int = y_test.map(CLASS_TO_INT).values
        if self.pipeline is not None:
            X_df = prepare_feature_dataframe(X_test)
            y_pred_int = self.pipeline.predict(X_df)
        else:
            probs = self.predict_proba(X_test, normalized_text=normalized_texts)
            y_pred_int = np.argmax(probs, axis=1)

        y_pred_labels = [INT_TO_CLASS[i] for i in y_pred_int]
        y_true_labels = [INT_TO_CLASS[i] for i in y_true_int]

        emerg_prec = precision_score(y_true_int, y_pred_int, labels=[0], average="micro", zero_division=0)
        emerg_rec = recall_score(y_true_int, y_pred_int, labels=[0], average="micro", zero_division=0)
        emerg_f1 = f1_score(y_true_int, y_pred_int, labels=[0], average="micro", zero_division=0)

        metrics = {
            "accuracy": round(float(accuracy_score(y_true_int, y_pred_int)), 4),
            "macro_f1": round(float(f1_score(y_true_int, y_pred_int, average="macro", zero_division=0)), 4),
            "weighted_f1": round(float(f1_score(y_true_int, y_pred_int, average="weighted", zero_division=0)), 4),
            "emergency_precision": round(float(emerg_prec), 4),
            "emergency_recall": round(float(emerg_rec), 4),
            "emergency_f1": round(float(emerg_f1), 4),
            "confusion_matrix": confusion_matrix(y_true_labels, y_pred_labels, labels=TRIAGE_CLASSES).tolist(),
            "classification_report": classification_report(y_true_labels, y_pred_labels, labels=TRIAGE_CLASSES, output_dict=True, zero_division=0)
        }
        return metrics

    def save(self, model_dir: str):
        """Persists model pipeline to disk."""
        os.makedirs(model_dir, exist_ok=True)
        pipeline_path = os.path.join(model_dir, "triage_pipeline.joblib")
        if self.pipeline is not None:
            joblib.dump(self.pipeline, pipeline_path)
        elif self.xgb_model is not None:
            artifact = {
                "xgb_model": self.xgb_model,
                "tfidf": self.tfidf,
                "feature_schema": FEATURE_SCHEMA_COLUMNS,
                "classes": TRIAGE_CLASSES,
                "class_to_int": CLASS_TO_INT,
                "int_to_class": INT_TO_CLASS
            }
            joblib.dump(artifact, pipeline_path)

    @classmethod
    def load(cls, model_dir: str) -> "TriageModelPipeline":
        """Loads fitted pipeline from disk."""
        pipeline_path = os.path.join(model_dir, "triage_pipeline.joblib")
        if not os.path.exists(pipeline_path):
            raise FileNotFoundError(f"Model artifact not found at {pipeline_path}")
        loaded = joblib.load(pipeline_path)
        return cls(pipeline=loaded)

