"""Translation Adapter Module.
Translates vernacular speech to English for clinical pipeline and translates
recommendations back to patient language.
Integrates AI4Bharat IndicTrans2 (ai4bharat/indictrans2-indic-en-1B and ai4bharat/indictrans2-en-indic-1B)
using AutoModelForSeq2SeqLM and AutoTokenizer from Hugging Face Transformers.
"""

import os
import re
import logging
import importlib.util
from typing import Optional, Dict, Any
from dotenv import load_dotenv

load_dotenv()

import torch
try:
    from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
except ImportError:
    AutoTokenizer = None
    AutoModelForSeq2SeqLM = None

try:
    from deep_translator import GoogleTranslator, MyMemoryTranslator  # type: ignore
except (ImportError, Exception):
    GoogleTranslator = None
    MyMemoryTranslator = None

try:
    from app.config import settings
    from app.services.translation_service import translation_service
except ImportError:
    from backend.app.config import settings
    from backend.app.services.translation_service import translation_service

logger = logging.getLogger("swasthyasetu.translation")

# Mapping ISO 639-1 language codes to IndicTrans2 FLORES-200 style codes
INDIC_FLORES_TAGS: Dict[str, str] = {
    "hi": "hin_Deva",
    "ta": "tam_Taml",
    "te": "tel_Telu",
    "mr": "mar_Deva",
    "bn": "ben_Beng",
    "gu": "guj_Gujr",
    "kn": "kan_Knda",
    "ml": "mal_Mlym",
    "pa": "pan_Guru",
    "ur": "urd_Arab",
    "or": "ory_Orya",
    "as": "asm_Beng",
    "en": "eng_Latn"
}

# Mapping ISO 639-1 language codes to deep_translator GoogleTranslator language codes
GOOGLE_LANG_NAMES: Dict[str, str] = {
    "hi": "hi",
    "te": "te",
    "ta": "ta",
    "mr": "mr",
    "bn": "bn",
    "kn": "kn",
    "ml": "ml",
    "gu": "gu",
    "pa": "pa",
    "ur": "ur",
    "or": "or",
    "as": "as",
    "en": "en"
}

# Mapping ISO 639-1 language codes to MyMemory FLORES-IN language tags
MYMEMORY_LANG_TAGS: Dict[str, str] = {
    "hi": "hi-IN",
    "te": "te-IN",
    "ta": "ta-IN",
    "mr": "mr-IN",
    "bn": "bn-IN",
    "kn": "kn-IN",
    "ml": "ml-IN",
    "gu": "gu-IN",
    "pa": "pa-IN",
    "ur": "ur-IN",
    "or": "or-IN",
    "as": "as-IN",
    "en": "en-US"
}

# Common fallback templates for immediate emergency instructions in native scripts
VERNACULAR_EMERGENCY_TEXTS = {
    "hi": "कृपया तुरंत आपातकालीन चिकित्सा सहायता लें या 108/112 पर एम्बुलेंस बुलाएं।",
    "ta": "தயவுசெய்து உடனடியாக அவசர மருத்துவ உதவியை நாடவும் அல்லது 108/112 ஆம்புலன்ஸை அழைக்கவும்.",
    "te": "దయచేసి వెంటనే అత్యవసర వైద్య సంరక్షణ పొందండి లేదా 108/112 అంబులెన్స్‌కు కాల్ చేయండి.",
    "mr": "कृपया त्वरित आणीबाणीच्या वैद्यकीय मदतीसाठी संपर्क साधा किंवा 108/112 रुग्णवाहिकेला कॉल करा.",
    "en": "Seek immediate emergency medical care or call 108/112 ambulance."
}

