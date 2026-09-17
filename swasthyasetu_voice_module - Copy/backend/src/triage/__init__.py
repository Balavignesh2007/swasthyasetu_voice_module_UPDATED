"""SwasthyaSetu Clinical Triage Package."""

from src.triage.dataset_inspector import COLUMN_ALIASES, resolve_column_aliases, inspect_dataset_split
from src.triage.label_mapping import ESI_TO_PROJECT_TRIAGE, map_acuity_to_project_triage
from src.triage.danger_sign_rules import evaluate_danger_signs, SafetyEvaluationResult
from src.triage.feature_builder import build_clinical_features, FEATURE_SCHEMA_COLUMNS
from src.triage.preprocessing import build_clinical_preprocessor, prepare_feature_dataframe
from src.triage.triage_model import TriageModelPipeline, TRIAGE_CLASSES
from src.triage.prediction import TriageEngine, FinalTriageDecision, triage_engine

__all__ = [
    "COLUMN_ALIASES",
    "resolve_column_aliases",
    "inspect_dataset_split",
    "ESI_TO_PROJECT_TRIAGE",
    "map_acuity_to_project_triage",
    "evaluate_danger_signs",
    "SafetyEvaluationResult",
    "build_clinical_features",
    "FEATURE_SCHEMA_COLUMNS",
    "build_clinical_preprocessor",
    "prepare_feature_dataframe",
    "TriageModelPipeline",
    "TRIAGE_CLASSES",
    "TriageEngine",
    "FinalTriageDecision",
    "triage_engine"
]
