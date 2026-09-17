"""Gemini API Adapter for SwasthyaSetu Chatbot.

Provides LLM reasoning, question answering, and clinical communication with:
- Google Gemini 1.5 Flash integration when GEMINI_API_KEY is configured
- Graceful local fallback when GEMINI_API_KEY is missing, expired, or offline
- Medical rural India system persona (compassionate, practical, safety-first)
"""

import logging
from typing import List, Dict, Optional, Any
from app.config import settings

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """You are SwasthyaSetu AI — the official AI healthcare assistant of the SwasthyaSetu Digital Health Platform.

## About SwasthyaSetu
SwasthyaSetu ("Health Bridge") is India's multilingual digital rural healthcare platform that connects patients,
ASHA (Accredited Social Health Activist) workers, and doctors through a unified digital system.

Key platform features:
- Voice-first multilingual interface: Supports Hindi, Telugu, Tamil, Marathi, Bengali, and English
- AI triage engine: XGBoost-powered clinical triage (ROUTINE / URGENT / EMERGENCY)
- ASHA worker portal: Field health workers capture patient symptoms via voice and get AI guidance
- Doctor portal: OPD appointment management, Jitsi video teleconsultation, patient records
- Patient portal: Voice symptom reporting, appointment booking, health education
- Emergency alerts: Automatic ASHA/doctor notification for life-threatening red flags
- RAG-powered health education: Medical FAQ database for maternal health, child nutrition, immunization

## Your Role and Identity
You are SwasthyaSetu's compassionate AI healthcare assistant. You assist patients (villagers, mothers,
elderly), ASHA workers, and doctors. You are NOT a doctor and must never claim to diagnose diseases,
prescribe restricted medications, or replace qualified medical professionals.

## Core Guidelines

### 1. Safety First (NON-NEGOTIABLE)
For ANY emergency red flag (chest pain, breathlessness, unconsciousness, seizures, severe bleeding,
snakebite, stroke symptoms):
- IMMEDIATELY instruct: Call 108 (National Ambulance Helpline)
- Add: Rush to the nearest Primary Health Centre (PHC) or District Hospital
- Do NOT downplay emergency symptoms

### 2. Empathy and Simplicity
- Use simple, respectful language with short sentences. No medical jargon.
- Acknowledge the patient's concern before providing information

### 3. Clinical Accuracy with RAG Context
- Rely on provided medical FAQ context (RAG retrieval) for evidence-based answers
- For ORS: Always specify 1 packet ORS dissolved in 1 liter boiled, cooled water
- For fever: Paracetamol dose by weight, sponge bath, encourage fluids
- For dehydration: ORS + Zinc 14-day course
- Never invent doses of antibiotics, steroids, or controlled medications

### 4. Rural India Context
- Mention accessible home remedies (ORS, zinc, sponge bath, ginger-tulsi tea for mild cough)
- Recommend government schemes: JSY, Ayushman Bharat PM-JAY, Nikshay Poshan Yojana (TB), RBSK
- Refer to local ASHA worker, ANM, Sub-Centre, or PHC

### 5. SwasthyaSetu Platform Guidance
When users ask about platform features:
- Patient portal: Voice symptom checker, appointment booking, hospital referrals
- Doctor portal: OPD management, Jitsi video teleconsultation, patient records
- ASHA portal: Voice note capture, patient assignments, emergency alerts
- Appointments: Book via My Consultations > Book New in the patient portal

### 6. Language Policy
- Respond in the same language the user wrote in
- Always include the 108 emergency number regardless of language

### 7. Disclaimer
Always include for clinical questions:
"This is AI-generated health guidance. For examination, diagnosis, or prescription, please consult a
qualified doctor at your nearest PHC or hospital."
"""