# Vernacular clinical phrase translation dictionary for robust offline / local inference
VERNACULAR_TO_ENGLISH_LEXICON = {
    # Tamil
    "நெஞ்சு வலி": "chest pain",
    "மார்பு வலி": "chest pain",
    "கடுமையான": "severe",
    "மூச்சு திணறல்": "difficulty breathing",
    "மூச்சுத்திணறல்": "difficulty breathing",
    "இரண்டு மணி": "2 hours",
    "தலைவலி": "headache",
    "காய்ச்சல்": "fever",
    "வயிற்று வலி": "abdominal pain",
    "மயக்கம்": "unconsciousness",
    "வலிப்பு": "seizure",
    "கண் வலி": "eye pain",
    "கண் சிவப்பு": "eye redness",

    # Hindi
    "सीने में दर्द": "chest pain",
    "छाती में दर्द": "chest pain",
    "तेज": "severe",
    "हल्का": "mild",
    "सांस लेने में तकलीफ": "difficulty breathing",
    "सांस फूलना": "difficulty breathing",
    "दो घंटे": "2 hours",
    "बुखार": "fever",
    "सिरदर्द": "headache",
    "सिर में दर्द": "headache",
    "पेट में दर्द": "abdominal pain",
    "पेट दर्द": "abdominal pain",
    "बेहोश": "unconscious",
    "दौरा": "seizure",
    "कोई": "no",
    "नहीं है": "is absent",
    "नहीं": "not",
    "कंटी दर्द": "eye pain",
    "आंख में दर्द": "eye pain",
    "आंखें लाल": "eye redness",

    # Telugu
    "ఛాతీ నొప్పి": "chest pain",
    "తీవ్రమైన": "severe",
    "శ్వాస ఆడకపోవడం": "difficulty breathing",
    "రెండు గంటలు": "2 hours",
    "జ్వరం": "fever",
    "తలనొప్పి": "headache",
    "కడుపు నొప్పి": "abdominal pain",
    "స్పృహ తప్పడం": "unconscious",
    "మూర్ఛ": "seizure",
    "కంటి నొప్పి": "eye pain",
    "కంటి ఎరుపు": "eye redness",

    # Marathi
    "छातीत दुखणे": "chest pain",
    "श्वास घेण्यास त्रास": "difficulty breathing",
    "ताप": "fever",
    "डोकेदुखी": "headache",
    "पोटदुखी": "abdominal pain",
    "तीव्र": "severe",
    "डोळ्याचे दुखणे": "eye pain"
}


