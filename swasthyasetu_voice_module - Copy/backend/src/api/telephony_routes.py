"""Twilio Voice / Telephony Webhook API Routes for SwasthyaSetu.

Ports the Node.js Express voice telephony server into native FastAPI endpoints:
- POST /api/voice/incoming          : Initial Twilio call webhook (TwiML IVR)
- POST /api/voice/verify-patient    : Patient ID DTMF / voice verification
- POST /api/voice/process-speech    : Clinical triage, VoiceNote/EmergencyEvent creation, ASHA SMS alert
- GET  /api/voice/calls             : Call history log (from CallSession table)
- GET  /api/voice/calls/{call_sid}  : Specific call session details
- POST /api/voice/alerts/{id}/ack   : Acknowledge ASHA emergency alert
"""

import json
import logging
from datetime import datetime
from typing import Optional, List, Dict, Any

from fastapi import APIRouter, Depends, Form, HTTPException, Request, Response
from sqlalchemy.orm import Session

from app.config import settings
from app.database.database import get_db
from app.models.models import CallSession, EmergencyEvent, Patient, VoiceNote, AshaWorker, PatientAshaAssignment
from app.websocket_manager import websocket_manager
from src.clinical_pipeline import run_voice_clinical_pipeline

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/voice", tags=["Telephony & Voice IVR"])


def find_patient_by_phone(db: Session, phone_str: Optional[str]) -> Optional[Patient]:
    """Robust patient lookup supporting E.164, local digits, and known demo numbers."""
    if not phone_str:
        return None

    from app.utils.security import hash_phone

    raw_digits = "".join(c for c in phone_str if c.isdigit())
    last10 = raw_digits[-10:] if len(raw_digits) >= 10 else raw_digits

    # 1. Direct name/phone mapping for registered users
    if last10 == "9121458655":
        p = db.query(Patient).filter(Patient.name == "Balavignesh").first()
        if p:
            return p
    elif last10 == "9030252566":
        p = db.query(Patient).filter(Patient.name == "Harsha datta").first()
        if p:
            return p

    # 2. Match exact phone hash
    p_hash = hash_phone(phone_str)
    patient = db.query(Patient).filter(Patient.phone_hash == p_hash).first()
    if patient:
        return patient

    # 3. Match 10-digit normalized hash
    if last10:
        hash_10 = hash_phone(last10)
        patient = db.query(Patient).filter(
            (Patient.phone_hash == hash_10) | (Patient.phone_hash.like(f"%{last10}%"))
        ).first()
        if patient:
            return patient

    return None


def _make_twiml_response(content: str) -> Response:
    """Return a properly formed XML response for Twilio."""
    xml_content = f'<?xml version="1.0" encoding="UTF-8"?>\n<Response>\n{content}\n</Response>'
    return Response(content=xml_content, media_type="application/xml")


def _get_callback_url(endpoint: str, request: Optional[Request] = None) -> str:
    if request:
        host = request.headers.get("x-forwarded-host") or request.headers.get("host")
        proto = request.headers.get("x-forwarded-proto") or request.url.scheme
        if host and not any(h in host for h in ("127.0.0.1", "localhost")):
            return f"{proto}://{host}{endpoint}"
    base = (settings.PUBLIC_BASE_URL or "").rstrip("/")
    if base and not any(h in base for h in ("127.0.0.1", "localhost", "example.com")):
        return f"{base}{endpoint}"
    return endpoint


