"""Spelling and ASR speech-recognition phonetic correction dictionary."""

from typing import Dict

ASR_SPELLING_CORRECTIONS: Dict[str, str] = {
    # Common ASR / SMS phonetic slips
    "hav": "have",
    "hv": "have",
    "seveer": "severe",
    "sever": "severe",
    "sevear": "severe",
    "frm": "for",
    "fr": "for",
    "hrs": "hours",
    "hr": "hours",
    "mins": "minutes",
    "min": "minutes",
    "n": "and",
    "nd": "and",
    "brethless": "breathless",
    "breathles": "breathless",
    "breathingless": "breathless",
    "brethe": "breathe",
    "difficutly": "difficulty",
    "difficuly": "difficulty",
    "fevr": "fever",
    "feverr": "fever",
    "hedache": "headache",
    "headach": "headache",
    "stomache": "stomach",
    "stomachache": "stomach ache",
    "vomitin": "vomiting",
    "vomting": "vomiting",
    "dizzines": "dizziness",
    "bleedng": "bleeding",
    "unconcious": "unconscious",
    "unconcsious": "unconscious",
    "chestpain": "chest pain",
    "coughin": "coughing",
    "pein": "pain",
    "pan": "pain",
    "shiverng": "shivering",
    "palpitation": "palpitations",
}

def correct_spelling_token(token: str) -> str:
    cleaned = token.strip().lower()
    return ASR_SPELLING_CORRECTIONS.get(cleaned, token)