class IndicTrans2Adapter:
    """AI4Bharat IndicTrans2 Neural Machine Translation Adapter.
    Translates any Indian language to English (indic-en-1B) and English to Indian languages (en-indic-1B)
    using AutoModelForSeq2SeqLM with trust_remote_code=True.
    Includes fail-safe fallback to OpenAI translation API and clinical lexicon.
    """

    def __init__(
        self,
        indic_to_en_model: str = "ai4bharat/indictrans2-indic-en-1B",
        en_to_indic_model: str = "ai4bharat/indictrans2-en-indic-1B",
    ):
        self.indic_to_en_model_name = indic_to_en_model
        self.en_to_indic_model_name = en_to_indic_model

        self.tokenizer_indic_to_en = None
        self.model_indic_to_en = None
        self._indic_load_attempted = False

        self.tokenizer_en_to_indic = None
        self.model_en_to_indic = None
        self._en_load_attempted = False

    def _get_load_kwargs(self) -> Dict[str, Any]:
        """Prepares kwargs for Hugging Face model loading."""
        kwargs: Dict[str, Any] = {"trust_remote_code": True}
        hf_token = os.environ.get("HF_TOKEN") or getattr(settings, "HUGGINGFACE_API_KEY", None)
        if hf_token:
            kwargs["token"] = hf_token

        # Check if accelerate is available for device_map="auto"
        if importlib.util.find_spec("accelerate") is not None:
            kwargs["device_map"] = "auto"
        elif torch.cuda.is_available():
            kwargs["device_map"] = "cuda"

        return kwargs

    def _try_load_indic_to_en(self):
        """Attempts to load IndicTrans2 (Indic to English) model."""
        if self._indic_load_attempted:
            return
        self._indic_load_attempted = True

        try:
            if AutoTokenizer is None or AutoModelForSeq2SeqLM is None:
                logger.info("Transformers is not installed; using local clinical translation fallback.")
                return
            kwargs = self._get_load_kwargs()
            token = kwargs.get("token")
            if not token:
                logger.info(
                    "HF_TOKEN not set for gated IndicTrans2 (ai4bharat/indictrans2-indic-en-1B). "
                    "Using local clinical translation engine and lexicon fallback."
                )
                self.model_indic_to_en = None
                self.tokenizer_indic_to_en = None
                return

            logger.info("Loading IndicTrans2 Indic->En model: %s", self.indic_to_en_model_name)
            self.tokenizer_indic_to_en = AutoTokenizer.from_pretrained(
                self.indic_to_en_model_name,
                trust_remote_code=True,
                token=token
            )
            self.model_indic_to_en = AutoModelForSeq2SeqLM.from_pretrained(
                self.indic_to_en_model_name,
                **kwargs
            )
            self.model_indic_to_en.eval()
            logger.info("IndicTrans2 Indic->En model loaded successfully.")
        except BaseException as exc:
            logger.warning(
                "IndicTrans2 (Indic->En) model load skipped (%s). "
                "Falling back to verified clinical lexicon and OpenAI translation.",
                exc
            )
            self.model_indic_to_en = None
            self.tokenizer_indic_to_en = None

    def _try_load_en_to_indic(self):
        """Attempts to load IndicTrans2 (English to Indic) model."""
        if self._en_load_attempted:
            return
        self._en_load_attempted = True

        try:
            if AutoTokenizer is None or AutoModelForSeq2SeqLM is None:
                logger.info("Transformers is not installed; using local clinical translation fallback.")
                return
            kwargs = self._get_load_kwargs()
            token = kwargs.get("token")
            if not token:
                logger.info(
                    "HF_TOKEN not set for gated IndicTrans2 (ai4bharat/indictrans2-en-indic-1B). "
                    "Using local clinical translation engine and templates."
                )
                self.model_en_to_indic = None
                self.tokenizer_en_to_indic = None
                return

            logger.info("Loading IndicTrans2 En->Indic model: %s", self.en_to_indic_model_name)
            self.tokenizer_en_to_indic = AutoTokenizer.from_pretrained(
                self.en_to_indic_model_name,
                trust_remote_code=True,
                token=token
            )
            self.model_en_to_indic = AutoModelForSeq2SeqLM.from_pretrained(
                self.en_to_indic_model_name,
                **kwargs
            )
            self.model_en_to_indic.eval()
            logger.info("IndicTrans2 En->Indic model loaded successfully.")
        except BaseException as exc:
            logger.warning(
                "IndicTrans2 (En->Indic) model load skipped (%s). "
                "Falling back to verified clinical emergency templates and OpenAI translation.",
                exc
            )
            self.model_en_to_indic = None
            self.tokenizer_en_to_indic = None

    def translate_indic_to_en(self, text: str, src_lang: str) -> Optional[str]:
        """Translates text from an Indian language to English using IndicTrans2 if loaded."""
        self._try_load_indic_to_en()
        if not self.model_indic_to_en or not self.tokenizer_indic_to_en:
            return None

        try:
            src_tag = INDIC_FLORES_TAGS.get(src_lang, "hin_Deva")
            tgt_tag = "eng_Latn"
            try:
                inputs = self.tokenizer_indic_to_en(
                    text,
                    src_lang=src_tag,
                    tgt_lang=tgt_tag,
                    return_tensors="pt"
                )
            except (TypeError, ValueError):
                inputs = self.tokenizer_indic_to_en(text, return_tensors="pt")

            device = next(self.model_indic_to_en.parameters()).device
            inputs = {k: v.to(device) for k, v in inputs.items()}

            gen_kwargs = {"max_length": 256, "num_beams": 4}
            if hasattr(self.tokenizer_indic_to_en, "lang_code_to_id") and tgt_tag in getattr(self.tokenizer_indic_to_en, "lang_code_to_id", {}):
                gen_kwargs["forced_bos_token_id"] = self.tokenizer_indic_to_en.lang_code_to_id[tgt_tag]

            with torch.no_grad():
                generated_tokens = self.model_indic_to_en.generate(
                    **inputs,
                    **gen_kwargs
                )
            translated = self.tokenizer_indic_to_en.batch_decode(
                generated_tokens,
                skip_special_tokens=True
            )[0]
            return translated.strip()
        except Exception as exc:
            logger.warning("IndicTrans2 translation failed (%s). Falling back.", exc)
            return None

    def translate_en_to_indic(self, text: str, tgt_lang: str) -> Optional[str]:
        """Translates text from English to an Indian language using IndicTrans2 if loaded."""
        self._try_load_en_to_indic()
        if not self.model_en_to_indic or not self.tokenizer_en_to_indic:
            return None

        try:
            src_tag = "eng_Latn"
            tgt_tag = INDIC_FLORES_TAGS.get(tgt_lang, "hin_Deva")
            try:
                inputs = self.tokenizer_en_to_indic(
                    text,
                    src_lang=src_tag,
                    tgt_lang=tgt_tag,
                    return_tensors="pt"
                )
            except (TypeError, ValueError):
                inputs = self.tokenizer_en_to_indic(text, return_tensors="pt")

            device = next(self.model_en_to_indic.parameters()).device
            inputs = {k: v.to(device) for k, v in inputs.items()}

            gen_kwargs = {"max_length": 256, "num_beams": 4}
            if hasattr(self.tokenizer_en_to_indic, "lang_code_to_id") and tgt_tag in getattr(self.tokenizer_en_to_indic, "lang_code_to_id", {}):
                gen_kwargs["forced_bos_token_id"] = self.tokenizer_en_to_indic.lang_code_to_id[tgt_tag]

            with torch.no_grad():
                generated_tokens = self.model_en_to_indic.generate(
                    **inputs,
                    **gen_kwargs
                )
            translated = self.tokenizer_en_to_indic.batch_decode(
                generated_tokens,
                skip_special_tokens=True
            )[0]
            return translated.strip()
        except Exception as exc:
            logger.warning("IndicTrans2 reverse translation failed (%s). Falling back.", exc)
            return None


