"""Clinical Preprocessing Pipeline with strict leakage prevention.
Fits imputation and scalers strictly on TRAIN splits.
Transforms validation and test splits using the pre-fitted pipeline.
"""

import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

try:
    from src.triage.feature_builder import FEATURE_SCHEMA_COLUMNS
except ImportError:
    from backend.src.triage.feature_builder import FEATURE_SCHEMA_COLUMNS

BINARY_FEATURES = [
    "chest_pain", "difficulty_breathing", "fever", "abdominal_pain",
    "severe_pain", "unconsciousness", "seizure", "severe_bleeding",
    "hemoptysis", "hematemesis", "altered_mental_status", "headache",
    "vomiting", "diarrhea", "cough", "dizziness"
]

NUMERIC_FEATURES = [
    "pain_score", "duration_hours", "temperature",
    "heart_rate", "respiratory_rate", "oxygen_saturation",
    "systolic_bp", "diastolic_bp"
]

def build_clinical_preprocessor() -> ColumnTransformer:
    """Builds an unfitted ColumnTransformer pipeline for clinical features."""
    # Binary features: fill missing with 0 (absence)
    binary_pipeline = Pipeline([
        ("imputer", SimpleImputer(strategy="constant", fill_value=0))
    ])

    # Numeric features: median imputation + standard scaling
    # Strictly fitted only on TRAIN split
    numeric_pipeline = Pipeline([
        ("imputer", SimpleImputer(strategy="median")),
        ("scaler", StandardScaler())
    ])

    preprocessor = ColumnTransformer(
        transformers=[
            ("bin", binary_pipeline, BINARY_FEATURES),
            ("num", numeric_pipeline, NUMERIC_FEATURES)
        ],
        remainder="drop"
    )

    return preprocessor

def prepare_feature_dataframe(features_dict_or_list) -> pd.DataFrame:
    """Converts a feature dict, Series, DataFrame, or list of dicts into a validated DataFrame aligned with schema."""
    if isinstance(features_dict_or_list, dict):
        df = pd.DataFrame([features_dict_or_list])
    elif isinstance(features_dict_or_list, pd.Series):
        df = pd.DataFrame([features_dict_or_list.to_dict()])
    elif isinstance(features_dict_or_list, pd.DataFrame):
        df = features_dict_or_list.copy()
    elif isinstance(features_dict_or_list, (list, tuple)):
        if len(features_dict_or_list) > 0 and isinstance(features_dict_or_list[0], dict):
            df = pd.DataFrame(features_dict_or_list)
        elif len(features_dict_or_list) == 0:
            df = pd.DataFrame(columns=FEATURE_SCHEMA_COLUMNS)
        else:
            df = pd.DataFrame(features_dict_or_list)
    else:
        df = pd.DataFrame(features_dict_or_list)

    # Ensure all expected columns exist with appropriate defaults
    for col in FEATURE_SCHEMA_COLUMNS:
        if col not in df.columns:
            df[col] = np.nan if col in NUMERIC_FEATURES else 0

    return df[FEATURE_SCHEMA_COLUMNS]

