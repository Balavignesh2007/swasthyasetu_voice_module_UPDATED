"""Clinical negation detection and preservation module.
Distinguishes asserted symptoms from ruled-out / negated symptoms.
Ensures expressions like "no fever" or "denies chest pain" are NEVER converted
into positive symptom presence.
"""

from typing import List, Tuple, Set
import re

# Negation triggers common in conversational and clinical notes
PRE_NEGATION_TRIGGERS = [
    r"\bno\b",
    r"\bnot\b",
    r"\bnever\b",
    r"\bwithout\b",
    r"\bdenies\b",
    r"\bdenied\b",
    r"\bdeny\b",
    r"\bnegative\s+for\b",
    r"\bfree\s+of\b",
    r"\babsence\s+of\b",
    r"\bruled\s+out\b",
    r"\bdo\s+not\s+have\b",
    r"\bdon\'?t\s+have\b",
    r"\bdoes\s+not\s+have\b",
    r"\bdoesn\'?t\s+have\b",
    r"\bdid\s+not\s+have\b",
    r"\bdidn\'?t\s+have\b",
    r"\bhaven\'?t\s+got\b",
    r"\bhasn\'?t\s+got\b",
]

POST_NEGATION_TRIGGERS = [
    r"\bis\s+absent\b",
    r"\bwas\s+absent\b",
    r"\bunlikely\b",
    r"\bnot\s+present\b",
]

CONJUNCTIONS_TERMINATING_NEGATION = [
    r"\bbut\b",
    r"\bhowever\b",
    r"\byet\b",
    r"\balso\b",
    r"\band\s+also\b",
    r"\balthough\b",
    r"\bexcept\b",
    r";",
    r"\.",
]

def split_clauses_with_negation(text: str) -> List[Tuple[str, bool]]:
    """Splits clinical text into clause segments and labels whether the clause is negated."""
    # First split by sentence or contrastive conjunctions
    clauses = re.split(r'([.,;]|\bbut\b|\bhowever\b|\balthough\b|\byet\b)', text, flags=re.IGNORECASE)

    labeled_clauses: List[Tuple[str, bool]] = []
    current_clause = ""

    for part in clauses:
        if not part:
            continue
        if re.match(r'^([.,;]|\bbut\b|\bhowever\b|\balthough\b|\byet\b)$', part, re.IGNORECASE):
            if current_clause.strip():
                is_neg = _is_negated(current_clause)
                labeled_clauses.append((current_clause.strip(), is_neg))
                current_clause = ""
        else:
            current_clause += " " + part

    if current_clause.strip():
        is_neg = _is_negated(current_clause)
        labeled_clauses.append((current_clause.strip(), is_neg))

    return labeled_clauses

def _is_negated(clause_text: str) -> bool:
    for trigger in PRE_NEGATION_TRIGGERS:
        if re.search(trigger, clause_text, re.IGNORECASE):
            return True
    for trigger in POST_NEGATION_TRIGGERS:
        if re.search(trigger, clause_text, re.IGNORECASE):
            return True
    return False

def partition_symptoms_by_negation(text: str, candidate_symptoms: List[str]) -> Tuple[List[str], List[str]]:
    """Partitions a list of candidate symptoms found in the text into present vs negated."""
    clauses = split_clauses_with_negation(text)
    present: Set[str] = set()
    negated: Set[str] = set()

    for sym in candidate_symptoms:
        sym_pattern = re.escape(sym)

        for clause, is_neg in clauses:
            if re.search(r'\b' + sym_pattern + r'\b', clause, re.IGNORECASE):
                if is_neg:
                    negated.add(sym)
                else:
                    present.add(sym)

        # If it appeared in both, positive assertion takes precedence if stated separately
        # but pure negation must not be classified as present
        if sym in negated and sym in present:
            # Check if there is explicit negation specifically for this term
            pass

    # A symptom that is explicitly negated must not appear in present
    present_clean = [s for s in present if s not in negated]
    return sorted(list(present_clean)), sorted(list(negated))