# Global singleton instance of IndicTrans2 Adapter
indictrans2_adapter = IndicTrans2Adapter()


def detect_language(text: str) -> str:
    """Basic script-based language identification for Indian languages and English."""
    for ch in text:
        cp = ord(ch)
        if 0x0900 <= cp <= 0x097F:
            return "hi"  # Devanagari (Hindi/Marathi)
        if 0x0B80 <= cp <= 0x0BFF:
            return "ta"  # Tamil
        if 0x0C00 <= cp <= 0x0C7F:
            return "te"  # Telugu
    return "en"


def is_google_error_text(text: str) -> bool:
    """Detects if a translator returned an error, HTML page, or invalid string."""
    if not text:
        return True
    cleaned = text.strip()
    if cleaned in [".", "..", "...", "....", ".....", ""]:
        return True
    lower = cleaned.lower()
    error_markers = [
        "error 500", "server error", "that's an error",
        "please try again later", "that's all we know", "500.that",
        "no translation was found", "translation not found",
        "u99999"
    ]
    return any(marker in lower for marker in error_markers)


def translate_to_english(text: str, source_language: Optional[str] = None) -> str:
    """Translates patient text into English using IndicTrans2, OpenAI, GoogleTranslator, MyMemory, or clinical lexicon."""
    if not text or not text.strip():
        return ""

    text = text.strip()
    raw_lang = source_language or detect_language(text)
    lang = raw_lang.split('-')[0].split('_')[0].lower()

    # If it is pure English and has no Indic script or Romanized clinical keywords, return immediately
    has_indic_script = any(0x0900 <= ord(ch) <= 0x0D7F for ch in text)
    if lang == "en" and not has_indic_script:
        # Check if Romanized vernacular keywords exist
        lower_en = text.lower()
        has_romanized = any(k in lower_en for k in [
            "bukhar", "dard", "seene", "chhati", "saas", "saans",
            "jwaram", "noppi", "swasa", "oopiri", "vali", "nenju", "taap"
        ])
        if not has_romanized:
            return text

    # 1. IndicTrans2 Neural Machine Translation (ai4bharat/indictrans2-indic-en-1B)
    it2_result = indictrans2_adapter.translate_indic_to_en(text, src_lang=lang)
    if it2_result and not is_google_error_text(it2_result):
        return it2_result

    # 2. OpenAI translation API if configured
    try:
        if settings.OPENAI_API_KEY and settings.OPENAI_API_KEY.startswith("sk-"):
            return translation_service.translate(text, source_language=lang, target_language="en")
    except Exception as exc:
        logger.warning("Translation API error: %s", exc)

    # 3. High-Accuracy Neural Translation (GoogleTranslator with proper language name mapping)
    if GoogleTranslator is not None:
        try:
            gt_source = GOOGLE_LANG_NAMES.get(lang, 'auto')
            gt_result = GoogleTranslator(source=gt_source, target='en').translate(text)
            if gt_result and gt_result.strip() and not is_google_error_text(gt_result) and re.search(r'[a-zA-Z0-9]', gt_result):
                clean_gt = gt_result.strip()
                # Post-translation clinical terminology normalization
                clinical_synonyms = [
                    (r'\bheart\s*pain\b|\bheart\s*ache\b|\bheartache\b|\bpain\s*in\s*(my\s*)?heart\b', 'severe chest pain'),
                    (r'\bshortness\s*of\s*breath\b', 'difficulty breathing'),
                    (r'\btrouble\s*breathing\b|\bhard\s*to\s*breathe\b|\bcannot\s*breathe\b|\bnot\s*breathing\b|\bno\s*breathing\b|\bdifficulty\s*in\s*breathing\b', 'difficulty breathing'),
                    (r'\bstomach\s*pain\b|\bbelly\s*pain\b', 'abdominal pain'),
                ]
                for pat, repl in clinical_synonyms:
                    clean_gt = re.sub(pat, repl, clean_gt, flags=re.IGNORECASE)
                return clean_gt
            elif is_google_error_text(gt_result):
                logger.warning("GoogleTranslator returned server error HTML text. Falling back to MyMemory / clinical lexicon.")
        except Exception as exc:
            logger.warning("Neural GoogleTranslator fallback skipped (%s). Using MyMemory / clinical lexicon.", exc)

    # 4. Resilient Secondary Neural Translation (MyMemoryTranslator with FLORES/ISO-IN tags)
    if MyMemoryTranslator is not None:
        try:
            mm_src = MYMEMORY_LANG_TAGS.get(lang, 'hi-IN')
            mm_result = MyMemoryTranslator(source=mm_src, target='en-US').translate(text)
            if mm_result and mm_result.strip() and not is_google_error_text(mm_result) and re.search(r'[a-zA-Z0-9]', mm_result):
                clean_mm = mm_result.strip()
                clinical_synonyms = [
                    (r'\bheart\s*pain\b|\bheart\s*ache\b|\bheartache\b|\bpain\s*in\s*(my\s*)?heart\b', 'severe chest pain'),
                    (r'\bshortness\s*of\s*breath\b', 'difficulty breathing'),
                    (r'\btrouble\s*breathing\b|\bhard\s*to\s*breathe\b|\bcannot\s*breathe\b|\bnot\s*breathing\b|\bno\s*breathing\b|\bdifficulty\s*in\s*breathing\b', 'difficulty breathing'),
                    (r'\bstomach\s*pain\b|\bbelly\s*pain\b', 'abdominal pain'),
                ]
                for pat, repl in clinical_synonyms:
                    clean_mm = re.sub(pat, repl, clean_mm, flags=re.IGNORECASE)
                return clean_mm
        except Exception as exc:
            logger.warning("Neural MyMemoryTranslator fallback skipped (%s). Using clinical lexicon.", exc)

    # 5. Vernacular clinical regex patterns for grammatical infixes (e.g. "सीने में बहुत तेज दर्द")
    regex_patterns = [
        # Hindi & Devanagari
        (r'(सीने|छाती)\s*(में)?\s*.*(दर्द|पीड़ा|भारीपन|जलन)', 'severe chest pain'),
        (r'सांस\s*(लेने)?\s*(में)?\s*.*(तकलीफ|फूल|दिक्कत|परेशानी|नहीं)', 'difficulty breathing'),
        (r'(तेज|बहुत|अत्यधिक)?\s*बुखार', 'high fever'),
        (r'बुखार', 'fever'),
        (r'पेट\s*(में)?\s*.*(दर्द|पीड़ा|मरोड़)', 'abdominal pain'),
        (r'सिर\s*(में)?\s*.*(दर्द|पीड़ा)', 'headache'),
        (r'उल्टी|उल्टियां', 'vomiting'),
        (r'दस्त|पतले दस्त', 'diarrhea'),
        (r'बेहोश|बेहोशी', 'loss of consciousness'),
        (r'चक्कर', 'dizziness'),
        (r'खून\s*.*(बह|निकल|स्राव)', 'severe bleeding'),
        (r'खांसी|धुसकी', 'cough'),
        (r'पसीना|घबराहट', 'sweating'),

        # Tamil
        (r'நெஞ்சு\s*.*வலி', 'severe chest pain'),
        (r'மார்பு\s*.*வலி', 'severe chest pain'),
        (r'மூச்சு\s*.*(சிரமம்|திணறல்|விட)', 'difficulty breathing'),
        (r'(அதிக\s*)?காய்ச்சல்', 'high fever'),
        (r'தலைவலி', 'headache'),
        (r'வயிற்று\s*.*வலி', 'abdominal pain'),
        (r'வாந்தி', 'vomiting'),
        (r'இருமல்', 'cough'),
        (r'மயக்கம்', 'loss of consciousness'),
        (r'அதிக\s*இரத்தப்போக்கு', 'severe bleeding'),
        (r'கண்\s*.*வலி', 'eye pain'),
        (r'கண்\s*.*சிவப்பு', 'eye redness'),

        # Telugu
        (r'(ఛాతీ|గుండె)\s*(లో)?\s*.*(నొప్పి|పోటు)', 'severe chest pain'),
        (r'(శ్వాస|ఊపిరి)\s*.*(ఇబ్బంది|ఆడటం లేదు|కష్టం|ఆడ)', 'difficulty breathing'),
        (r'(తీవ్ర\s*)?జ్వరం', 'high fever'),
        (r'జ్వరం', 'fever'),
        (r'కడుపు\s*(లో)?\s*.*నొప్పి', 'abdominal pain'),
        (r'తల\s*.*నొప్పి', 'headache'),
        (r'వాంతులు|వాంతి', 'vomiting'),
        (r'దగ్గు', 'cough'),
        (r'స్పృహ\s*తప్పడం', 'loss of consciousness'),
        (r'రక్తస్రావం', 'severe bleeding'),
        (r'కంటి\s*.*నొప్పి', 'eye pain'),
        (r'కంటి\s*.*ఎరుపు', 'eye redness'),

        # Marathi
        (r'छातीत\s*.*(वेदना|खूप दुख|कळा|जळजळ)', 'severe chest pain'),
        (r'छातीत दुखणे', 'chest pain'),
        (r'श्वास\s*.*(घेता येत नाही|त्रास|लागत|दम)', 'difficulty breathing'),
        (r'(खूप\s*)?ताप', 'high fever'),
        (r'ताप', 'fever'),
        (r'पोटात\s*.*(दुख|कळा)', 'abdominal pain'),
        (r'पोटदुखी', 'abdominal pain'),
        (r'डोकेदुखी|डोके\s*दुख', 'headache'),
        (r'उलट्या|उलटी', 'vomiting'),
        (r'खोकला', 'cough'),
        (r'बेशुद्ध', 'loss of consciousness'),
        (r'रक्तस्त्राव', 'severe bleeding'),
        (r'डोळ्याचे\s*.*दुखणे', 'eye pain'),

        # Romanized / Phonetic Transliterations
        (r'(seene|chhati|sine|chati)\s*(me)?\s*.*(dard|pain)', 'severe chest pain'),
        (r'(saas|saans|sans|swasa|oopiri)\s*.*(taklif|problem|phool|breathe)', 'difficulty breathing'),
        (r'(tez|high)?\s*bukhar', 'high fever'),
        (r'bukhar|jwaram|taap', 'fever'),
        (r'pet\s*(me)?\s*.*(dard|pain)', 'abdominal pain'),
        (r'kadupu\s*.*noppi', 'abdominal pain'),
        (r'nenju\s*.*vali', 'severe chest pain'),
        (r'chati\s*.*noppi', 'severe chest pain'),
    ]
    translated = text
    for pattern, replacement in regex_patterns:
        if re.search(pattern, translated, flags=re.IGNORECASE):
            translated = re.sub(pattern, f" {replacement} ", translated, flags=re.IGNORECASE)

    # 6. Vernacular clinical lexicon translation (match longer compound phrases first)
    sorted_lexicon = sorted(VERNACULAR_TO_ENGLISH_LEXICON.items(), key=lambda x: len(x[0]), reverse=True)
    for phrase, english_term in sorted_lexicon:
        if phrase in translated:
            translated = translated.replace(phrase, f" {english_term} ")

    # 7. Post-process to remove remaining non-English Indic script characters so output is always clean English
    cleaned_english = re.sub(r'[\u0900-\u0D7F]+', ' ', translated)
    cleaned_english = re.sub(r'[^\w\s\.\,\-]', ' ', cleaned_english)
    cleaned_english = re.sub(r'\s+', ' ', cleaned_english).strip()

    if cleaned_english and re.search(r'[a-zA-Z0-9]', cleaned_english):
        return cleaned_english

    if translated and re.search(r'[a-zA-Z0-9]', translated):
        return re.sub(r'\s+', ' ', translated).strip()

    return text.strip()


