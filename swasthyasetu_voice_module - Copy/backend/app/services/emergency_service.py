from dataclasses import dataclass
from typing import Optional, List

@dataclass
class EmergencyScreenResult:
    is_emergency: bool
    red_flag_type: Optional[str] = None
    matched_symptom: Optional[str] = None

class EmergencySafetyService:
    RULES = {
        'chest pain': 'Severe Chest Pain',
        'heart pain': 'Severe Cardiac / Chest Pain',
        'chest tightness': 'Severe Chest Tightness / Cardiac Pain',
        'chest pressure': 'Severe Chest Pressure',
        'heart attack': 'Suspected Heart Attack / Acute Coronary Syndrome',
        'difficulty breathing': 'Difficulty Breathing',
        'shortness of breath': 'Shortness of Breath',
        'breathing problem': 'Difficulty Breathing',
        'loss of consciousness': 'Loss of Consciousness',
        'unconsciousness': 'Loss of Consciousness',
        'fainting': 'Syncope / Loss of Consciousness',
        'seizure': 'Active Seizure',
        'severe bleeding': 'Severe Bleeding',
        'vomiting blood': 'Vomiting Blood',
        'coughing up blood': 'Coughing Up Blood',
        'stroke': 'Suspected Acute Stroke',
        'paralysis': 'Sudden Weakness / Paralysis',
    }
    def screen(self, symptoms: List[str]) -> EmergencyScreenResult:
        vals = {str(s).strip().lower() for s in symptoms if s}
        joined = ' '.join(vals)
        has_chest = any(k in joined or k in vals for k in ['chest pain', 'heart pain', 'chest tightness', 'chest pressure', 'heart attack'])
        has_breath = any(k in joined or k in vals for k in ['difficulty breathing', 'shortness of breath', 'breathing problem', 'dyspnea'])

        if has_chest and has_breath:
            return EmergencyScreenResult(True, 'Severe Chest Pain with Breathing Difficulty', 'Chest Pain & Breathing')
        if has_chest:
            return EmergencyScreenResult(True, 'Severe Chest / Cardiac Pain', 'Chest / Heart Pain')
        if has_breath:
            return EmergencyScreenResult(True, 'Severe Breathing Difficulty', 'Breathing Difficulty')

        for key, label in self.RULES.items():
            if key in vals or key in joined:
                return EmergencyScreenResult(True, label, key.title())
        return EmergencyScreenResult(False)

emergency_safety_service = EmergencySafetyService()