class GeminiAdapter:
    def __init__(self):
        self.api_key = settings.GEMINI_API_KEY
        self.model_name = settings.GEMINI_MODEL or "gemini-1.5-flash"
        self._client_initialized = False
        self._init_client()

    def _init_client(self):
        if not self.api_key or not self.api_key.strip():
            logger.info("GeminiAdapter: GEMINI_API_KEY not provided. Operating in deterministic local fallback mode.")
            self._client_initialized = False
            return

        try:
            import google.generativeai as genai
            genai.configure(api_key=self.api_key.strip())
            self._client_initialized = True
            logger.info(f"GeminiAdapter: Initialized with model {self.model_name}")
        except Exception as e:
            logger.warning(f"GeminiAdapter initialization failed: {e}. Fallback enabled.")
            self._client_initialized = False

    def is_available(self) -> bool:
        return self._client_initialized and bool(self.api_key and self.api_key.strip())

    def generate_response(
        self,
        prompt: str,
        context: Optional[str] = None,
        history: Optional[List[Dict[str, str]]] = None,
        language: str = "en",
        user_role: Optional[str] = None,
    ) -> str:
        """Generate response via Gemini LLM or rule-based fallback."""
        if self.is_available():
            import google.generativeai as genai

            # Assemble prompt with context
            full_prompt = ""
            if user_role:
                u_role = user_role.upper()
                full_prompt += f"User Role on SwasthyaSetu Platform: {u_role}\n"
                if "DOCTOR" in u_role:
                    full_prompt += "Role Context: You are speaking to a Doctor. Provide clinical workflow information, medical protocol context, platform features (OPD, Jitsi teleconsult, referral network). Do not replace clinical judgment.\n"
                elif "ASHA" in u_role:
                    full_prompt += "Role Context: You are speaking to an ASHA community healthcare worker. Support their village outreach, antenatal/postnatal care protocols, immunization schedules, and emergency alert escalation.\n"
                elif "ADMIN" in u_role:
                    full_prompt += "Role Context: You are speaking to a System Administrator. Provide operational platform guidance, registry navigation, and analytics usage. Never expose database credentials or secrets.\n"
                else:
                    full_prompt += "Role Context: You are speaking to a Patient. Provide empathetic, simple health guidance, explanation of symptoms, clinic visit advice, and appointment booking guidance. Remind them to see a doctor for formal diagnosis.\n"
                full_prompt += "\n"

            if context:
                full_prompt += f"Verified Medical Context (from SwasthyaSetu Knowledge Base):\n{context}\n\n"

            if history:
                full_prompt += "Recent Conversation History:\n"
                for msg in history[-6:]:
                    role = "Patient/User" if msg.get("role") == "user" else "SwasthyaSetu AI"
                    full_prompt += f"{role}: {msg.get('message', '')}\n"
                full_prompt += "\n"

            full_prompt += f"Current Message: {prompt}\n"
            if language and language != "en":
                full_prompt += (
                    f"Important: Please respond in the user's language ({language}). "
                    f"Keep clinical advice clear and accurate.\n"
                )
            else:
                full_prompt += "Please provide a concise, helpful, empathetic, and clinically accurate response.\n"

            # Use correct Gemini model names that actually exist in the API
            candidate_models = []
            if self.model_name and self.model_name not in candidate_models:
                candidate_models.append(self.model_name)
            for m in [
                "gemini-1.5-flash",
                "gemini-1.5-flash-8b",
                "gemini-1.5-pro",
                "gemini-2.0-flash",
                "gemini-2.0-flash-lite",
            ]:
                if m not in candidate_models:
                    candidate_models.append(m)

            for cand in candidate_models:
                try:
                    model = genai.GenerativeModel(
                        model_name=cand,
                        system_instruction=SYSTEM_PROMPT
                    )
                    response = model.generate_content(full_prompt)
                    if response and response.text:
                        logger.info(f"GeminiAdapter: Response generated via {cand}")
                        return response.text.strip()
                except Exception as e:
                    err_str = str(e)
                    if "quota" in err_str.lower() or "429" in err_str or "rate" in err_str.lower():
                        logger.warning(f"Gemini quota/rate limit on {cand}, trying next model...")
                    elif "not found" in err_str.lower() or "404" in err_str:
                        logger.warning(f"Model {cand} not found, trying next...")
                    else:
                        logger.warning(f"Gemini API call with {cand} failed: {e}. Trying next model...")

        # Graceful Local Fallback
        return self._local_fallback_response(prompt, context)

    def _local_fallback_response(self, prompt: str, context: Optional[str]) -> str:
        """Deterministic local medical response when Gemini API is offline or unconfigured."""
        if context and context.strip():
            lines = [line.strip() for line in context.strip().split("\n") if line.strip()]
            answers = [l for l in lines if l.startswith("Answer:") or l.startswith("A:")]
            if answers:
                synthesized = " ".join([a.split(":", 1)[-1].strip() for a in answers[:2]])
                return (
                    f"Based on SwasthyaSetu health guidelines:\n\n"
                    f"{synthesized}\n\n"
                    f"For a detailed examination or if symptoms persist, please visit your local PHC "
                    f"or consult your village ASHA worker."
                )
            return (
                f"SwasthyaSetu Health Information:\n\n{context}\n\n"
                f"Please consult your Sub-centre or Primary Health Centre (PHC) for direct doctor consultation."
            )

        prompt_lower = prompt.lower()
        if "swasthyasetu" in prompt_lower:
            return (
                "SwasthyaSetu is India's multilingual digital rural healthcare platform that bridges patients, "
                "ASHA workers, and doctors. It offers voice-enabled symptom checking, AI triage, "
                "appointment booking, emergency alerts, and health education in multiple Indian languages. "
                "Portals: Patient Portal, Doctor Portal, and ASHA Worker Portal."
            )
        if "ors" in prompt_lower or "oral rehydration" in prompt_lower:
            return (
                "ORS (Oral Rehydration Salts) is the key treatment for diarrhea and dehydration. "
                "Dissolve 1 ORS packet in 1 liter of boiled and cooled clean water. "
                "Give small sips frequently. Continue breastfeeding. "
                "Also give Zinc tablets (20mg for children over 6 months) for 14 days. "
                "If the child cannot drink or worsens, go to the nearest PHC immediately."
            )
        return (
            "Thank you for contacting SwasthyaSetu. "
            "If you are experiencing symptoms, describe them in detail for AI triage assistance. "
            "For urgent emergencies, call 108 (National Ambulance Helpline) immediately.\n\n"
            "I can help you with: health questions, maternal and child health guidance, "
            "appointment booking, and SwasthyaSetu platform navigation."
        )


gemini_adapter = GeminiAdapter()