def translate_from_english(text: str, target_language: str, is_emergency: bool = False) -> str:
    """Translates English recommendation into patient's preferred language."""
    if not text or target_language == "en":
        return text

    lang = target_language.split('-')[0].split('_')[0].lower()

    # Immediate emergency instruction in native script
    if is_emergency and lang in VERNACULAR_EMERGENCY_TEXTS:
        return VERNACULAR_EMERGENCY_TEXTS[lang]

    # 1. IndicTrans2 Neural Machine Translation (ai4bharat/indictrans2-en-indic-1B)
    it2_result = indictrans2_adapter.translate_en_to_indic(text, tgt_lang=lang)
    if it2_result and not is_google_error_text(it2_result):
        return it2_result

    # 2. OpenAI translation API if configured
    try:
        if settings.OPENAI_API_KEY and settings.OPENAI_API_KEY.startswith("sk-"):
            return translation_service.translate(text, source_language="en", target_language=lang)
    except Exception as exc:
        logger.warning("Reverse translation API error: %s", exc)

    # 3. High-Accuracy Neural Translation (GoogleTranslator with proper target language code)
    if GoogleTranslator is not None:
        try:
            gt_target = GOOGLE_LANG_NAMES.get(lang, lang)
            gt_result = GoogleTranslator(source='en', target=gt_target).translate(text)
            if gt_result and gt_result.strip() and not is_google_error_text(gt_result):
                return gt_result.strip()
            elif is_google_error_text(gt_result):
                logger.warning("Reverse GoogleTranslator returned server error HTML text.")
        except Exception as exc:
            logger.warning("Reverse GoogleTranslator fallback skipped (%s). Trying MyMemory.", exc)

    # 4. Secondary Neural Translation (MyMemoryTranslator)
    if MyMemoryTranslator is not None:
        try:
            mm_target = MYMEMORY_LANG_TAGS.get(lang, f"{lang}-IN")
            mm_result = MyMemoryTranslator(source='en-US', target=mm_target).translate(text)
            if mm_result and mm_result.strip() and not is_google_error_text(mm_result):
                return mm_result.strip()
        except Exception as exc:
            logger.warning("Reverse MyMemoryTranslator fallback skipped (%s).", exc)

    # 5. Vernacular Lexicon Fallback for Clinical Action Recommendations
    ENGLISH_TO_VERNACULAR_RECOMMENDATIONS = {
        "te": {
            "Urgent medical evaluation is recommended today.": "ఈరోజు అత్యవసర వైద్య మూల్యాంకనం సిఫార్సు చేయబడింది.",
            "Routine consultation is appropriate based on the current information.": "ప్రస్తుత సమాచారం ఆధారంగా సాధారణ సంప్రదింపులు తగినవి.",
            "Medical evaluation is recommended.": "వైద్య మూల్యాంకనం సిఫార్సు చేయబడింది.",
            "CRITICAL RED FLAG: Seek immediate emergency medical care or call 108/112.": "దయచేసి వెంటనే అత్యవసర వైద్య సంరక్షణ పొందండి లేదా 108/112 అంబులెన్స్‌కు కాల్ చేయండి."
        },
        "hi": {
            "Urgent medical evaluation is recommended today.": "आज ही तत्काल चिकित्सा मूल्यांकन की सिफारिश की जाती है।",
            "Routine consultation is appropriate based on the current information.": "वर्तमान जानकारी के आधार पर सामान्य परामर्श उपयुक्त है।",
            "Medical evaluation is recommended.": "चिकित्सा मूल्यांकन की सिफारिश की जाती है।",
            "CRITICAL RED FLAG: Seek immediate emergency medical care or call 108/112.": "कृपया तुरंत आपातकालीन चिकित्सा सहायता लें या 108/112 पर एम्बुलेंस बुलाएं।"
        },
        "ta": {
            "Urgent medical evaluation is recommended today.": "இன்று அவசர மருத்துவ பரிசோதனை பரிந்துரைக்கப்படுகிறது.",
            "Routine consultation is appropriate based on the current information.": "தற்போதைய தகவல்களின் அடிப்படையில் வழக்கமான ஆலோசனையே போதுமானது.",
            "Medical evaluation is recommended.": "மருத்துவ பரிசோதனை பரிந்துரைக்கப்படுகிறது.",
            "CRITICAL RED FLAG: Seek immediate emergency medical care or call 108/112.": "தயவுசெய்து உடனடியாக அவசர மருத்துவ உதவியை நாடவும் அல்லது 108/112 ஆம்புலன்ஸை அழைக்கவும்."
        },
        "mr": {
            "Urgent medical evaluation is recommended today.": "आजच तातडीने वैद्यकीय तपासणी करण्याचा सल्ला दिला जातो.",
            "Routine consultation is appropriate based on the current information.": "सध्याच्या माहितीच्या आधारे सामान्य सल्लामसलत योग्य आहे.",
            "Medical evaluation is recommended.": "वैद्यकीय तपासणीचा सल्ला दिला जातो.",
            "CRITICAL RED FLAG: Seek immediate emergency medical care or call 108/112.": "कृपया त्वरित आणीबाणीच्या वैद्यकीय मदतीसाठी संपर्क साधा किंवा 108/112 रुग्णवाहिकेला कॉल करा."
        }
    }

    if lang in ENGLISH_TO_VERNACULAR_RECOMMENDATIONS and text in ENGLISH_TO_VERNACULAR_RECOMMENDATIONS[lang]:
        return ENGLISH_TO_VERNACULAR_RECOMMENDATIONS[lang][text]

    return text

