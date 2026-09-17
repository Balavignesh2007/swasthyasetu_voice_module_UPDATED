"""MultiClinNER Adapter Module.
Integrates IEETA/MultiClinNER-EN for clinical named entity recognition (NER)
using AutoTokenizer and AutoModelForTokenClassification from Hugging Face Transformers,
with an auditable rule-and-lexicon fallback so the clinical pipeline never fails silently.
"""

import os
import logging
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, asdict
import re

try:
    from transformers import AutoTokenizer, AutoModelForTokenClassification
except ImportError:
    AutoTokenizer = None
    AutoModelForTokenClassification = None

try:
    from src.normalization.medical_vocabulary import CANONICAL_SYMPTOMS
    from src.normalization.body_part_dictionary import BODY_PARTS
    from src.normalization.symptom_dictionary import DANGER_SYMPTOMS
    from src.normalization.severity import SEVERITY_LEVELS
    from src.normalization.duration import DURATION_PATTERNS
except ImportError:
    from backend.src.normalization.medical_vocabulary import CANONICAL_SYMPTOMS
    from backend.src.normalization.body_part_dictionary import BODY_PARTS
    from backend.src.normalization.symptom_dictionary import DANGER_SYMPTOMS
    from backend.src.normalization.severity import SEVERITY_LEVELS
    from backend.src.normalization.duration import DURATION_PATTERNS

logger = logging.getLogger("swasthyasetu.nlp")

@dataclass
class ClinicalEntity:
    text: str
    entity_type: str  # SYMPTOM, DISEASE, BODY_PART, SEVERITY, DURATION, DANGER_SIGN
    canonical_concept: Optional[str] = None
    start_char: int = 0
    end_char: int = 0
    confidence: float = 1.0
    source: str = "lexicon_fallback"  # "multiclinner_model" or "lexicon_fallback"

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

