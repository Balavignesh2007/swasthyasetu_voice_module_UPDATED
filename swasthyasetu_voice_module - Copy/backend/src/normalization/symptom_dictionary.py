"""Symptom dictionary with categories and canonical mapping."""

from typing import Dict, List

SYMPTOM_CATEGORIES: Dict[str, List[str]] = {
    "respiratory": ["difficulty_breathing", "cough", "wheezing", "stridor", "hemoptysis"],
    "cardiovascular": ["chest_pain", "chest_tightness", "chest_pressure", "palpitations", "arrhythmia"],
    "gastrointestinal": ["abdominal_pain", "nausea", "vomiting", "diarrhea", "hematemesis", "dyspepsia"],
    "neurological": ["headache", "severe_headache", "dizziness", "syncope", "unconsciousness", "seizure", "hemiparesis", "altered_mental_status"],
    "systemic": ["fever", "high_fever", "chills", "fatigue", "generalized_weakness", "myalgia", "arthralgia"],
    "emergency_critical": ["unconsciousness", "seizure", "severe_bleeding", "hemoptysis", "hematemesis", "altered_mental_status", "hemiparesis"]
}

DANGER_SYMPTOMS = set(SYMPTOM_CATEGORIES["emergency_critical"]) | {
    "difficulty_breathing", "chest_pain"
}

def is_danger_symptom(canonical_symptom: str) -> bool:
    return canonical_symptom in DANGER_SYMPTOMS
