"""Dataset batch normalization pipeline.
Processes raw clinical and triage datasets into normalized datasets reproducibly
without modifying the raw source files or leaking future information.
"""

import os
import pandas as pd
from typing import Optional, Dict
from src.normalization.normalizer import clinical_normalizer

class DatasetNormalizer:
    """Normalizes tabular clinical datasets preserving raw integrity."""

    def __init__(self, normalizer=clinical_normalizer):
        self.normalizer = normalizer

    def normalize_dataframe(
        self,
        df: pd.DataFrame,
        text_column: str,
        target_column: Optional[str] = None,
        label_mapping: Optional[Dict[str, str]] = None
    ) -> pd.DataFrame:
        """Processes dataframe creating normalized text, extracted symptoms, and mapped targets."""
        processed_df = df.copy()

        # Preserve original complaint
        processed_df["original_chief_complaint"] = processed_df[text_column]

        # Apply clinical normalization
        normalized_records = [
            self.normalizer.normalize(str(val) if pd.notnull(val) else "")
            for val in processed_df[text_column]
        ]

        processed_df["normalized_chief_complaint"] = [r.normalized_text for r in normalized_records]
        processed_df["extracted_present_symptoms"] = [",".join(r.present_symptoms) for r in normalized_records]
        processed_df["extracted_negated_symptoms"] = [",".join(r.negated_symptoms) for r in normalized_records]
        processed_df["extracted_canonical_symptoms"] = [",".join(r.canonical_symptoms) for r in normalized_records]
        processed_df["extracted_duration_hours"] = [r.duration_hours for r in normalized_records]
        processed_df["extracted_pain_score"] = [r.pain_score for r in normalized_records]

        # Preserve original acuity and map to project triage level if available
        if target_column and target_column in processed_df.columns:
            processed_df["original_acuity"] = processed_df[target_column]
            if label_mapping:
                processed_df["project_triage_level"] = processed_df["original_acuity"].astype(str).map(label_mapping)

        return processed_df

    def process_and_save(
        self,
        raw_filepath: str,
        output_filepath: str,
        text_column: str,
        target_column: Optional[str] = None,
        label_mapping: Optional[Dict[str, str]] = None
    ) -> pd.DataFrame:
        """Loads raw dataset, normalizes it, and saves to processed destination."""
        if not os.path.exists(raw_filepath):
            raise FileNotFoundError(f"Raw dataset file not found: {raw_filepath}")

        os.makedirs(os.path.dirname(output_filepath), exist_ok=True)

        if raw_filepath.endswith(".parquet"):
            df = pd.read_parquet(raw_filepath)
        elif raw_filepath.endswith(".csv"):
            df = pd.read_csv(raw_filepath)
        else:
            raise ValueError("Unsupported format. Use .parquet or .csv")

        normalized_df = self.normalize_dataframe(df, text_column, target_column, label_mapping)
        if output_filepath.endswith(".parquet"):
            normalized_df.to_parquet(output_filepath, index=False)
        else:
            normalized_df.to_csv(output_filepath, index=False)

        return normalized_df
