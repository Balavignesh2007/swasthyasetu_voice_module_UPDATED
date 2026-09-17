"""Anatomical body locations and organ system dictionary."""

from typing import Dict, Optional, List

BODY_PARTS: Dict[str, str] = {
    "chest": "chest",
    "heart": "chest",
    "lungs": "chest",
    "ribs": "chest",
    "stomach": "abdomen",
    "belly": "abdomen",
    "tummy": "abdomen",
    "abdomen": "abdomen",
    "gut": "abdomen",
    "head": "head",
    "forehead": "head",
    "throat": "throat",
    "neck": "neck",
    "back": "back",
    "lower back": "lumbar",
    "spine": "spine",
    "arm": "arm",
    "left arm": "left_arm",
    "right arm": "right_arm",
    "shoulder": "shoulder",
    "leg": "leg",
    "knee": "knee",
    "foot": "foot",
    "eye": "eye",
    "eyes": "eye",
    "ear": "ear",
    "ears": "ear",
    "mouth": "mouth",
    "skin": "skin",
}

def get_canonical_body_part(term: str) -> Optional[str]:
    cleaned = term.strip().lower()
    return BODY_PARTS.get(cleaned)

def get_all_body_parts() -> List[str]:
    return sorted(list(set(BODY_PARTS.values())))
