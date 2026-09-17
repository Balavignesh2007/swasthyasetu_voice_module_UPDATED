"""Unit conversion and normalization helper functions."""

from typing import Tuple
import re

def normalize_temperature(value: float, unit: str) -> Tuple[float, str]:
    """Normalizes temperature to Celsius and Fahrenheit representations."""
    unit_clean = unit.strip().lower()
    if unit_clean in ("f", "fahrenheit", "deg f", "degrees"):
        celsius = (value - 32.0) * 5.0 / 9.0
        return round(celsius, 1), "celsius"
    return round(value, 1), "celsius"

def parse_vitals_from_text(text: str) -> dict:
    """Parses standard vital signs from clinical text if present."""
    vitals = {
        "temperature": None,
        "heart_rate": None,
        "respiratory_rate": None,
        "oxygen_saturation": None,
        "systolic_bp": None,
        "diastolic_bp": None
    }

    # Temperature (e.g., 102 F, 38.5 C, 99.4 degrees)
    temp_match = re.search(r'(\d{2,3}(?:\.\d)?)\s*(?:degrees?|deg)?\s*(f|c|celsius|fahrenheit)\b', text, re.IGNORECASE)
    if temp_match:
        val = float(temp_match.group(1))
        unit = temp_match.group(2).lower()
        if unit.startswith("f") or val > 50: # Likely Fahrenheit
            celsius = (val - 32.0) * 5.0 / 9.0
            vitals["temperature"] = round(celsius, 1)
        else:
            vitals["temperature"] = round(val, 1)

    # Blood Pressure (e.g. 120/80, BP 140/90)
    bp_match = re.search(r'\b(?:bp\s*)?(\d{2,3})\s*/\s*(\d{2,3})\b', text, re.IGNORECASE)
    if bp_match:
        vitals["systolic_bp"] = int(bp_match.group(1))
        vitals["diastolic_bp"] = int(bp_match.group(2))

    # Heart Rate (e.g., HR 110, pulse 95, 100 bpm)
    hr_match = re.search(r'\b(?:hr|pulse|heart\s*rate)\s*(?:is|=|:)?\s*(\d{2,3})\b|\b(\d{2,3})\s*bpm\b', text, re.IGNORECASE)
    if hr_match:
        val = hr_match.group(1) or hr_match.group(2)
        vitals["heart_rate"] = int(val)

    # SpO2 / O2 Sat (e.g., SpO2 92%, O2 sat 88)
    o2_match = re.search(r'\b(?:spo2|o2\s*sat(?:uration)?)\s*(?:is|=|:)?\s*(\d{2,3})\s*%?\b', text, re.IGNORECASE)
    if o2_match:
        vitals["oxygen_saturation"] = int(o2_match.group(1))

    # Respiratory Rate (e.g., RR 24, resp rate 28)
    rr_match = re.search(r'\b(?:rr|resp(?:iratory)?\s*rate)\s*(?:is|=|:)?\s*(\d{1,2})\b', text, re.IGNORECASE)
    if rr_match:
        vitals["respiratory_rate"] = int(rr_match.group(1))

    return vitals
