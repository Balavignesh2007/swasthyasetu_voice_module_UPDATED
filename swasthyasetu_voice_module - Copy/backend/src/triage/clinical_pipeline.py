"""Shared Clinical Voice Pipeline.

Executes the complete clinical pipeline:
Speech / Text -> Multilingual Translation -> Clinical Normalization ->
MultiClinNER Entity Extraction -> Feature Engineering ->
XGBoost Triage Model -> Emergency Red-Flag Screening -> Care Recommendation.
"""

from typing import Optional, Dict, Any
from fastapi import HTTPException
from app.services.emergency_service import emergency_safety_service
from src.normalization.normalizer import clinical_normalizer
from src.nlp.multiclinner_adapter import multiclinner_adapter
from src.translation.translation_adapter import detect_language, translate_to_english
from src.triage.feature_builder import build_clinical_features
from src.triage.prediction import triage_engine


CLINICAL_TRANSLATION_LEXICON = {
    'सीने में बहुत तेज़ दर्द है और सांस लेने में तकलीफ हो रही है': 'severe chest pain and difficulty breathing',
    'सीने में बहुत तेज़ दर्द है': 'severe chest pain',
    'सीने में बहुत तेज दर्द है': 'severe chest pain',
    'सीने में बहुत तेज़ दर्द': 'severe chest pain',
    'सीने में बहुत तेज दर्द': 'severe chest pain',
    'सीने में तेज दर्द': 'severe chest pain',
    'सीने में दर्द': 'severe chest pain',
    'छाती में दर्द': 'severe chest pain',
    'सांस लेने में तकलीफ': 'difficulty breathing',
    'सांस फूलना': 'difficulty breathing',
    'सांस फूल रही है': 'difficulty breathing',
    'हॉट पेन': 'severe heart chest pain',
    'हार्ट पेन': 'severe heart chest pain',
    'चेस्ट पेन': 'severe chest pain',
    'हार्ट अटैक': 'heart attack emergency',
    'डिफिकल्ट टू ब्रीदिंग': 'severe difficulty breathing',
    'ब्रीदिंग प्रॉब्लम': 'difficulty breathing',
    'सिरदर्द': 'headache',
    'हल्का': 'mild',
    'खांसी': 'cough',
    'हॉट': 'heart',
    'पेन': 'pain',
    'ब्रीदिंग': 'breathing',
    'నాకు గుండెల్లో నొప్పిగా ఉంది': 'severe chest pain',
    'గుండెల్లో నొప్పిగా ఉంది': 'severe chest pain',
    'గుండెల్లో నొప్పి': 'severe chest pain',
    'గుండె నొప్పి': 'severe chest pain',
    'గుండెనొప్పి': 'severe chest pain',
    'గుండెల్లో మంట': 'severe burning chest pain',
    'ఛాతీలో నొప్పి': 'severe chest pain',
    'ఛాతీ నొప్పి': 'severe chest pain',
    'శ్వాస ఆడటం లేదు': 'severe difficulty breathing',
    'శ్వాస ఆడకపోవడం': 'difficulty breathing',
    'ఆయాసంగా ఉంది': 'severe difficulty breathing',
    'ఆయాసం': 'difficulty breathing',
    'నెஞ்சு வலி': 'chest pain',
    'மூச்சு விடுவதில் சிரமம்': 'difficulty breathing',
    'மூச்சு திணறல்': 'difficulty breathing'
}


def _translate_local(text: str, lang: str) -> str:
    try:
        return translate_to_english(text, source_language=lang)
    except Exception:
        return text


def run_voice_clinical_pipeline(raw: str, requested_language: Optional[str] = None) -> Dict[str, Any]:
    """Execute the end-to-end clinical AI triage pipeline."""
    raw = (raw or '').strip()
    if not raw:
        raise HTTPException(400, 'Voice transcript is empty')

    # 1) Language detection
    lang = requested_language or detect_language(raw)

    # 2) Translation to English with rural dialect lexicon
    english = _translate_local(raw, lang)
    for source, target in sorted(CLINICAL_TRANSLATION_LEXICON.items(), key=lambda x: -len(x[0])):
        english = english.replace(source, target)

    # 3) Clinical normalization
    record = clinical_normalizer.normalize(english)

    # 4) MultiClinNER entity extraction
    entities = multiclinner_adapter.extract_entities(record.normalized_text)

    # 5) Structured clinical features for XGBoost
    features = build_clinical_features(record, entities)

    # 6) XGBoost triage prediction with danger-sign safety override
    decision = triage_engine.evaluate(features, normalized_text=record.normalized_text)
    screen = emergency_safety_service.screen([s.replace('_', ' ') for s in record.canonical_symptoms])

    triage = triage_engine.public_level(decision.triage_level)
    if screen.is_emergency or triage == 'EMERGENCY' or decision.triage_level == 'EMERGENCY':
        triage = 'EMERGENCY'
        action = 'CRITICAL RED FLAG: Seek immediate emergency medical care or call 108/112.'
        emergency = {
            'is_emergency': True,
            'red_flag_type': screen.red_flag_type or 'Acute Clinical Emergency',
            'matched_symptom': screen.matched_symptom or 'Critical Symptoms'
        }
    else:
        action = {
            'URGENT': 'Urgent medical evaluation is recommended today.',
            'ROUTINE': 'Routine consultation is appropriate based on the current information.'
        }.get(triage, 'Medical evaluation is recommended.')
        emergency = {
            'is_emergency': False,
            'red_flag_type': None,
            'matched_symptom': None
        }

    return {
        'raw_transcript': raw,
        'detected_language': lang,
        'translation': {'source_language': lang, 'target_language': 'en', 'text': english},
        'translated_text': english,
        'normalization': {'text': record.normalized_text, 'canonical_symptoms': record.canonical_symptoms},
        'normalized_text': record.normalized_text,
        'multiclinner': {'model': 'IEETA/MultiClinNER-EN', 'entities': [e.to_dict() for e in entities]},
        'extracted_entities': [e.to_dict() for e in entities],
        'clinical_features': features,
        'standardized_symptoms': record.canonical_symptoms,
        'xgboost': {
            'model': 'XGBoost',
            'internal_prediction': decision.triage_level,
            'confidence': decision.confidence,
            'class_probabilities': decision.class_probabilities,
            'decision_source': decision.decision_source
        },
        'emergency': emergency,
        'triage_level': triage,
        'severity': 'urgent' if triage == 'EMERGENCY' else ('review' if triage == 'URGENT' else 'routine'),
        'triage_probability': decision.confidence,
        'suggested_action': action,
        'disclaimer': 'AI-assisted suggestion only — does not diagnose. Confirmed by a licensed clinician.',
        'safety_principle': 'This is a healthcare decision-support platform, NOT an AI doctor. AI performs triage/urgency assistance only. Never claim or display a disease diagnosis.',
        'pipeline': ['Speech-to-Text', 'Translation to English', 'Clinical Normalization', 'MultiClinNER', 'XGBoost', 'Triage', 'Recommendation / Referral']
    }


# Backwards compatibility alias for existing code
_run_voice_clinical_pipeline = run_voice_clinical_pipeline
