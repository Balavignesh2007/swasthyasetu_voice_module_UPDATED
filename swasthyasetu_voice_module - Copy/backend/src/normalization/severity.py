"""Clinical severity extraction and preservation module."""

from typing import Dict, Optional, List
import re

SEVERITY_LEVELS: Dict[str, str] = {
    "mild": "mild",
    "slight": "mild",
    "minor": "mild",
    "little": "mild",
    "moderate": "moderate",
    "medium": "moderate",
    "tolerable": "moderate",
    "severe": "severe",
    "seveer": "severe",
    "very bad": "severe",
    "terrible": "severe",
    "intense": "severe",
    "excruciating": "critical",
    "unbearable": "critical",
    "critical": "critical",
    "acute": "severe"
}

def extract_severity_map(text: str, detected_symptoms: List[str]) -> Dict[str, str]:
    """Maps detected symptoms to their explicit clinical severity."""
    severity_map: Dict[str, str] = {}

    for symptom in detected_symptoms:
        # Check if severity word precedes or follows the symptom within 3 words
        sym_pattern = re.escape(symptom)
        for term, canonical_sev in SEVERITY_LEVELS.items():
            pattern = rf'\b{re.escape(term)}\b\s+(?:\w+\s+){{0,2}}{sym_pattern}\b|\b{sym_pattern}\b\s+(?:is\s+|was\s+)?{re.escape(term)}\b'
            if re.search(pattern, text, re.IGNORECASE):
                severity_map[symptom] = canonical_sev
                break

    # If general severe phrase exists and symptom is present without specific map
    if "severe" in text.lower() or "excruciating" in text.lower():
        for s in detected_symptoms:
            if s not in severity_map:
                # If only 1 symptom present, assign severe
                if len(detected_symptoms) == 1:
                    severity_map[s] = "severe"

    return severity_map

def extract_pain_score(text: str) -> Optional[int]:
    """Extracts numeric pain scale (0-10) if mentioned."""
    match = re.search(r'\b(?:pain\s*(?:scale|score|is)?\s*)?(\d{1,2})\s*(?:/|out\s+of)\s*10\b', text, re.IGNORECASE)
    if match:
        val = int(match.group(1))
        if 0 <= val <= 10:
            return val

    # Direct "pain 8" or "8 out of 10"
    match2 = re.search(r'\bpain\s*(?:is|=|:)?\s*(\d{1,2})\b', text, re.IGNORECASE)
    if match2:
        val = int(match2.group(1))
        if 1 <= val <= 10:
            return val
    return None