@router.post("/incoming")
async def incoming_call(
    request: Request,
    CallSid: Optional[str] = Form(None),
    From: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    """Initial IVR greeting. Prompts caller for 4-digit patient ID or speech."""
    logger.info(f"Incoming Twilio call: CallSid={CallSid}, From={From}")

    # Track call session
    session = None
    if CallSid:
        session = db.query(CallSession).filter(CallSession.call_sid == CallSid).first()
        if not session:
            session = CallSession(
                call_sid=CallSid,
                caller_number=From or "Unknown",
                status="INCOMING_CALL_ACTIVE"
            )
            db.add(session)
            db.commit()

    # Check if caller is a recognized patient
    if From:
        recognized_patient = find_patient_by_phone(db, From)
        if recognized_patient:
            if session:
                session.patient_id = recognized_patient.id
                session.status = "PATIENT_VERIFIED"
                db.commit()
            speech_action = _get_callback_url("/api/voice/process-speech", request=request)
            p_name = recognized_patient.name or "Valued Caller"
            twiml = f"""  <Say voice="Polly.Aditi" language="hi-IN">नमस्ते {p_name} जी! स्वास्थ्य सेतु में आपका स्वागत है। Welcome to SwasthyaSetu. कृपया बीप के बाद अपने लक्षण बताएं। Please describe your symptoms after the beep.</Say>
  <Gather input="speech" timeout="6" speechTimeout="auto" language="hi-IN" action="{speech_action}" method="POST">
  </Gather>
  <Record timeout="5" maxLength="45" playBeep="true" action="{speech_action}" method="POST"/>"""
            return _make_twiml_response(twiml)

    verify_action = _get_callback_url("/api/voice/verify-patient", request=request)

    twiml = f"""  <Gather numDigits="4" timeout="6" action="{verify_action}" method="POST">
    <Say voice="Polly.Aditi" language="hi-IN">नमस्ते! स्वास्थ्य सेतु में आपका स्वागत है। Welcome to SwasthyaSetu Helpline. कृपया अपना 4 अंकों का मरीज़ पहचान संख्या दर्ज करें, या सीधे बोलने के लिए 0 दबाएं।</Say>
  </Gather>
  <Redirect method="POST">{verify_action}</Redirect>"""
    return _make_twiml_response(twiml)


@router.post("/verify-patient")
async def verify_patient(
    request: Request,
    CallSid: Optional[str] = Form(None),
    From: Optional[str] = Form(None),
    Digits: Optional[str] = Form(None),
    SpeechResult: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    """Verifies patient from DTMF digits or phone number, then gathers symptom description."""
    digits = (Digits or "").strip()
    logger.info(f"Verify patient: CallSid={CallSid}, Digits={digits}, From={From}")

    patient = None
    if digits and digits != "0":
        # Search by health_id ending or ID
        patient = db.query(Patient).filter(
            (Patient.health_id.like(f"%{digits}%")) | (Patient.id.like(f"%{digits}%"))
        ).first()

    if not patient and From:
        patient = find_patient_by_phone(db, From)

    # If still not found, pick demo patient or create one
    if not patient:
        patient = db.query(Patient).first()

    patient_id = patient.id if patient else "DEMO-PATIENT-001"
    patient_name = patient.name if patient else "Valued Caller"

    # Update CallSession with patient_id
    if CallSid:
        session = db.query(CallSession).filter(CallSession.call_sid == CallSid).first()
        if session:
            session.patient_id = patient_id
            session.status = "PATIENT_VERIFIED"
            db.commit()

    process_action = _get_callback_url("/api/voice/process-speech", request=request)

    twiml = f"""  <Say voice="Polly.Aditi" language="hi-IN">पहचान सफल हुई, {patient_name} जी। कृपया बीप की आवाज़ के बाद अपनी परेशानी या लक्षण विस्तार से बताएं।</Say>
  <Gather input="speech" timeout="7" speechTimeout="auto" action="{process_action}" method="POST" language="hi-IN">
  </Gather>
  <Record action="{process_action}" maxLength="60" finishOnKey="#" playBeep="true"/>"""
    return _make_twiml_response(twiml)


@router.post("/process-speech")
@router.post("/triage")
async def process_speech(
    request: Request,
    CallSid: Optional[str] = Form(None),
    From: Optional[str] = Form(None),
    SpeechResult: Optional[str] = Form(None),
    RecordingUrl: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    """Processes spoken symptoms through clinical NLP + XGBoost triage pipeline,

    creates VoiceNote, alerts ASHA worker if emergency, and speaks TwiML response.
    """
    # Ensure form parameter defaults aren't Form objects
    if not isinstance(CallSid, str): CallSid = None
    if not isinstance(From, str): From = None
    if not isinstance(SpeechResult, str): SpeechResult = None
    if not isinstance(RecordingUrl, str): RecordingUrl = None

    # Fallback to request form or json if not already extracted
    if not CallSid and not SpeechResult:
        try:
            form_data = await request.form()
            CallSid = form_data.get("CallSid") or form_data.get("call_sid") or CallSid
            From = form_data.get("From") or form_data.get("from") or form_data.get("caller_phone") or From
            SpeechResult = form_data.get("SpeechResult") or form_data.get("speech_result") or form_data.get("transcript") or SpeechResult
            RecordingUrl = form_data.get("RecordingUrl") or form_data.get("recording_url") or RecordingUrl
        except Exception:
            pass

        if not CallSid and not SpeechResult:
            try:
                body = await request.json()
                if isinstance(body, dict):
                    CallSid = body.get("CallSid") or body.get("call_sid") or CallSid
                    From = body.get("From") or body.get("from") or body.get("caller_phone") or From
                    SpeechResult = body.get("SpeechResult") or body.get("speech_result") or body.get("transcript") or SpeechResult
                    RecordingUrl = body.get("RecordingUrl") or body.get("recording_url") or RecordingUrl
            except Exception:
                pass

    raw_text = (SpeechResult or "").strip()
    logger.info(f"Process speech / triage: CallSid={CallSid}, SpeechResult='{raw_text}', RecordingUrl={RecordingUrl}")

    # Fallback if no speech captured
    if not raw_text:
        raw_text = "Routine consultation follow up"

    # Run clinical triage pipeline
    try:
        clinical_output = run_voice_clinical_pipeline(raw_text)
    except Exception as e:
        logger.error(f"Clinical pipeline failed for telephony call: {e}")
        clinical_output = {
            "triage_level": "ROUTINE",
            "is_emergency": False,
            "suggested_action": "Consult your local doctor or ASHA worker.",
            "emergency": {"is_emergency": False, "red_flag_type": None},
            "extracted_entities": [],
            "standardized_symptoms": [],
            "translated_text": raw_text
        }

    triage_level = clinical_output.get("triage_level", "ROUTINE")
    is_emergency = clinical_output.get("emergency", {}).get("is_emergency", False) or triage_level == "EMERGENCY"
    red_flag_type = clinical_output.get("emergency", {}).get("red_flag_type") or ("Critical Clinical Triage: Emergency" if is_emergency else None)
    suggested_action = clinical_output.get("suggested_action", "Consult your local doctor.")

    # 1. Find or create CallSession by CallSid
    session = None
    if CallSid:
        session = db.query(CallSession).filter(CallSession.call_sid == CallSid).first()
        if not session:
            session = CallSession(
                call_sid=CallSid,
                caller_number=From or "Unknown",
                status="INCOMING_CALL_ACTIVE"
            )
            db.add(session)
            db.commit()
            db.refresh(session)

    # 2. Identify patient reliably
    patient = None
    if session and session.patient_id:
        patient = db.query(Patient).filter(Patient.id == session.patient_id).first()

    if not patient and From:
        patient = find_patient_by_phone(db, From)
    if not patient and session and session.caller_number:
        patient = find_patient_by_phone(db, session.caller_number)

    if not patient:
        patient = db.query(Patient).first()

    patient_id = patient.id if patient else "DEMO-PATIENT-001"
    patient_name = patient.name if patient else "Patient"
    patient_village = patient.village if patient else "Central Village"

    if session and not session.patient_id:
        session.patient_id = patient_id
        db.commit()

    # 3. Create VoiceNote in DB
    note = VoiceNote(
        patient_id=patient_id,
        raw_transcript=raw_text,
        translated_text=clinical_output.get("translated_text", raw_text),
        extracted_symptoms=json.dumps(clinical_output.get("standardized_symptoms", [])),
        is_emergency=is_emergency,
        red_flag_type=red_flag_type if is_emergency else None,
        clinical_summary=clinical_output.get("suggested_action")
    )
    db.add(note)
    db.commit()
    db.refresh(note)

    # 4. Identify assigned ASHA worker
    asha = None
    if patient:
        assignment = db.query(PatientAshaAssignment).filter(PatientAshaAssignment.patient_id == patient.id).first()
        if assignment:
            asha = db.query(AshaWorker).filter(AshaWorker.id == assignment.asha_id).first()
    if not asha:
        asha = db.query(AshaWorker).filter(AshaWorker.is_active == True).first()
    asha_id = asha.id if asha else "1ff3d261-76ad-4f69-9873-504b048cc67c"

    # Determine alert attributes for ASHA dashboard
    if is_emergency:
        severity = "HIGH"
        alert_title = red_flag_type or "Severe Acute Symptoms / Emergency"
        risk_score_val = max(session.risk_score or 90, 85)
    elif triage_level == "URGENT":
        severity = "MEDIUM"
        alert_title = f"Urgent Voice Triage: {suggested_action[:50]}"
        risk_score_val = max(session.risk_score or 65, 60)
    else:
        severity = "ROUTINE"
        alert_title = f"Voice Consultation: {suggested_action[:50]}"
        risk_score_val = session.risk_score or 25

    # ALWAYS create EmergencyEvent incident in DB for ASHA worker dashboard
    event = EmergencyEvent(
        call_session_id=session.id if session else None,
        patient_id=patient_id,
        asha_id=asha_id,
        red_flag_type=alert_title,
        severity=severity,
        status="UNACKNOWLEDGED"
    )
    db.add(event)
    db.commit()
    db.refresh(event)

    # Real-time WebSocket broadcast to connected ASHA dashboards
    caller_phone_val = (From or (session.caller_number if session and session.caller_number != 'Unknown' else None) or ("+919121458655" if patient_name == "Balavignesh" else "+919030252566"))
    try:
        websocket_manager.broadcast_emergency_alert(
            alert_id=event.id,
            red_flag_type=alert_title,
            severity=severity,
            status="UNACKNOWLEDGED",
            call_session_id=session.id if session else None,
            patient_id=patient_id,
            patient_name=patient_name,
            patient_phone=caller_phone_val,
            patient_village=patient_village,
            symptoms=raw_text,
            risk_score=risk_score_val,
            assigned_asha_id=asha_id,
            created_at=event.created_at.isoformat()
        )
    except Exception as ws_err:
        logger.warning(f"WebSocket broadcast error: {ws_err}")

    asha_alert_data = {
        "event_id": event.id,
        "red_flag": alert_title,
        "severity": severity,
        "asha_id": asha_id,
        "timestamp": datetime.utcnow().isoformat()
    }

    # Dispatch Twilio SMS notifications if credentials exist
    if is_emergency:
        if settings.TWILIO_ACCOUNT_SID and settings.TWILIO_AUTH_TOKEN:
            tw_client = None
            try:
                from twilio.rest import Client
                tw_client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
            except Exception as e:
                logger.warning(f"Failed to initialize Twilio client: {e}")

            if tw_client:
                # 1. Dispatch emergency alert directly to caller's verified phone
                caller_target = (From or (session.caller_number if session and session.caller_number != 'Unknown' else "") or "").strip()
                if caller_target and caller_target.startswith("+") and len(caller_target) >= 10:
                    try:
                        clean_flag = (red_flag_type or "Emergency").replace("'", "").strip()
                        caller_body = (
                            f"[SWASTHYA SETU EMERGENCY] Red flag detected: {clean_flag}. "
                            f"Your local ASHA worker has been alerted. Please call 108 or visit hospital immediately."
                        )
                        msg = tw_client.messages.create(
                            body=caller_body,
                            from_=settings.TWILIO_PHONE_NUMBER,
                            to=caller_target
                        )
                        logger.info(f"Sent emergency SMS confirmation to caller {caller_target} (SID: {msg.sid})")
                    except Exception as e:
                        logger.warning(f"Failed to dispatch caller SMS to {caller_target}: {e}")

                # 2. Dispatch alert to ASHA worker if distinct
                if asha and asha.phone and asha.phone != caller_target:
                    try:
                        clean_flag = (red_flag_type or "Emergency").replace("'", "").strip()
                        sms_body = (
                            f"[SWASTHYA SETU ALERT] Patient {patient_name} ({caller_target or 'Caller'}) reported: {clean_flag}. "
                            f"Immediate home visit or PHC referral required! Ref: {event.id[:8]}"
                        )
                        tw_client.messages.create(
                            body=sms_body,
                            from_=settings.TWILIO_PHONE_NUMBER,
                            to=asha.phone
                        )
                        logger.info(f"Sent emergency SMS alert to ASHA worker {asha.phone}")
                    except Exception as e:
                        logger.warning(f"Failed to dispatch ASHA SMS to {asha.phone}: {e}")
    else:
        # Send triage summary SMS to caller for non-emergency assessment
        if settings.TWILIO_ACCOUNT_SID and settings.TWILIO_AUTH_TOKEN:
            caller_target = (From or (session.caller_number if session and session.caller_number != 'Unknown' else "") or "").strip()
            if caller_target and caller_target.startswith("+") and len(caller_target) >= 10:
                try:
                    from twilio.rest import Client
                    tw_client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
                    summary_clean = (suggested_action or "Routine follow-up recommended.")[:90].replace("'", "")
                    caller_body = (
                        f"[Swasthya Setu] Voice health check complete. Category: {triage_level}. "
                        f"Advice: {summary_clean}"
                    )
                    msg = tw_client.messages.create(
                        body=caller_body,
                        from_=settings.TWILIO_PHONE_NUMBER,
                        to=caller_target
                    )
                    logger.info(f"Sent assessment SMS to caller {caller_target} (SID: {msg.sid})")
                except Exception as e:
                    logger.warning(f"Failed to dispatch assessment SMS to {caller_target}: {e}")

    # 5. Update same CallSession with triage results
    if session:
        session.transcript = raw_text
        session.recorded_audio_url = RecordingUrl
        session.triage_level = triage_level
        session.medical_entities_json = json.dumps(clinical_output.get("extracted_entities", []))
        session.risk_score = risk_score_val
        session.status = "COMPLETED"
        if asha_alert_data:
            session.asha_alert_json = json.dumps(asha_alert_data)
        db.commit()

    # Generate Spoken TwiML Response
    if is_emergency:
        twiml = f"""  <Say voice="Polly.Aditi" language="hi-IN">चेतावनी: आपके लक्षणों में आपातकालीन संकेत पाए गए हैं। हमने आपकी निकटतम आशा कार्यकर्ता को तत्काल सतर्क कर दिया है। कृपया तुरंत 108 पर कॉल करें या नज़दीकी स्वास्थ्य केंद्र जाएं।</Say>
  <Hangup/>"""
    else:
        hindi_triage = "अति आवश्यक (Urgent)" if triage_level == "URGENT" else "सामान्य (Routine)"
        twiml = f"""  <Say voice="Polly.Aditi" language="hi-IN">धन्यवाद {patient_name} जी। आपके लक्षणों का विश्लेषण पूरा हो गया है। स्थिति श्रेणी है: {hindi_triage}। {suggested_action}</Say>
  <Hangup/>"""

    return _make_twiml_response(twiml)


@router.get("/calls")
def list_call_sessions(limit: int = 100, db: Session = Depends(get_db)):
    """Return all recorded call sessions."""
    sessions = db.query(CallSession).order_by(CallSession.created_at.desc()).limit(limit).all()

    results = []
    for s in sessions:
        entities = []
        if s.medical_entities_json:
            try:
                entities = json.loads(s.medical_entities_json)
            except Exception:
                pass
        results.append({
            "id": s.id,
            "call_sid": s.call_sid,
            "caller_number": s.caller_number,
            "patient_id": s.patient_id,
            "status": s.status,
            "transcript": s.transcript,
            "recorded_audio_url": s.recorded_audio_url,
            "triage_level": s.triage_level,
            "risk_score": s.risk_score,
            "medical_entities": entities,
            "created_at": s.created_at.isoformat() if s.created_at else None,
            "updated_at": s.updated_at.isoformat() if s.updated_at else None
        })
    return results


@router.get("/calls/{call_sid}")
def get_call_session(call_sid: str, db: Session = Depends(get_db)):
    """Get single call session details by Twilio CallSid."""
    session = db.query(CallSession).filter(CallSession.call_sid == call_sid).first()
    if not session:
        raise HTTPException(404, "Call session not found")

    entities = []
    if session.medical_entities_json:
        try:
            entities = json.loads(session.medical_entities_json)
        except Exception:
            pass

    alert = None
    if session.asha_alert_json:
        try:
            alert = json.loads(session.asha_alert_json)
        except Exception:
            pass

    return {
        "id": session.id,
        "call_sid": session.call_sid,
        "caller_number": session.caller_number,
        "patient_id": session.patient_id,
        "status": session.status,
        "transcript": session.transcript,
        "recorded_audio_url": session.recorded_audio_url,
        "triage_level": session.triage_level,
        "risk_score": session.risk_score,
        "medical_entities": entities,
        "asha_alert": alert,
        "created_at": session.created_at.isoformat() if session.created_at else None,
        "updated_at": session.updated_at.isoformat() if session.updated_at else None
    }


@router.post("/alerts/{alert_id}/acknowledge")
def acknowledge_telephony_alert(alert_id: str, db: Session = Depends(get_db)):
    """Acknowledge emergency alert generated during telephony call."""
    event = db.query(EmergencyEvent).filter(EmergencyEvent.id == alert_id).first()
    if not event:
        raise HTTPException(404, "Emergency alert not found")
    event.status = "ACKNOWLEDGED"
    event.acknowledged_at = datetime.utcnow()
    db.commit()
    return {"status": "ok", "alert_id": event.id, "status_text": "ACKNOWLEDGED", "acknowledged_at": event.acknowledged_at.isoformat()}
