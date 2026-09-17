from typing import Dict, List, Any
import pandas as pd

COLUMN_ALIASES: Dict[str, List[str]] = {
    "chief_complaint": [
        "chiefcomplaint",
        "chief_complaint",
        "complaint",
        "cc",
        "presenting_complaint",
        "clinical_text"
    ],
    "temperature": [
        "temperature",
        "temp"
    ],
    "heart_rate": [
        "heartrate",
        "heart_rate",
        "hr",
        "pulse"
    ],
    "respiratory_rate": [
        "resprate",
        "respiratory_rate",
        "rr"
    ],
    "oxygen_saturation": [
        "o2sat",
        "oxygen_saturation",
        "spo2",
        "o2_sat"
    ],
    "systolic_bp": [
        "sbp",
        "systolic_bp",
        "systolic"
    ],
    "diastolic_bp": [
        "dbp",
        "diastolic_bp",
        "diastolic"
    ],
    "pain": [
        "pain",
        "pain_score",
        "pain_scale"
    ],
    "acuity": [
        "acuity",
        "triage",
        "triage_level",
        "esi"
    ],
    "age": [
        "age"
    ],
    "gender": [
        "gender",
        "sex"
    ]
}

def resolve_column_aliases(df: pd.DataFrame) -> Dict[str, str]:
    """Matches dataframe columns to canonical concept names using configured aliases.
    Only selects an alias if that column actually exists in the dataframe.
    """
    resolved: Dict[str, str] = {}
    lower_to_actual = {col.lower(): col for col in df.columns}

    for canonical, aliases in COLUMN_ALIASES.items():
        for alias in aliases:
            if alias in lower_to_actual:
                resolved[canonical] = lower_to_actual[alias]
                break

    return resolved

def inspect_dataset_split(df: pd.DataFrame, split_name: str = "TRAIN") -> Dict[str, Any]:
    """Produces detailed structural summary of dataset split."""
    info = {
        "split": split_name,
        "shape": df.shape,
        "columns": df.columns.tolist(),
        "dtypes": {str(k): str(v) for k, v in df.dtypes.items()},
        "missing_counts": {str(k): int(v) for k, v in df.isnull().sum().items()},
        "resolved_aliases": resolve_column_aliases(df)
    }
    return info
