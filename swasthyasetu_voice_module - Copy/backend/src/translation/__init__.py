"""SwasthyaSetu Translation Package."""

from src.translation.translation_adapter import (
    detect_language, translate_to_english, translate_from_english, VERNACULAR_EMERGENCY_TEXTS
)

__all__ = [
    "detect_language",
    "translate_to_english",
    "translate_from_english",
    "VERNACULAR_EMERGENCY_TEXTS"
]
