"""Medical abbreviation expansion dictionary.
Expands common clinical and colloquial medical acronyms into plain English terms.
"""

from typing import Dict

MEDICAL_ABBREVIATIONS: Dict[str, str] = {
    "sob": "difficulty breathing",
    "bp": "blood pressure",
    "hr": "heart rate",
    "rr": "respiratory rate",
    "o2": "oxygen",
    "spo2": "oxygen saturation",
    "htn": "hypertension",
    "dm": "diabetes mellitus",
    "t2dm": "type 2 diabetes",
    "mi": "myocardial infarction",
    "cva": "stroke",
    "gi": "gastrointestinal",
    "copd": "chronic obstructive pulmonary disease",
    "uti": "urinary tract infection",
    "tb": "tuberculosis",
    "ed": "emergency department",
    "er": "emergency room",
    "icu": "intensive care unit",
    "temp": "temperature",
    "hx": "history",
    "rx": "prescription",
    "sx": "symptoms",
    "dx": "diagnosis",
    "yo": "years old",
    "y/o": "years old",
    "f": "female",
    "m": "male"
}

def expand_abbreviation(token: str) -> str:
    cleaned = token.strip().lower()
    return MEDICAL_ABBREVIATIONS.get(cleaned, token)