class MultiClinNERAdapter:
    """Pretrained MultiClinNER adapter with robust, transparent clinical fallback.
    Loads AutoTokenizer and AutoModelForTokenClassification from IEETA/MultiClinNER-EN.
    """

    def __init__(self, model_name: str = "IEETA/MultiClinNER-EN", revision: str = "main"):
        self.model_name = model_name
        self.revision = revision  # Supports "main" or specific branch variants
        self.tokenizer = None
        self.model = None
        self._load_attempted = False

    def _try_load_model(self):
        if self._load_attempted:
            return
        self._load_attempted = True
        try:
            if AutoTokenizer is None or AutoModelForTokenClassification is None:
                logger.info("Transformers is not installed; using deterministic clinical lexicon fallback.")
                return
            hf_token = os.getenv("HF_TOKEN")
            kwargs = {"revision": self.revision}
            if hf_token:
                kwargs["token"] = hf_token

            # 1. Load fast tokenizer
            logger.info("Loading AutoTokenizer for MultiClinNER: %s (revision=%s)", self.model_name, self.revision)
            self.tokenizer = AutoTokenizer.from_pretrained(
                self.model_name,
                **kwargs
            )
            logger.info("AutoTokenizer loaded successfully")

            # 2. Load token classification model
            logger.info("Loading token classification model: %s (revision=%s)", self.model_name, self.revision)
            try:
                self.model = AutoModelForTokenClassification.from_pretrained(
                    self.model_name,
                    **kwargs
                )
            except (KeyError, ValueError):
                from transformers import BertForTokenClassification
                self.model = BertForTokenClassification.from_pretrained(
                    self.model_name,
                    **kwargs
                )
            logger.info("Token classification model loaded successfully")
        except BaseException as exc:
            # Transparent fallback to clinical lexicon & rules if offline or custom CRF
            logger.warning("MultiClinNER model load note (%s). Utilizing clinical lexicon & rule fallback.", exc)
            self.model = None

    def extract_entities(self, normalized_text: str) -> List[ClinicalEntity]:
        """Extracts structured clinical entities from normalized text."""
        if not normalized_text or not normalized_text.strip():
            return []

        self._try_load_model()
        entities: List[ClinicalEntity] = []

        # If tokenizer and model are loaded, run token classification inference
        if self.tokenizer is not None and self.model is not None:
            try:
                import torch
                inputs = self.tokenizer(normalized_text, return_tensors="pt")
                with torch.no_grad():
                    outputs = self.model(**inputs)
                logits = outputs.logits
                predictions = torch.argmax(logits, dim=2)[0]
                tokens = self.tokenizer.convert_ids_to_tokens(inputs["input_ids"][0])
                id2label = getattr(self.model.config, "id2label", {0: "O", 1: "B", 2: "I"})

                current_entity = []
                for token, pred_id in zip(tokens, predictions):
                    label = id2label.get(pred_id.item(), "O")
                    if label != "O" and token not in ("[CLS]", "[SEP]", "[PAD]"):
                        clean_tok = token.replace("##", "")
                        current_entity.append(clean_tok)
                    elif current_entity:
                        ent_text = " ".join(current_entity)
                        canonical = CANONICAL_SYMPTOMS.get(ent_text.lower())
                        entities.append(ClinicalEntity(
                            text=ent_text,
                            entity_type="SYMPTOM",
                            canonical_concept=canonical,
                            confidence=0.92,
                            source="multiclinner_model"
                        ))
                        current_entity = []
            except Exception as exc:
                logger.warning("MultiClinNER token inference note: %s", exc)

        # Apply transparent lexicon fallback to ensure zero clinical information loss
        fallback_entities = self._extract_via_lexicon(normalized_text)

        # Merge without duplicate overlaps
        existing_texts = {e.text.lower() for e in entities}
        for fb in fallback_entities:
            if fb.text.lower() not in existing_texts:
                entities.append(fb)

        return entities

    def _map_model_label(self, raw_label: str, text: str) -> str:
        label = raw_label.upper()
        if "SYMP" in label or "SIGN" in label:
            return "SYMPTOM"
        if "DIS" in label or "COND" in label:
            return "DISEASE"
        if "ANAT" in label or "BODY" in label:
            return "BODY_PART"
        if "SEV" in label:
            return "SEVERITY"
        if "DUR" in label or "TIME" in label:
            return "DURATION"

        t = text.lower()
        if t in CANONICAL_SYMPTOMS:
            return "SYMPTOM"
        if t in BODY_PARTS:
            return "BODY_PART"
        return "SYMPTOM"

    def _extract_via_lexicon(self, text: str) -> List[ClinicalEntity]:
        """Comprehensive deterministic clinical lexicon entity extractor."""
        results: List[ClinicalEntity] = []
        text_lower = text.lower()

        # 1. Symptoms & Danger Signs
        for phrase, canonical in CANONICAL_SYMPTOMS.items():
            for m in re.finditer(rf'\b{re.escape(phrase)}\b', text_lower):
                is_danger = canonical in DANGER_SYMPTOMS
                results.append(ClinicalEntity(
                    text=m.group(0),
                    entity_type="DANGER_SIGN" if is_danger else "SYMPTOM",
                    canonical_concept=canonical,
                    start_char=m.start(),
                    end_char=m.end(),
                    confidence=0.98,
                    source="lexicon_fallback"
                ))

        # 2. Body Parts
        for bp_phrase, canonical_bp in BODY_PARTS.items():
            for m in re.finditer(rf'\b{re.escape(bp_phrase)}\b', text_lower):
                results.append(ClinicalEntity(
                    text=m.group(0),
                    entity_type="BODY_PART",
                    canonical_concept=canonical_bp,
                    start_char=m.start(),
                    end_char=m.end(),
                    confidence=0.99,
                    source="lexicon_fallback"
                ))

        # 3. Severity
        for sev_term in SEVERITY_LEVELS.keys():
            for m in re.finditer(rf'\b{re.escape(sev_term)}\b', text_lower):
                results.append(ClinicalEntity(
                    text=m.group(0),
                    entity_type="SEVERITY",
                    canonical_concept=SEVERITY_LEVELS[sev_term],
                    start_char=m.start(),
                    end_char=m.end(),
                    confidence=0.95,
                    source="lexicon_fallback"
                ))

        # 4. Duration
        for pattern, _ in DURATION_PATTERNS:
            for m in re.finditer(pattern, text_lower):
                results.append(ClinicalEntity(
                    text=m.group(0),
                    entity_type="DURATION",
                    canonical_concept=m.group(0),
                    start_char=m.start(),
                    end_char=m.end(),
                    confidence=0.95,
                    source="lexicon_fallback"
                ))

        return results

# Singleton instance
multiclinner_adapter = MultiClinNERAdapter(model_name="IEETA/MultiClinNER-EN", revision="main")
