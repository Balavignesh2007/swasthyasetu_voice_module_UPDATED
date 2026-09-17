"""Multilingual AI Chatbot API Router for SwasthyaSetu.

Implements the complete Chatbot architecture:
Text / Voice / Multilingual Input
  -> Intent Detection (Emergency, Symptom Report, Health FAQ, Appointment, Greeting)
  -> Emergency Detection & Red-Flag Safety Rules
  -> Clinical Symptom Extraction & XGBoost Triage (for Symptom Reports)
  -> RAG Context Retrieval over Medical FAQs + Gemini LLM Reasoning
  -> Multilingual Translation (Hindi, Telugu, Tamil, Marathi, English)
  -> Chat Session History persistence (ChatMessage table)
"""

import json
import logging
import uuid
from typing import Optional, List, Dict, Any

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.models import ChatMessage, Patient, EmergencyEvent, Appointment
from src.chatbot.intent_detector import intent_detector, ChatIntent
from src.chatbot.rag_engine import rag_engine
from src.chatbot.gemini_adapter import gemini_adapter
from src.clinical_pipeline import run_voice_clinical_pipeline
from src.translation.translation_adapter import detect_language, translate_to_english, translate_from_english
from src.speech.speech_adapter import transcribe_audio_bytes

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/chatbot", tags=["AI Health Chatbot"])


class ChatMessageRequest(BaseModel):
    message: str = Field(..., min_length=1, description="Text message from user")
    session_id: Optional[str] = Field(None, description="Client session UUID")
    patient_id: Optional[str] = Field(None, description="Optional registered patient ID")
    language: Optional[str] = Field(None, description="ISO language code (e.g., 'hi', 'te', 'ta', 'en')")
    role: Optional[str] = Field(None, description="Role: PATIENT, DOCTOR, ASHA_WORKER, ADMIN")


def _get_or_create_session_id(session_id: Optional[str]) -> str:
    return session_id.strip() if session_id and session_id.strip() else str(uuid.uuid4())


def _get_recent_history(session_id: str, db: Session, limit: int = 6) -> List[Dict[str, str]]:
    msgs = db.query(ChatMessage).filter(ChatMessage.session_id == session_id).order_by(ChatMessage.created_at.asc()).limit(limit).all()
    return [{"role": m.role, "message": m.message} for m in msgs]


def _save_message(
    db: Session,
    session_id: str,
    role: str,
    message: str,
    intent: Optional[str] = None,
    language: str = "en",
    is_emergency: bool = False,
    patient_id: Optional[str] = None
) -> ChatMessage:
    msg = ChatMessage(
        session_id=session_id,
        patient_id=patient_id,
        role=role,
        message=message,
        intent=intent,
        language=language,
        is_emergency=is_emergency
    )
    db.add(msg)
    db.commit()
    db.refresh(msg)
    return msg


