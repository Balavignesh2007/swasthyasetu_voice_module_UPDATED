"""Clinical symptom duration and frequency extraction module."""

from typing import Optional
import re

DURATION_PATTERNS = [
    (r'(?:for|since|past|last|from|frm)\s+(\d+(?:\.\d+)?)\s*(?:hours?|hrs?|hr)\b', 1.0),
    (r'(\d+(?:\.\d+)?)\s*(?:hours?|hrs?|hr)\s*(?:ago|duration)?\b', 1.0),
    (r'(?:for|since|past|last|from|frm)\s+(\d+(?:\.\d+)?)\s*(?:days?|d)\b', 24.0),
    (r'(\d+(?:\.\d+)?)\s*(?:days?|d)\s*(?:ago|duration)?\b', 24.0),
    (r'(?:for|since|past|last|from|frm)\s+(\d+(?:\.\d+)?)\s*(?:weeks?|wks?|wk)\b', 168.0),
    (r'(?:for|since|past|last|from|frm)\s+(\d+(?:\.\d+)?)\s*(?:months?|mos?|mo)\b', 720.0),
    (r'(?:for|since|past|last|from|frm)\s+(\d+(?:\.\d+)?)\s*(?:minutes?|mins?|min)\b', 1.0 / 60.0),
]

def extract_duration_hours(text: str) -> Optional[float]:
    """Extracts duration and standardizes it into total duration hours."""
    cleaned = text.lower()
    for pattern, multiplier in DURATION_PATTERNS:
        match = re.search(pattern, cleaned)
        if match:
            value = float(match.group(1))
            return round(value * multiplier, 2)
    return None

def normalize_duration_phrase(text: str) -> str:
    """Normalizes colloquial duration phrases like 'frm 2 hrs' to 'for 2 hours'."""
    # Replace frm -> for
    normalized = re.sub(r'\bfrm\s+(\d+)\s*hrs?\b', r'for \1 hours', text, flags=re.IGNORECASE)
    normalized = re.sub(r'\bfr\s+(\d+)\s*hrs?\b', r'for \1 hours', normalized, flags=re.IGNORECASE)
    normalized = re.sub(r'\b(\d+)\s*hrs?\b', r'\1 hours', normalized, flags=re.IGNORECASE)
    normalized = re.sub(r'\b(\d+)\s*mins?\b', r'\1 minutes', normalized, flags=re.IGNORECASE)
    return normalized
