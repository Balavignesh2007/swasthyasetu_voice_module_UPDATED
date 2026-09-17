# MultiClinNER Integration

`app/services/clinical_nlp_service.py` is the integration point for clinical
entity extraction. It ships with two layers:

1. **Model path** — loads a HuggingFace `token-classification` pipeline from
   `MULTICLINNER_MODEL_NAME`. Replace this constant with your organization's
   validated multilingual clinical NER checkpoint once available (e.g. a
   fine-tuned XLM-R or IndicBERT model trained on annotated symptom mentions
   in English/Hindi/Telugu/Tamil transcripts).
2. **Lexicon fallback** — a small, auditable synonym table
   (`app/services/normalization_service.py`) plus a term-matcher. This keeps
   the pipeline functional and safe even before a trained NER model exists,
   and guarantees the system degrades to "match known standardized terms"
   rather than silently returning nothing.

## Recommended path to a real MultiClinNER model

1. Collect and clinically annotate transcript data (with consent/appropriate
   legal basis) tagging SYMPTOM / CONDITION / BODY_PART / NEGATION spans.
2. Fine-tune a multilingual token-classification model (start from an
   IndicBERT/XLM-R base) on the annotated corpus.
3. Push the model to your private HuggingFace Hub / internal model registry.
4. Set `MULTICLINNER_MODEL_NAME` to that checkpoint path.
5. Have qualified clinical staff review a sample of extraction outputs before
   enabling the model path in production (set an environment flag /
   feature flag to gate rollout).
6. Keep the lexicon fallback active as a safety net for extraction failures
   or extremely low-confidence model outputs.

## Negation handling

Clinical NER needs to detect negation ("no chest pain", "denies fever") to
avoid false positives feeding the emergency red-flag layer. The current
lexicon fallback does NOT handle negation — this is a known gap that must be
closed with the real model (via a NEGATION entity label, or a
negation-detection library) before production emergency screening is fully
trusted to run unattended in high volumes. Until then, treat the human
escalation path (spec section 36) as the safety valve for ambiguous cases.