@router.post("/message")
def chat_message(req: ChatMessageRequest, db: Session = Depends(get_db)):
    """Primary chat endpoint. Handles intent classification, safety overrides, RAG, and LLM synthesis."""
    raw_message = req.message.strip()
    session_id = _get_or_create_session_id(req.session_id)

    # 1. Language Detection
    detected_lang = req.language or detect_language(raw_message)

    # 2. Intent Detection
    intent, intent_info = intent_detector.detect(raw_message, language=detected_lang)

    # Save user message to history
    _save_message(
        db=db,
        session_id=session_id,
        role="user",
        message=raw_message,
        intent=intent.value,
        language=detected_lang,
        patient_id=req.patient_id
    )

    history = _get_recent_history(session_id, db)
    is_emergency = False
    clinical_data = None
    retrieved_faq = []
    final_response = ""

    # 3. Process according to intent
    if intent == ChatIntent.EMERGENCY:
        is_emergency = True
        matched_term = intent_info.get("matched", "Critical Red Flag")

        # Create Emergency Event record if patient is identifiable
        patient = None
        if req.patient_id:
            patient = db.query(Patient).filter(Patient.id == req.patient_id).first()
        if not patient:
            patient = db.query(Patient).first()

        if patient:
            event = EmergencyEvent(
                patient_id=patient.id,
                red_flag_type=f"Chatbot Emergency: {matched_term}",
                severity="HIGH",
                status="UNACKNOWLEDGED"
            )
            db.add(event)
            db.commit()

        if detected_lang == "hi":
            final_response = (
                f"🚨 **आपातकालीन चेतावनी**: आपके द्वारा बताए गए लक्षण ('{matched_term}') गंभीर हो सकते हैं।\n\n"
                f"1. **तुरंत 108 एम्बुलेंस पर कॉल करें** या नज़दीकी आपातकालीन अस्पताल जाएं।\n"
                f"2. मरीज़ को शांत और आरामदायक स्थिति में रखें।\n"
                f"3. हमने आपकी स्थानीय स्वास्थ्य सहायता को सतर्क करने का संदेश दर्ज कर लिया है।"
            )
        elif detected_lang == "te":
            final_response = (
                f"🚨 **అత్యవసర హెచ్చరిక**: మీరు తెలిపిన లక్షణాలు తీవ్రమైనవిగా కనిపిస్తున్నాయి.\n\n"
                f"1. **వెంటనే 108 అంబులెన్స్‌కు కాల్ చేయండి** లేదా దగ్గరలోని ఆసుపత్రికి వెళ్ళండి.\n"
                f"2. రోగిని సౌకర్యవంతంగా ఉంచండి."
            )
        elif detected_lang == "ta":
            final_response = (
                f"🚨 **அவசர எச்சரிக்கை**: நீங்கள் குறிப்பிட்ட அறிகுறிகள் ஆபத்தானவை.\n\n"
                f"1. **உடனடியாக 108 ஆம்புலன்ஸை அழைக்கவும்** அல்லது மருத்துவமனைக்குச் செல்லவும்."
            )
        else:
            final_response = (
                f"🚨 **CRITICAL MEDICAL EMERGENCY DETECTED**: Symptoms '{matched_term}' require immediate attention!\n\n"
                f"1. **Call 108 (National Ambulance Helpline) immediately** or proceed to the nearest emergency trauma center.\n"
                f"2. Keep the patient in a resting, seated or recovery position; do not exert.\n"
                f"3. An alert has been logged for community health follow-up."
            )

    elif intent == ChatIntent.SYMPTOM_REPORT:
        # Run full clinical pipeline (Normalization -> MultiClinNER -> XGBoost Triage)
        try:
            clinical_data = run_voice_clinical_pipeline(raw_message, requested_language=detected_lang)
            is_emergency = clinical_data.get("emergency", {}).get("is_emergency", False)
            triage_level = clinical_data.get("triage_level", "ROUTINE")
            action = clinical_data.get("suggested_action", "")
            symptoms = clinical_data.get("standardized_symptoms", [])

            # Format helpful response
            symptom_list_str = ", ".join([s.replace("_", " ").title() for s in symptoms]) if symptoms else "reported symptoms"
            
            if is_emergency:
                final_response = (
                    f"⚠️ **Clinical Red Flag**: The system detected high-risk danger signs for: **{symptom_list_str}**.\n\n"
                    f"• Triage Status: **EMERGENCY**\n"
                    f"• Recommended Action: {action}\n"
                    f"• Please call **108** right away or visit the nearest Primary Health Centre / District Hospital."
                )
            else:
                level_badge = "🔴 URGENT" if triage_level == "URGENT" else "🟢 ROUTINE"
                final_response = (
                    f"📋 **Clinical Assessment Summary**:\n\n"
                    f"• Identified Symptoms: **{symptom_list_str}**\n"
                    f"• Triage Assessment: **{level_badge}**\n"
                    f"• Clinical Guidance: {action}\n\n"
                    f"Would you like me to connect you to an ASHA worker or book an appointment with our medical doctor?"
                )

            # If user spoke non-English, translate guidance back
            if detected_lang != "en":
                try:
                    final_response = translate_from_english(final_response, target_language=detected_lang)
                except Exception:
                    pass

        except Exception as e:
            logger.error(f"Symptom pipeline error: {e}")
            final_response = "Thank you for reporting your symptoms. A medical evaluation is recommended. Please visit your local Primary Health Centre (PHC)."

    elif intent == ChatIntent.APPOINTMENT_REQUEST:
        # Look up appointments or advise how to book
        appointments = []
        if req.patient_id:
            appointments = db.query(Appointment).filter(Appointment.patient_id == req.patient_id).order_by(Appointment.created_at.desc()).limit(3).all()
        
        if appointments:
            appt_details = []
            for a in appointments:
                q = getattr(a, 'queue_number', 1) or 1
                spec = getattr(a, 'speciality', 'General Medicine') or 'General Medicine'
                appt_details.append(f"• **Queue #{q}** - Speciality: {spec} (Status: {a.status})")
            appts_str = "\n".join(appt_details)
            final_response = (
                f"📅 **Your Doctor Appointments**:\n\n{appts_str}\n\n"
                f"You can also schedule a new consultation with our doctor or ASHA worker at any time."
            )
        else:
            final_response = (
                "📅 **Doctor & OPD Appointments**:\n\n"
                "We can connect you with the General Medicine, Pediatrics, or Gynecology specialists at your nearest PHC.\n"
                "To book an appointment, please speak or write your main symptom, or contact your village ASHA worker."
            )

        if detected_lang != "en":
            try:
                final_response = translate_from_english(final_response, target_language=detected_lang)
            except Exception:
                pass

    elif intent == ChatIntent.GREETING:
        if detected_lang == "hi":
            final_response = (
                "🙏 **नमस्ते! स्वास्थ्य सेतु में आपका स्वागत है।**\n\n"
                "मैं आपका डिजिटल स्वास्थ्य सहायक हूँ। मैं आपकी क्या मदद कर सकता हूँ?\n"
                "• अपने लक्षण बताएं (जैसे बुखार, खांसी, सिरदर्द)\n"
                "• मातृ एवं शिशु स्वास्थ्य या पोषण संबंधी जानकारी लें\n"
                "• डॉक्टर की पर्ची या अपॉइंटमेंट देखें"
            )
        elif detected_lang == "te":
            final_response = (
                "🙏 **నమస్కారం! స్వాస్థ్య సేతుకు స్వాగతం.**\n\n"
                "నేను మీ డిజిటల్ ఆరోగ్య సహాయకుడిని. మీ సమస్యను లేదా లక్షణాలను తెలియజేయండి."
            )
        elif detected_lang == "ta":
            final_response = (
                "🙏 **வணக்கம்! ஸ்வஸ்திய சேதுவிற்கு நல்வரவு.**\n\n"
                "நான் உங்கள் சுகாதார உதவியாளர். உங்கள் அறிகுறிகளை அல்லது சந்தேகங்களை கூறவும்."
            )
        else:
            final_response = (
                "👋 **Hello & Welcome to SwasthyaSetu!**\n\n"
                "I am your AI Healthcare Assistant. Here is how I can assist you today:\n"
                "1. **Check Symptoms**: Describe how you are feeling for AI triage and guidance.\n"
                "2. **Health Education & Maternal Care**: Ask about pregnancy, infant feeding, vaccination, malaria, or diabetes.\n"
                "3. **Doctor Consultations**: View and book OPD appointments.\n"
                "4. **Emergency Support**: Immediate guidance for critical health signs."
            )

    else:
        # HEALTH_FAQ / UNKNOWN -> RAG + Gemini Adapter
        # Translate to English for optimal semantic retrieval if input is in regional language
        query_in_english = raw_message
        if detected_lang != "en":
            try:
                query_in_english = translate_to_english(raw_message, source_language=detected_lang)
            except Exception:
                query_in_english = raw_message

        # RAG retrieval
        docs = rag_engine.search(query_in_english, top_k=3)
        context_str = rag_engine.format_context(docs)
        retrieved_faq = [{"question": d.get("question"), "category": d.get("category"), "answer": d.get("answer")} for d in docs]

        # Gemini LLM generation with fallback
        final_response = gemini_adapter.generate_response(
            prompt=query_in_english,
            context=context_str,
            history=history,
            language=detected_lang,
            user_role=req.role
        )

        # Translate back to native language if needed and response is in English
        if detected_lang != "en" and not any('\u0900' <= char <= '\u097f' for char in final_response):
            try:
                final_response = translate_from_english(final_response, target_language=detected_lang)
            except Exception:
                pass

    # Save assistant reply to history
    _save_message(
        db=db,
        session_id=session_id,
        role="assistant",
        message=final_response,
        intent=intent.value,
        language=detected_lang,
        is_emergency=is_emergency,
        patient_id=req.patient_id
    )

    t_level = clinical_data.get("triage_level") if clinical_data else None
    ext_symptoms = clinical_data.get("standardized_symptoms", []) if clinical_data else []

    return {
        "session_id": session_id,
        "reply": final_response,
        "response": final_response,
        "intent": intent.value,
        "language": detected_lang,
        "is_emergency": is_emergency,
        "triage_level": t_level,
        "extracted_symptoms": ext_symptoms,
        "clinical_data": clinical_data,
        "rag_sources": retrieved_faq,
        "retrieved_context": retrieved_faq
    }


