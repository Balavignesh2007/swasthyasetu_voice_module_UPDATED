"""Comprehensive Clinical Normalization Pipeline.

Executes:
1. Unicode normalization
2. Whitespace cleanup
3. Sentence cleanup
4. ASR/spelling correction
5. Medical synonym normalization
6. Abbreviation expansion
7. Number normalization
8. Unit normalization
9. Duration normalization
10. Severity preservation
11. Negation preservation
12. Uncertainty preservation
13. Body-location preservation

Preserves original transcript without inventing clinical information.
"""

import unicodedata
import re
from typing import Dict, Any, List, Optional
from dataclasses import dataclass, field, asdict

try:
    from src.normalization.spelling_dictionary import correct_spelling_token
    from src.normalization.abbreviation_dictionary import expand_abbreviation, MEDICAL_ABBREVIATIONS
    from src.normalization.medical_vocabulary import CANONICAL_SYMPTOMS, get_canonical_symptom
    from src.normalization.body_part_dictionary import BODY_PARTS
    from src.normalization.negation import partition_symptoms_by_negation
    from src.normalization.severity import extract_severity_map, extract_pain_score
    from src.normalization.duration import extract_duration_hours, normalize_duration_phrase
    from src.normalization.units import parse_vitals_from_text
except ImportError:
    from backend.src.normalization.spelling_dictionary import correct_spelling_token
    from backend.src.normalization.abbreviation_dictionary import expand_abbreviation, MEDICAL_ABBREVIATIONS
    from backend.src.normalization.medical_vocabulary import CANONICAL_SYMPTOMS, get_canonical_symptom
    from backend.src.normalization.body_part_dictionary import BODY_PARTS
    from backend.src.normalization.negation import partition_symptoms_by_negation
    from backend.src.normalization.severity import extract_severity_map, extract_pain_score
    from backend.src.normalization.duration import extract_duration_hours, normalize_duration_phrase
    from backend.src.normalization.units import parse_vitals_from_text

@dataclass
class NormalizedClinicalRecord:
    original_text: str
    normalized_text: str
    present_symptoms: List[str] = field(default_factory=list)
    negated_symptoms: List[str] = field(default_factory=list)
    canonical_symptoms: List[str] = field(default_factory=list)
    severity_map: Dict[str, str] = field(default_factory=dict)
    pain_score: Optional[int] = None
    duration_hours: Optional[float] = None
    body_parts: List[str] = field(default_factory=list)
    vitals: Dict[str, Any] = field(default_factory=dict)
    uncertainty_detected: bool = False

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

class ClinicalNormalizer:
    """Production clinical normalizer preserving clinical fidelity."""

    def __init__(self, version: str = "1.0.0"):
        self.version = version

    def normalize(self, text: str) -> NormalizedClinicalRecord:
        if not text or not text.strip():
            return NormalizedClinicalRecord(original_text="", normalized_text="")

        original = text.strip()

        # 1. Unicode normalization (NFKC)
        cleaned = unicodedata.normalize("NFKC", original)

        # 2. Whitespace cleanup
        cleaned = re.sub(r'\s+', ' ', cleaned).strip()

        # 3. Sentence cleanup (fix spaces before punctuation)
        cleaned = re.sub(r'\s+([.,;:!?])', r'\1', cleaned)

        # 4. ASR / Spelling correction
        tokens = cleaned.split(" ")
        spelling_corrected_tokens = [correct_spelling_token(t) for t in tokens]
        step4_text = " ".join(spelling_corrected_tokens)

        # 5. Abbreviation expansion
        step5_tokens = []
        for tok in step4_text.split(" "):
            # Strip punctuation for abbreviation check
            stripped = re.sub(r'^[^\w]+|[^\w]+$', '', tok)
            if stripped.lower() in MEDICAL_ABBREVIATIONS:
                expanded = expand_abbreviation(stripped)
                tok = tok.replace(stripped, expanded)
            step5_tokens.append(tok)
        step5_text = " ".join(step5_tokens)

        # 6. Duration phrase normalization (e.g. 'frm 2 hrs' -> 'for 2 hours')
        step6_text = normalize_duration_phrase(step5_text)

        # Handle colloquial 'n' -> 'and'
        step6_text = re.sub(r'\bn\b', 'and', step6_text, flags=re.IGNORECASE)

        # 7. Medical synonym normalization
        # Replace multi-word colloquial phrases with standard clinical terms
        normalized_phrase_text = step6_text
        for phrase, canonical in CANONICAL_SYMPTOMS.items():
            # e.g., 'breathing difficulty' or 'breathless' -> 'difficulty breathing'
            if phrase in ("breathing difficulty", "breathlessness", "shortness of breath", "gasping for air", "breathless"):
                pattern = rf'\b{re.escape(phrase)}\b'
                normalized_phrase_text = re.sub(pattern, "difficulty breathing", normalized_phrase_text, flags=re.IGNORECASE)
            elif phrase in ("tummy pain", "belly pain", "stomach ache"):
                pattern = rf'\b{re.escape(phrase)}\b'
                normalized_phrase_text = re.sub(pattern, "abdominal pain", normalized_phrase_text, flags=re.IGNORECASE)

        # Final sentence capitalization & formatting
        final_normalized_text = normalized_phrase_text[0].upper() + normalized_phrase_text[1:] if normalized_phrase_text else ""
        if final_normalized_text and not final_normalized_text.endswith((".", "!", "?")):
            final_normalized_text += "."

        # --- Clinical Feature & Information Extraction (Never Lost) ---

        # Candidate symptoms extraction
        candidate_symptoms: List[str] = []

        text_lower = final_normalized_text.lower()
        for phrase, canonical in CANONICAL_SYMPTOMS.items():
            if re.search(rf'\b{re.escape(phrase)}\b', text_lower):
                candidate_symptoms.append(phrase)

        # Body parts
        detected_body_parts = set()
        for bp_phrase, canonical_bp in BODY_PARTS.items():
            if re.search(rf'\b{re.escape(bp_phrase)}\b', text_lower):
                detected_body_parts.add(canonical_bp)

        # Negation preservation
        present_symptoms, negated_symptoms = partition_symptoms_by_negation(final_normalized_text, candidate_symptoms)

        # Map present symptoms to canonical
        canonical_present: List[str] = []
        for s in present_symptoms:
            c = get_canonical_symptom(s)
            if c and c not in canonical_present:
                canonical_present.append(c)

        # Severity preservation
        severity_map = extract_severity_map(final_normalized_text, present_symptoms)
        pain_score = extract_pain_score(final_normalized_text)

        # Duration preservation
        duration_hrs = extract_duration_hours(final_normalized_text)

        # Vitals extraction
        vitals = parse_vitals_from_text(final_normalized_text)

        # Uncertainty check (e.g. maybe, perhaps, possibly)
        uncertainty = bool(re.search(r'\b(maybe|perhaps|possibly|not sure|wondering)\b', text_lower))

        return NormalizedClinicalRecord(
            original_text=original,
            normalized_text=final_normalized_text,
            present_symptoms=present_symptoms,
            negated_symptoms=negated_symptoms,
            canonical_symptoms=canonical_present,
            severity_map=severity_map,
            pain_score=pain_score,
            duration_hours=duration_hrs,
            body_parts=sorted(list(detected_body_parts)),
            vitals=vitals,
            uncertainty_detected=uncertainty
        )

# Global singleton instance for high performance
clinical_normalizer = ClinicalNormalizer()
