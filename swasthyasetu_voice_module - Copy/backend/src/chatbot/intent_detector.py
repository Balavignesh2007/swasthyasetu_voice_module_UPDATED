"""Intent detector for SwasthyaSetu Chatbot.

Classifies incoming patient messages into clinical and conversational intents:
- EMERGENCY: Immediate life-threatening red flags (chest pain, severe breathlessness, unconsciousness, snakebite)
- SYMPTOM_REPORT: Patient describing ongoing symptoms needing clinical triage
- APPOINTMENT_REQUEST: Patient wanting to book, view, or reschedule doctor appointments
- HEALTH_FAQ: Health education, maternal care, immunization, prevention, schemes
- GREETING: Conversational greetings, politeness, closings
- UNKNOWN: Fallback
"""

from enum import Enum
import re
from typing import Tuple, Dict, Any, Optional


class ChatIntent(str, Enum):
    EMERGENCY = "EMERGENCY"
    SYMPTOM_REPORT = "SYMPTOM_REPORT"
    APPOINTMENT_REQUEST = "APPOINTMENT_REQUEST"
    HEALTH_FAQ = "HEALTH_FAQ"
    GREETING = "GREETING"
    UNKNOWN = "UNKNOWN"


class IntentDetector:
    def __init__(self):
        # High-priority red-flag emergency keywords & phrases (multilingual)
        self.emergency_patterns = [
            r"\b(chest pain|heart attack|angina|cardiac)\b",
            r"\b(can'?t breathe|cannot breathe|difficulty breathing|breathless|gasping|suffocating)\b",
            r"\b(unconscious|passed out|fainted|loss of consciousness|not responding|blackout)\b",
            r"\b(seizure|convulsion|epilepsy|fits)\b",
            r"\b(coughing up blood|vomiting blood|blood in stool|severe bleeding|hemorrhage)\b",
            r"\b(snakebite|snake bite|poisoning|swallowed poison|consumed pesticide)\b",
            r"\b(stroke|paralysis|slurred speech|face droop)\b",
            r"\b(severe burn|deep burn|burn shock)\b",
            # Hindi
            r"(सीने में.*दर्द|छाती में.*दर्द|सांस.*फूल|सांस.*तकलीफ|सांस.*नहीं|दिल का दौरा|बेहोश|दौरा|खून की उल्टी|सांप ने काटा|जहर)",
            # Telugu
            r"(గుండె.*నొప్పి|ఛాతీ.*నొప్పి|శ్వాస.*ఆడ|స్పృహ తప్పి|రక్తం కక్కు|పాము కాటు)",
            # Tamil
            r"(நெஞ்சு.*வலி|மூச்சு.*விட|மயக்கம்|ரத்தம் வாந்தி|பாம்பு கடி)"
        ]

        # Symptoms patterns indicating clinical triage
        self.symptom_patterns = [
            r"\b(fever|chills|shivering|temperature|pyrexia)\b",
            r"\b(cough|cold|sore throat|congestion|runny nose|sneezing)\b",
            r"\b(headache|migraine|body ache|joint pain|back pain|stomach pain|abdominal pain)\b",
            r"\b(vomiting|nausea|loose motion|diarrhea|dehydration|constipation)\b",
            r"\b(rash|itching|swelling|allergy|skin infection|wound|ulcer)\b",
            r"\b(dizziness|weakness|fatigue|tiredness|pale|loss of appetite)\b",
            r"\b(i have|i feel|suffering from|since yesterday|pain in|hurts|ache)\b",
            # Hindi symptoms
            r"(बुखार|खांसी|जुकाम|सिरदर्द|पेट दर्द|उल्टी|दस्त|कमजोरी|दर्द|चक्कर)",
            # Telugu symptoms
            r"(జ్వరం|దగ్గు|జలుబు|తలనొప్పి|కడుపు నొప్పి|వాంతులు|విరేచనాలు|నీరసం)",
            # Tamil symptoms
            r"(காய்ச்சல்|இருமல்|தலைவலி|வயிற்று வலி|வாந்தி|வயிற்றுப்போக்கு)"
        ]

        # Appointment patterns
        self.appointment_patterns = [
            r"\b(appointment|book doctor|consult doctor|see a doctor|schedule visit|booking)\b",
            r"\b(meet doctor|doctor timing|opd|phc visit|hospital timing|reschedule|cancel appointment)\b",
            r"\b(doctor appointment|want to consult|need a doctor|book token)\b",
            r"(अपॉइंटमेंट|डॉक्टर से मिलना|डॉक्टर को दिखाना|बुकिंग|तारीख)",
            r"(అపాయింట్‌మెంట్|డాక్టర్‌ని కలవాలి|బుకింగ్)",
            r"(மருத்துவர் சந்திப்பு|முன்பதிவு)"
        ]

        # Greeting patterns
        self.greeting_patterns = [
            r"\b(hi|hello|hey|greetings|namaste|vanakkam|namaskaram|good morning|good afternoon|good evening|pranam)\b",
            r"\b(thanks|thank you|dhanyawad|shukriya|nandri|dhanyavadalu|welcome)\b",
            r"\b(bye|goodbye|see you|alvida)\b",
            r"(नमस्ते|नमस्कार|प्रणाम|வணக்கம்|నమస్కారం)"
        ]

        # Health FAQ / Education patterns
        self.faq_patterns = [
            r"\b(what is|how to|why is|how many|when should|is it safe|can i eat|guidelines|prevent)\b",
            r"\b(pregnant|pregnancy|anc|breastfeeding|colostrum|infant|baby food|vaccine|immunization|polio|bcg)\b",
            r"\b(nutrition|diet|iron tablet|folic acid|ifa|clean water|chlorine|ors|zinc)\b",
            r"\b(asha|jsy|janani suraksha|ayushman bharat|pmjay|sub centre|phc|vhsnd)\b",
            r"\b(diabetes|hypertension|blood pressure|tb|tuberculosis|malaria|dengue|typhoid)\b",
            r"(गर्भावस्था|स्तनपान|टीकाकरण|टीका|आशा|आयुष्मान|पानी उबालकर|ओआरएस)"
        ]

    def detect(self, text: str, language: Optional[str] = None) -> Tuple[ChatIntent, Dict[str, Any]]:
        """Classify message into ChatIntent with metadata dictionary."""
        intent, conf = self.detect_intent(text)
        is_emergency = (intent == ChatIntent.EMERGENCY)
        meta = {
            "intent": intent.value,
            "confidence": round(conf, 2),
            "is_emergency": is_emergency,
            "language": language or "en"
        }
        return intent, meta

    def detect_intent(self, text: str) -> Tuple[ChatIntent, float]:
        """Classify message into ChatIntent with confidence score (0.0 to 1.0)."""
        if not text or not text.strip():
            return ChatIntent.UNKNOWN, 0.0

        cleaned = text.strip().lower()

        # 1. Critical Emergencies (Highest safety priority)
        for pattern in self.emergency_patterns:
            if re.search(pattern, cleaned, re.IGNORECASE):
                return ChatIntent.EMERGENCY, 0.98

        # 2. Symptoms Report (Physical complaints)
        symptom_matches = 0
        for pattern in self.symptom_patterns:
            if re.search(pattern, cleaned, re.IGNORECASE):
                symptom_matches += 1

        if symptom_matches >= 1:
            confidence = min(0.65 + (symptom_matches * 0.1), 0.95)
            return ChatIntent.SYMPTOM_REPORT, confidence

        # 3. Appointment Requests
        for pattern in self.appointment_patterns:
            if re.search(pattern, cleaned, re.IGNORECASE):
                return ChatIntent.APPOINTMENT_REQUEST, 0.90

        # 4. Greetings (only if no symptoms or appointments mentioned)
        for pattern in self.greeting_patterns:
            if re.search(pattern, cleaned, re.IGNORECASE):
                return ChatIntent.GREETING, 0.95

        # 5. Health FAQ / Educational queries
        faq_matches = 0
        for pattern in self.faq_patterns:
            if re.search(pattern, cleaned, re.IGNORECASE):
                faq_matches += 1

        if faq_matches >= 1 or "?" in text:
            confidence = min(0.60 + (faq_matches * 0.12), 0.92)
            return ChatIntent.HEALTH_FAQ, confidence

        return ChatIntent.UNKNOWN, 0.40


intent_detector = IntentDetector()