@router.get("/faq-topics")
def get_faq_topics():
    """Returns available medical FAQ topics and categories."""
    faqs = rag_engine.faq_items
    categories = sorted(list({f.get("category") for f in faqs if f.get("category")}))
    return {
        "total_faqs": len(faqs),
        "categories": categories
    }



@router.post("/voice")
async def chat_voice(
    file: UploadFile = File(...),
    session_id: Optional[str] = Form(None),
    patient_id: Optional[str] = Form(None),
    language: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    """Audio speech-to-text chat endpoint. Transcribes audio bytes and routes to chat engine."""
    audio_bytes = await file.read()
    if not audio_bytes:
        raise HTTPException(400, "Audio recording is empty")

    transcription = transcribe_audio_bytes(
        audio_bytes,
        filename=file.filename or "audio.wav",
        language=language
    )

    req = ChatMessageRequest(
        message=transcription.text,
        session_id=session_id,
        patient_id=patient_id,
        language=language or transcription.language
    )

    result = chat_message(req, db=db)
    result["speech_to_text"] = {
        "text": transcription.text,
        "language": transcription.language,
        "confidence": transcription.confidence
    }
    return result


@router.get("/history/{session_id}")
def get_chat_history(session_id: str, db: Session = Depends(get_db)):
    """Retrieve all messages for a given session."""
    messages = db.query(ChatMessage).filter(ChatMessage.session_id == session_id).order_by(ChatMessage.created_at.asc()).all()
    return [{
        "id": m.id,
        "role": m.role,
        "message": m.message,
        "intent": m.intent,
        "language": m.language,
        "is_emergency": m.is_emergency,
        "created_at": m.created_at.isoformat()
    } for m in messages]


@router.delete("/history/{session_id}")
def clear_chat_history(session_id: str, db: Session = Depends(get_db)):
    """Clear conversation history for a given session."""
    db.query(ChatMessage).filter(ChatMessage.session_id == session_id).delete()
    db.commit()
    return {"status": "cleared", "session_id": session_id}
