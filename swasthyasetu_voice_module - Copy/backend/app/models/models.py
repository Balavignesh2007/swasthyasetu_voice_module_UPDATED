from datetime import datetime
import uuid
from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship
from app.database.database import Base

def uid(): return str(uuid.uuid4())

class User(Base):
    __tablename__ = 'users'
    id = Column(String, primary_key=True, default=uid)
    username = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    name = Column(String, nullable=False)
    role = Column(String, default='patient', nullable=False)  # patient, health_worker, doctor, pharmacy, lab, phc_admin
    facility_id = Column(String, nullable=True)
    two_factor_enabled = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

class DoctorUser(Base):
    __tablename__ = 'doctor_users'
    id = Column(String, primary_key=True, default=uid)
    name = Column(String, nullable=False)
    username = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    role = Column(String, default='doctor', nullable=False)
    speciality = Column(String, default='General Medicine')
    facility_id = Column(String, ForeignKey('facilities.id'), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

class Facility(Base):
    __tablename__ = 'facilities'
    id = Column(String, primary_key=True, default=uid)
    name = Column(String, nullable=False)
    facility_type = Column(String, default='PHC') # PHC, Rural Hospital, District Hospital
    district = Column(String, default='')
    address = Column(String, nullable=True)
    emergency_capable = Column(Boolean, default=True)
    phone = Column(String, nullable=True)
    beds_total = Column(Integer, default=20)
    beds_available = Column(Integer, default=12)

class Patient(Base):
    __tablename__ = 'patients'
    id = Column(String, primary_key=True, default=uid)
    name = Column(String, nullable=True)
    controlled_identity_key = Column(String, nullable=True, unique=True)
    phone_hash = Column(String, nullable=True, index=True)
    health_id = Column(String, nullable=True, index=True)
    village = Column(String, nullable=True)
    preferred_language = Column(String, default='en')
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

class AshaWorker(Base):
    __tablename__ = 'asha_workers'
    id = Column(String, primary_key=True, default=uid)
    name = Column(String, nullable=False)
    phone = Column(String, unique=True, index=True, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

class PatientAshaAssignment(Base):
    __tablename__ = 'patient_asha_assignments'
    id = Column(String, primary_key=True, default=uid)
    patient_id = Column(String, ForeignKey('patients.id'), nullable=False)
    asha_id = Column(String, ForeignKey('asha_workers.id'), nullable=False)
    status = Column(String, default='active')

class Case(Base):
    __tablename__ = 'cases'
    id = Column(String, primary_key=True, default=uid)
    patient_id = Column(String, nullable=False, index=True)
    symptom_text = Column(Text, nullable=False)
    language = Column(String, default='en')
    severity = Column(String, default='routine')  # routine, review, urgent
    status = Column(String, default='open')        # open, in_consultation, closed
    source = Column(String, default='patient_app') # patient_app, health_worker_app
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

class Appointment(Base):
    __tablename__ = 'appointments'
    id = Column(String, primary_key=True, default=uid)
    case_id = Column(String, nullable=True)
    patient_id = Column(String, nullable=False, index=True)
    doctor_id = Column(String, nullable=True)
    facility_id = Column(String, nullable=True)
    scheduled_time = Column(DateTime, nullable=True)
    slot_time = Column(String, nullable=True)
    status = Column(String, default='booked')  # booked, checked_in, no_show, completed
    check_in_time = Column(DateTime, nullable=True)
    start_service_time = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    notes = Column(Text, nullable=True)
    speciality = Column(String, default='General Medicine')
    queue_number = Column(Integer, default=1)
    prescription = Column(Text, nullable=True)
    diagnosis = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

class Consult(Base):
    __tablename__ = 'consults'
    id = Column(String, primary_key=True, default=uid)
    case_id = Column(String, nullable=False, index=True)
    doctor_id = Column(String, nullable=False)
    notes = Column(Text, nullable=True)
    started_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    ended_at = Column(DateTime, nullable=True)

class Referral(Base):
    __tablename__ = 'referrals'
    id = Column(String, primary_key=True, default=uid)
    case_id = Column(String, nullable=True)
    patient_id = Column(String, nullable=True)
    from_facility_id = Column(String, nullable=True)
    to_facility_id = Column(String, nullable=False)
    status = Column(String, default='requested')  # requested, accepted, completed
    reason = Column(Text, nullable=True)
    urgency = Column(String, default='ROUTINE')    # ROUTINE, URGENT, EMERGENCY
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

class FollowUp(Base):
    __tablename__ = 'follow_ups'
    id = Column(String, primary_key=True, default=uid)
    case_id = Column(String, nullable=True)
    patient_id = Column(String, nullable=False, index=True)
    asha_id = Column(String, nullable=True)
    facility_id = Column(String, nullable=True)
    doctor_id = Column(String, nullable=True)
    category = Column(String, default='chronic')  # maternal, child, chronic, elderly
    title = Column(String, nullable=False)
    next_checkin_date = Column(DateTime, nullable=True)
    due_date = Column(DateTime, nullable=False)
    status = Column(String, default='pending')    # pending, completed
    priority = Column(String, default='NORMAL')
    notes = Column(Text, nullable=True)
    escalated_to_doctor = Column(Boolean, default=False)
    completed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

class PrescriptionOrder(Base):
    __tablename__ = 'prescription_orders'
    id = Column(String, primary_key=True, default=uid)
    case_id = Column(String, nullable=True)
    doctor_id = Column(String, nullable=False)
    patient_id = Column(String, nullable=True)
    facility_id = Column(String, nullable=False)
    medicine_list = Column(Text, nullable=False)   # JSON or formatted list
    instructions = Column(Text, nullable=True)
    status = Column(String, default='pending')     # pending, dispensed
    dispensed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

class LabOrder(Base):
    __tablename__ = 'lab_orders'
    id = Column(String, primary_key=True, default=uid)
    case_id = Column(String, nullable=True)
    doctor_id = Column(String, nullable=False)
    patient_id = Column(String, nullable=True)
    facility_id = Column(String, nullable=False)
    test_type = Column(String, nullable=False)     # CBC, Blood Glucose, Urine Routine, Malaria Rapid, Lipid Profile
    status = Column(String, default='pending')     # pending, sample_collected, result_uploaded
    result_ref = Column(String, nullable=True)
    result_summary = Column(Text, nullable=True)
    sample_collected_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

class ConsentRecord(Base):
    __tablename__ = 'consent_records'
    id = Column(String, primary_key=True, default=uid)
    patient_id = Column(String, nullable=False, index=True)
    requested_by = Column(String, nullable=False)
    scope = Column(String, default='tier_1_consent') # tier_1_consent, tier_2_records, tier_3_clinical_history
    status = Column(String, default='active')         # active, revoked, expired
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

class FacilityStatus(Base):
    __tablename__ = 'facility_statuses'
    id = Column(String, primary_key=True, default=uid)
    facility_id = Column(String, nullable=False, unique=True)
    doctor_id = Column(String, nullable=True)
    available = Column(Boolean, default=True)
    manually_toggled = Column(Boolean, default=False)
    roster_shift_start = Column(String, default='09:00')
    roster_shift_end = Column(String, default='17:00')
    beds_available = Column(Integer, default=12)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

class DoctorRoster(Base):
    __tablename__ = 'doctor_rosters'
    id = Column(String, primary_key=True, default=uid)
    doctor_id = Column(String, nullable=False)
    facility_id = Column(String, nullable=False)
    shift_start = Column(String, default='09:00')
    shift_end = Column(String, default='17:00')
    day_of_week = Column(String, default='Monday-Saturday')
    is_on_duty = Column(Boolean, default=True)

class MedicineInventory(Base):
    __tablename__ = 'medicine_inventories'
    id = Column(String, primary_key=True, default=uid)
    facility_id = Column(String, nullable=False, index=True)
    medicine_name = Column(String, nullable=False)
    stock_quantity = Column(Integer, default=100)
    unit = Column(String, default='tablets')
    min_threshold = Column(Integer, default=20)
    status = Column(String, default='available') # available, low_stock, out_of_stock
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

class DiagnosticService(Base):
    __tablename__ = 'diagnostic_services'
    id = Column(String, primary_key=True, default=uid)
    facility_id = Column(String, nullable=False, index=True)
    test_name = Column(String, nullable=False)
    available = Column(Boolean, default=True)
    turn_around_hours = Column(Integer, default=4)

class EmergencyEvent(Base):
    __tablename__ = 'emergency_events'
    id = Column(String, primary_key=True, default=uid)
    case_id = Column(String, nullable=True)
    call_session_id = Column(String, nullable=True)
    patient_id = Column(String, nullable=True)
    asha_id = Column(String, nullable=True)
    red_flag_type = Column(String, nullable=False)
    severity = Column(String, default='HIGH')       # ROUTINE, MEDIUM, HIGH, URGENT
    status = Column(String, default='UNACKNOWLEDGED')
    triggered_via = Column(String, default='app_trigger') # app_trigger, voice_call, 114_mock
    connected_to_108_at = Column(DateTime, nullable=True)
    asha_notified_at = Column(DateTime, nullable=True)
    phc_notified_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    acknowledged_at = Column(DateTime, nullable=True)
    resolved_at = Column(DateTime, nullable=True)

class TwoFactorChallenge(Base):
    __tablename__ = 'two_factor_challenges'
    id = Column(String, primary_key=True, default=uid)
    user_id = Column(String, nullable=False, index=True)
    code = Column(String, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    verified = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

class SyncQueue(Base):
    __tablename__ = 'sync_queues'
    id = Column(String, primary_key=True, default=uid)
    idempotency_key = Column(String, unique=True, index=True, nullable=False)
    operation = Column(String, nullable=False)
    payload = Column(Text, nullable=False)
    retry_count = Column(Integer, default=0)
    sync_status = Column(String, default='synced') # pending, synced, failed
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    synced_at = Column(DateTime, default=datetime.utcnow, nullable=False)

class Notification(Base):
    __tablename__ = 'notifications'
    id = Column(String, primary_key=True, default=uid)
    user_id = Column(String, nullable=False, index=True)
    title = Column(String, nullable=False)
    message = Column(Text, nullable=False)
    type = Column(String, default='general') # emergency, appointment, queue, referral, followup, lab
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

class AuditLog(Base):
    __tablename__ = 'audit_logs'
    id = Column(String, primary_key=True, default=uid)
    user_id = Column(String, nullable=True)
    action = Column(String, nullable=False)
    resource = Column(String, nullable=False)
    details = Column(Text, nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow, nullable=False)

class VoiceNote(Base):
    __tablename__ = 'voice_notes'
    id = Column(String, primary_key=True, default=uid)
    patient_id = Column(String, nullable=True)
    asha_id = Column(String, nullable=True)
    raw_transcript = Column(Text, nullable=True)
    translated_text = Column(Text, nullable=True)
    language = Column(String, default='en')
    extracted_symptoms = Column(Text, nullable=True)
    confirmed_symptoms = Column(Text, nullable=True)
    is_emergency = Column(Boolean, default=False)
    red_flag_type = Column(String, nullable=True)
    clinical_summary = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

class CallSession(Base):
    __tablename__ = 'call_sessions'
    id = Column(String, primary_key=True, default=uid)
    call_sid = Column(String, unique=True, index=True, nullable=False)
    caller_number = Column(String, nullable=True)
    patient_id = Column(String, nullable=True)
    status = Column(String, default='INCOMING_CALL_ACTIVE')
    transcript = Column(Text, nullable=True)
    recorded_audio_url = Column(String, nullable=True)
    medical_entities_json = Column(Text, nullable=True)
    triage_level = Column(String, default='PENDING')
    risk_score = Column(Integer, default=0)
    asha_alert_json = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

class ChatMessage(Base):
    __tablename__ = 'chat_messages'
    id = Column(String, primary_key=True, default=uid)
    session_id = Column(String, index=True, nullable=False)
    patient_id = Column(String, nullable=True)
    role = Column(String, nullable=False)       # 'user' | 'assistant'
    message = Column(Text, nullable=False)
    intent = Column(String, nullable=True)
    language = Column(String, default='en')
    is_emergency = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
