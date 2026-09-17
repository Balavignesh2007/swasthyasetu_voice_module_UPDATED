"""Centralized, version-controlled clinical vocabulary.
Maps synonyms, colloquialisms, and regional expressions to canonical clinical concepts.
Shared between dataset normalization and live patient normalization.
"""

from typing import Dict, Optional, List

CANONICAL_SYMPTOMS: Dict[str, str] = {
    # Respiratory
    "breathlessness": "difficulty_breathing",
    "breathless": "difficulty_breathing",
    "feeling breathless": "difficulty_breathing",
    "shortness of breath": "difficulty_breathing",
    "sob": "difficulty_breathing",
    "breathing difficulty": "difficulty_breathing",
    "difficulty breathing": "difficulty_breathing",
    "difficulty in breathing": "difficulty_breathing",
    "cannot breathe": "difficulty_breathing",
    "can't breathe": "difficulty_breathing",
    "hard to breathe": "difficulty_breathing",
    "breathing problem": "difficulty_breathing",
    "dyspnea": "difficulty_breathing",
    "gasping for air": "difficulty_breathing",
    "wheezing": "wheezing",
    "stridor": "stridor",
    "cough": "cough",
    "dry cough": "dry_cough",
    "productive cough": "productive_cough",
    "wet cough": "productive_cough",
    "coughing up blood": "hemoptysis",
    "hemoptysis": "hemoptysis",

    # Cardiovascular & Chest
    "chest pain": "chest_pain",
    "pain in chest": "chest_pain",
    "heartache": "chest_pain",
    "heart ache": "chest_pain",
    "heart pain": "chest_pain",
    "heart attack": "chest_pain",
    "pain in heart": "chest_pain",
    "pain in my heart": "chest_pain",
    "chest tightness": "chest_tightness",
    "pressure on chest": "chest_pressure",
    "chest heaviness": "chest_heaviness",
    "palpitations": "palpitations",
    "racing heart": "palpitations",
    "irregular heartbeat": "arrhythmia",

    # Gastrointestinal
    "stomach ache": "abdominal_pain",
    "belly pain": "abdominal_pain",
    "tummy pain": "abdominal_pain",
    "abdominal pain": "abdominal_pain",
    "pain in stomach": "abdominal_pain",
    "nausea": "nausea",
    "feeling sick": "nausea",
    "vomiting": "vomiting",
    "throwing up": "vomiting",
    "vomiting blood": "hematemesis",
    "hematemesis": "hematemesis",
    "diarrhea": "diarrhea",
    "loose motions": "diarrhea",
    "watery stool": "diarrhea",
    "blood in stool": "hematochezia",
    "black stool": "melena",
    "constipation": "constipation",
    "acidity": "dyspepsia",
    "heartburn": "dyspepsia",

    # Neurological
    "headache": "headache",
    "head pain": "headache",
    "severe headache": "severe_headache",
    "dizziness": "dizziness",
    "lightheadedness": "dizziness",
    "giddiness": "dizziness",
    "fainting": "syncope",
    "blackout": "syncope",
    "passed out": "unconsciousness",
    "unconscious": "unconsciousness",
    "unresponsiveness": "unconsciousness",
    "seizure": "seizure",
    "convulsion": "seizure",
    "fits": "seizure",
    "paralysis": "paralysis",
    "weakness on one side": "hemiparesis",
    "slurred speech": "dysarthria",
    "confusion": "altered_mental_status",
    "altered mental status": "altered_mental_status",

    # Systemic & Infectious
    "fever": "fever",
    "high fever": "high_fever",
    "pyrexia": "fever",
    "chills": "chills",
    "shivering": "chills",
    "fatigue": "fatigue",
    "extreme tiredness": "fatigue",
    "weakness": "generalized_weakness",
    "body ache": "myalgia",
    "muscle pain": "myalgia",
    "joint pain": "arthralgia",

    # Traumatic & Bleeding
    "bleeding": "bleeding",
    "hemorrhage": "severe_bleeding",
    "profuse bleeding": "severe_bleeding",
    "injury": "trauma",
    "wound": "wound",
    "fracture": "fracture",
    "burn": "burn",
}

VOCABULARY_VERSION = "1.0.0"

def get_canonical_symptom(term: str) -> Optional[str]:
    """Returns canonical symptom identifier if matched."""
    cleaned = term.strip().lower()
    return CANONICAL_SYMPTOMS.get(cleaned)

def get_all_canonical_concepts() -> List[str]:
    """Returns unique list of all canonical concepts."""
    return sorted(list(set(CANONICAL_SYMPTOMS.values())))
