"""Configurable Clinical Specialty Mapping Module.
Maps normalized clinical symptoms and context to appropriate medical specialties.
Can be updated dynamically by administrators.
"""

from typing import Dict, List, Optional

# Default clinical context -> medical specialty mapping
CLINICAL_SPECIALTY_MAP: Dict[str, str] = {
    # Ophthalmology (Eye & Vision)
    "eye": "Ophthalmology",
    "eyes": "Ophthalmology",
    "eye_pain": "Ophthalmology",
    "eye_redness": "Ophthalmology",
    "eye_irritation": "Ophthalmology",
    "eye_discharge": "Ophthalmology",
    "eye_swelling": "Ophthalmology",
    "eye_issue": "Ophthalmology",
    "eye_issues": "Ophthalmology",
    "eye_problem": "Ophthalmology",
    "eye_problems": "Ophthalmology",
    "vision": "Ophthalmology",
    "blurred_vision": "Ophthalmology",
    "vision_loss": "Ophthalmology",
    "double_vision": "Ophthalmology",
    "cataract": "Ophthalmology",
    "glaucoma": "Ophthalmology",
    "red_eye": "Ophthalmology",
    "watery_eyes": "Ophthalmology",
    "dry_eyes": "Ophthalmology",
    "ocular": "Ophthalmology",
    "cornea": "Ophthalmology",
    "retina": "Ophthalmology",

    # Dermatology (Skin & Rashes)
    "rash": "Dermatology",
    "skin": "Dermatology",
    "itching": "Dermatology",
    "burn": "Dermatology",
    "skin_rash": "Dermatology",
    "skin_lesion": "Dermatology",
    "eczema": "Dermatology",
    "psoriasis": "Dermatology",

    # Dentistry (Teeth & Gums)
    "tooth": "Dentistry",
    "teeth": "Dentistry",
    "toothache": "Dentistry",
    "dental": "Dentistry",
    "gum_bleeding": "Dentistry",
    "swollen_gums": "Dentistry",

    # Cardiology (Heart & Circulation)
    "chest_pain": "Cardiology",
    "palpitations": "Cardiology",
    "arrhythmia": "Cardiology",
    "chest_pressure": "Cardiology",
    "heart": "Cardiology",

    # Pulmonology (Lungs & Respiratory)
    "difficulty_breathing": "Pulmonology",
    "cough": "Pulmonology",
    "wheezing": "Pulmonology",
    "hemoptysis": "Pulmonology",
    "shortness_of_breath": "Pulmonology",
    "breathlessness": "Pulmonology",

    # Gastroenterology (Stomach & Digestive)
    "abdominal_pain": "Gastroenterology",
    "stomach_pain": "Gastroenterology",
    "vomiting": "Gastroenterology",
    "diarrhea": "Gastroenterology",
    "dyspepsia": "Gastroenterology",
    "hematemesis": "Gastroenterology",
    "nausea": "Gastroenterology",

    # Neurology (Brain & Nervous System)
    "headache": "Neurology",
    "severe_headache": "Neurology",
    "seizure": "Neurology",
    "dizziness": "Neurology",
    "syncope": "Neurology",
    "unconsciousness": "Neurology",
    "numbness": "Neurology",

    # General / Default
    "fever": "General Medicine",
    "fatigue": "General Medicine",
    "chills": "General Medicine",
    "generalized_weakness": "General Medicine"
}


def resolve_specialty_for_symptoms(symptoms: List[str], text: Optional[str] = None) -> str:
    """Selects the most specific medical specialty for the patient's symptoms."""
    # 1. Exact match on symptom tokens
    for sym in symptoms:
        s_lower = sym.lower().replace(" ", "_").strip()
        if s_lower in CLINICAL_SPECIALTY_MAP:
            return CLINICAL_SPECIALTY_MAP[s_lower]

    # 2. Keyword substring matching on symptoms
    for sym in symptoms:
        s_lower = sym.lower().replace("_", " ")
        if any(w in s_lower for w in ["eye", "vision", "optic", "ocular", "sight"]):
            return "Ophthalmology"
        if any(w in s_lower for w in ["skin", "rash", "itch", "dermat"]):
            return "Dermatology"
        if any(w in s_lower for w in ["tooth", "teeth", "dental", "gum"]):
            return "Dentistry"
        if any(w in s_lower for w in ["chest pain", "heart", "palpitation"]):
            return "Cardiology"
        if any(w in s_lower for w in ["breath", "cough", "lung", "wheez"]):
            return "Pulmonology"
        if any(w in s_lower for w in ["stomach", "abdomen", "vomit", "diarrhea"]):
            return "Gastroenterology"
        if any(w in s_lower for w in ["headache", "seizure", "dizzy"]):
            return "Neurology"

    # 3. Substring matching on raw/normalized text if provided
    if text:
        t_lower = text.lower()
        if any(w in t_lower for w in ["eye", "vision", "ophthalm", "optic", "blind", "cornea"]):
            return "Ophthalmology"
        if any(w in t_lower for w in ["skin", "rash", "dermatol", "eczema"]):
            return "Dermatology"
        if any(w in t_lower for w in ["tooth", "teeth", "dentist", "gum"]):
            return "Dentistry"
        if any(w in t_lower for w in ["chest pain", "cardio", "heart attack"]):
            return "Cardiology"

    return "General Medicine"


def update_specialty_mapping(concept: str, specialty: str):
    """Allows administrators to dynamically register or update specialty rules."""
    CLINICAL_SPECIALTY_MAP[concept.lower().strip()] = specialty.strip()

