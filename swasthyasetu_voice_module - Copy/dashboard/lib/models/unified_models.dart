enum UserRole {
  patient,
  asha,
  doctor,
  pharmacy,
  lab,
  phcAdmin;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'doctor': return UserRole.doctor;
      case 'asha':
      case 'health_worker': return UserRole.asha;
      case 'patient': return UserRole.patient;
      case 'pharmacy': return UserRole.pharmacy;
      case 'lab': return UserRole.lab;
      case 'phc_admin':
      case 'admin': return UserRole.phcAdmin;
      default: return UserRole.patient;
    }
  }
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.patient:
        return 'Patient';
      case UserRole.asha:
        return 'Health Worker (ASHA/ANM)';
      case UserRole.doctor:
        return 'Doctor / Specialist';
      case UserRole.pharmacy:
        return 'Pharmacy Staff';
      case UserRole.lab:
        return 'Lab Technician';
      case UserRole.phcAdmin:
        return 'PHC Administration';
    }
  }

  String get shortLabel {
    switch (this) {
      case UserRole.patient:
        return 'Patient';
      case UserRole.asha:
        return 'ASHA';
      case UserRole.doctor:
        return 'Doctor';
      case UserRole.pharmacy:
        return 'Pharmacy';
      case UserRole.lab:
        return 'Lab';
      case UserRole.phcAdmin:
        return 'PHC Admin';
    }
  }
}

class UnifiedUserSession {
  final UserRole role;
  final String id;
  final String name;
  final String identifier; // dr.sharma, +919876543210, HID10001
  final String? token;
  final Map<String, dynamic> extra;

  UnifiedUserSession({
    required this.role,
    required this.id,
    required this.name,
    required this.identifier,
    this.token,
    this.extra = const {},
  });
}

// -------------------------------------------------------------
// DOCTOR MODELS
// -------------------------------------------------------------

class DoctorProfile {
  final String id;
  final String name;
  final String username;
  final String role;
  final String? speciality;
  final String? facilityId;

  DoctorProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    this.speciality,
    this.facilityId,
  });

  factory DoctorProfile.fromJson(Map<String, dynamic> json) {
    return DoctorProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      username: json['username'] as String,
      role: json['role'] as String? ?? 'doctor',
      speciality: json['speciality'] as String?,
      facilityId: json['facility_id'] as String?,
    );
  }
}

class DashboardStats {
  final int totalCalls;
  final int activeCalls;
  final int completedCalls;
  final int emergencyCalls;
  final int highCases;
  final int lowCases;
  final int ashaAlerts;
  final int unacknowledgedAlerts;
  final int referralRequests;
  final int appointmentBookings;

  DashboardStats({
    required this.totalCalls,
    required this.activeCalls,
    required this.completedCalls,
    required this.emergencyCalls,
    required this.highCases,
    required this.lowCases,
    required this.ashaAlerts,
    required this.unacknowledgedAlerts,
    required this.referralRequests,
    required this.appointmentBookings,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v == null ? 0 : (v as num).toInt();
    return DashboardStats(
      totalCalls: asInt(json['total_calls']),
      activeCalls: asInt(json['active_calls']),
      completedCalls: asInt(json['completed_calls']),
      emergencyCalls: asInt(json['emergency_calls']),
      highCases: asInt(json['high_cases']),
      lowCases: asInt(json['low_cases']),
      ashaAlerts: asInt(json['asha_alerts']),
      unacknowledgedAlerts: asInt(json['unacknowledged_alerts']),
      referralRequests: asInt(json['referral_requests']),
      appointmentBookings: asInt(json['appointment_bookings']),
    );
  }
}

class DoctorEmergencyEvent {
  final String id;
  final String? patientId;
  final String? patientName;
  final String? patientPhone;
  final String? patientVillage;
  final String? symptoms;
  final int? riskScore;
  final String redFlagType;
  final String severity;
  final String status;
  final String? assignedAshaId;
  final DateTime createdAt;

  DoctorEmergencyEvent({
    required this.id,
    this.patientId,
    this.patientName,
    this.patientPhone,
    this.patientVillage,
    this.symptoms,
    this.riskScore,
    required this.redFlagType,
    required this.severity,
    required this.status,
    this.assignedAshaId,
    required this.createdAt,
  });

  factory DoctorEmergencyEvent.fromJson(Map<String, dynamic> json) {
    return DoctorEmergencyEvent(
      id: json['id'] as String,
      patientId: json['patient_id'] as String?,
      patientName: json['patient_name'] as String?,
      patientPhone: json['patient_phone'] as String?,
      patientVillage: json['patient_village'] as String?,
      symptoms: json['symptoms'] as String?,
      riskScore: json['risk_score'] != null ? (json['risk_score'] as num).toInt() : null,
      redFlagType: json['red_flag_type'] as String? ?? 'General Emergency',
      severity: json['severity'] as String? ?? 'HIGH',
      status: json['status'] as String? ?? 'UNACKNOWLEDGED',
      assignedAshaId: json['assigned_asha_id'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }
}

class DoctorAppointment {
  final String id;
  final String patientId;
  final String? patientName;
  final String? patientPhone;
  final String? patientVillage;
  final String? healthId;
  final String? facilityId;
  final String? speciality;
  final int? queueNumber;
  final String status;
  final String? doctorId;
  final String? notes;
  final String? prescription;
  final String? diagnosis;
  final String? voiceNoteId;
  final String? rawTranscript;
  final String? translatedText;
  final List<String> extractedSymptoms;
  final bool isEmergency;
  final String? redFlagType;
  final DateTime createdAt;

  DoctorAppointment({
    required this.id,
    required this.patientId,
    this.patientName,
    this.patientPhone,
    this.patientVillage,
    this.healthId,
    this.facilityId,
    this.speciality,
    this.queueNumber,
    required this.status,
    this.doctorId,
    this.notes,
    this.prescription,
    this.diagnosis,
    this.voiceNoteId,
    this.rawTranscript,
    this.translatedText,
    this.extractedSymptoms = const [],
    this.isEmergency = false,
    this.redFlagType,
    required this.createdAt,
  });

  factory DoctorAppointment.fromJson(Map<String, dynamic> json) {
    final rawSymptoms = json['extracted_symptoms'] as List<dynamic>? ?? [];
    return DoctorAppointment(
      id: json['id']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? '',
      patientName: json['patient_name'] as String?,
      patientPhone: json['patient_phone'] as String?,
      patientVillage: json['patient_village'] as String?,
      healthId: json['health_id'] as String?,
      facilityId: json['facility_id'] as String?,
      speciality: json['speciality'] as String?,
      queueNumber: json['queue_number'] is int
          ? json['queue_number'] as int
          : int.tryParse(json['queue_number']?.toString() ?? ''),
      status: json['status'] as String? ?? 'booked',
      doctorId: json['doctor_id'] as String?,
      notes: json['notes'] as String?,
      prescription: json['prescription'] as String?,
      diagnosis: json['diagnosis'] as String?,
      voiceNoteId: json['voice_note_id'] as String?,
      rawTranscript: json['raw_transcript'] as String?,
      translatedText: json['translated_text'] as String?,
      extractedSymptoms: rawSymptoms.map((e) => e.toString()).toList(),
      isEmergency: json['is_emergency'] == true ||
          json['is_emergency'] == 1 ||
          json['is_emergency'] == 'true',
      redFlagType: json['red_flag_type'] as String?,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

class DoctorFacility {
  final String id;
  final String name;
  final String level;
  final List<String> specialities;

  DoctorFacility({
    required this.id,
    required this.name,
    required this.level,
    this.specialities = const [],
  });

  factory DoctorFacility.fromJson(Map<String, dynamic> json) {
    final rawSpecs = json['specialities'] as List<dynamic>? ?? [];
    return DoctorFacility(
      id: json['id'] as String,
      name: json['name'] as String,
      level: json['level'] as String? ?? 'PHC',
      specialities: rawSpecs.map((e) => e.toString()).toList(),
    );
  }
}

class DoctorReferral {
  final String id;
  final String patientId;
  final String? patientName;
  final String? toFacilityId;
  final String? toFacilityName;
  final String? toDoctorName;
  final String? urgency;
  final String? reason;
  final String status;
  final DateTime createdAt;

  DoctorReferral({
    required this.id,
    required this.patientId,
    this.patientName,
    this.toFacilityId,
    this.toFacilityName,
    this.toDoctorName,
    this.urgency,
    this.reason,
    required this.status,
    required this.createdAt,
  });

  factory DoctorReferral.fromJson(Map<String, dynamic> json) {
    return DoctorReferral(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      patientName: json['patient_name'] as String?,
      toFacilityId: json['to_facility_id'] as String?,
      toFacilityName: json['to_facility_name'] as String?,
      toDoctorName: json['to_doctor_name'] as String?,
      urgency: json['urgency'] as String?,
      reason: json['reason'] as String?,
      status: json['status'] as String? ?? 'Created',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }
}

// -------------------------------------------------------------
// ASHA WORKER MODELS
// -------------------------------------------------------------

class AshaWorkerProfile {
  final String id;
  final String name;
  final String phone;
  final String? village;
  final String? assignedPhcId;

  AshaWorkerProfile({
    required this.id,
    required this.name,
    required this.phone,
    this.village,
    this.assignedPhcId,
  });

  factory AshaWorkerProfile.fromJson(Map<String, dynamic> json) {
    return AshaWorkerProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'ASHA Worker',
      phone: json['phone'] as String? ?? json['phone_number'] as String? ?? '',
      village: json['village'] as String?,
      assignedPhcId: json['assigned_phc_id'] as String? ?? json['facility_id'] as String?,
    );
  }
}

class AshaPatient {
  final String id;
  final String name;
  final String healthId;
  final String? village;
  final String? preferredLanguage;
  final String? phone;

  AshaPatient({
    required this.id,
    required this.name,
    required this.healthId,
    this.village,
    this.preferredLanguage,
    this.phone,
  });

  factory AshaPatient.fromJson(Map<String, dynamic> json) {
    return AshaPatient(
      id: json['id'] as String,
      name: json['name'] as String,
      healthId: json['health_id'] as String,
      village: json['village'] as String?,
      preferredLanguage: json['preferred_language'] as String?,
      phone: json['phone'] as String?,
    );
  }
}

class AshaEmergencyAlert {
  final String id;
  final String? callSessionId;
  final String? patientId;
  final String redFlagType;
  final String severity;
  final String status;
  final String? assignedAshaId;
  final String? notes;
  final String? patientName;
  final String? patientPhone;
  final String? patientVillage;
  final String? symptoms;
  final int? riskScore;
  final DateTime createdAt;

  AshaEmergencyAlert({
    required this.id,
    this.callSessionId,
    this.patientId,
    required this.redFlagType,
    required this.severity,
    required this.status,
    this.assignedAshaId,
    this.notes,
    this.patientName,
    this.patientPhone,
    this.patientVillage,
    this.symptoms,
    this.riskScore,
    required this.createdAt,
  });

  factory AshaEmergencyAlert.fromJson(Map<String, dynamic> json) {
    return AshaEmergencyAlert(
      id: json['id'] as String,
      callSessionId: json['call_session_id'] as String?,
      patientId: json['patient_id'] as String?,
      redFlagType: json['red_flag_type'] as String? ?? 'Red Flag Alert',
      severity: json['severity'] as String? ?? 'HIGH',
      status: json['status'] as String? ?? 'UNACKNOWLEDGED',
      assignedAshaId: json['assigned_asha_id'] as String?,
      notes: json['notes'] as String?,
      patientName: json['patient_name'] as String?,
      patientPhone: json['patient_phone'] as String?,
      patientVillage: json['patient_village'] as String?,
      symptoms: json['symptoms'] as String?,
      riskScore: json['risk_score'] != null ? (json['risk_score'] as num).toInt() : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }
}

class AshaFollowUp {
  final String id;
  final String ashaId;
  final String patientId;
  final String followUpType;
  final DateTime dueDate;
  final String status;
  final String? notes;

  AshaFollowUp({
    required this.id,
    required this.ashaId,
    required this.patientId,
    required this.followUpType,
    required this.dueDate,
    required this.status,
    this.notes,
  });

  factory AshaFollowUp.fromJson(Map<String, dynamic> json) {
    return AshaFollowUp(
      id: json['id'] as String,
      ashaId: json['asha_id'] as String,
      patientId: json['patient_id'] as String,
      followUpType: json['follow_up_type'] as String? ?? 'Check-in',
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : DateTime.now(),
      status: json['status'] as String? ?? 'pending',
      notes: json['notes'] as String?,
    );
  }
}

class FollowUpLastVisit {
  final bool hasVisit;
  final String? appointmentId;
  final String visitDate;
  final String doctorName;
  final String facilityName;
  final String speciality;
  final String status;
  final int queueNumber;
  final String diagnosis;
  final String prescription;
  final List<String> symptoms;
  final String clinicalNotes;

  FollowUpLastVisit({
    required this.hasVisit,
    this.appointmentId,
    required this.visitDate,
    required this.doctorName,
    required this.facilityName,
    required this.speciality,
    required this.status,
    required this.queueNumber,
    required this.diagnosis,
    required this.prescription,
    required this.symptoms,
    required this.clinicalNotes,
  });

  factory FollowUpLastVisit.fromJson(Map<String, dynamic> json) {
    final rawSymptoms = json['symptoms'] as List<dynamic>? ?? [];
    return FollowUpLastVisit(
      hasVisit: json['has_visit'] == true,
      appointmentId: json['appointment_id'] as String?,
      visitDate: json['visit_date'] as String? ?? 'Recent',
      doctorName: json['doctor_name'] as String? ?? 'Dr. Rajesh Sharma',
      facilityName: json['facility_name'] as String? ?? 'Primary Health Centre',
      speciality: json['speciality'] as String? ?? 'General Medicine',
      status: json['status'] as String? ?? 'completed',
      queueNumber: (json['queue_number'] as num?)?.toInt() ?? 1,
      diagnosis: json['diagnosis'] as String? ?? 'Clinical Assessment Completed',
      prescription: json['prescription'] as String? ?? 'Routine medication and rest.',
      symptoms: rawSymptoms.map((e) => e.toString()).toList(),
      clinicalNotes: json['clinical_notes'] as String? ?? '',
    );
  }
}

class FollowUpReferral {
  final bool hasReferral;
  final String? referralId;
  final String fromFacility;
  final String toFacility;
  final String urgency;
  final String reason;
  final String status;
  final String transportMode;
  final String createdAt;

  FollowUpReferral({
    required this.hasReferral,
    this.referralId,
    required this.fromFacility,
    required this.toFacility,
    required this.urgency,
    required this.reason,
    required this.status,
    required this.transportMode,
    required this.createdAt,
  });

  factory FollowUpReferral.fromJson(Map<String, dynamic> json) {
    return FollowUpReferral(
      hasReferral: json['has_referral'] == true,
      referralId: json['referral_id'] as String?,
      fromFacility: json['from_facility'] as String? ?? 'Primary Health Centre',
      toFacility: json['to_facility'] as String? ?? 'None',
      urgency: json['urgency'] as String? ?? 'ROUTINE',
      reason: json['reason'] as String? ?? 'Primary care management sufficient.',
      status: json['status'] as String? ?? 'not_required',
      transportMode: json['transport_mode'] as String? ?? 'Not Applicable',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class FollowUpWhatNext {
  final String title;
  final String category;
  final String priority;
  final String status;
  final String dueDate;
  final String dueLabel;
  final String carePathway;
  final String assignedAsha;
  final List<String> actions;
  final String guidanceNotes;
  final List<String> dangerSigns;

  FollowUpWhatNext({
    required this.title,
    required this.category,
    required this.priority,
    required this.status,
    required this.dueDate,
    required this.dueLabel,
    required this.carePathway,
    required this.assignedAsha,
    required this.actions,
    required this.guidanceNotes,
    required this.dangerSigns,
  });

  factory FollowUpWhatNext.fromJson(Map<String, dynamic> json) {
    final rawActions = json['actions'] as List<dynamic>? ?? [];
    final rawDangers = json['danger_signs'] as List<dynamic>? ?? [];
    return FollowUpWhatNext(
      title: json['title'] as String? ?? 'Community Follow-up Plan',
      category: json['category'] as String? ?? 'chronic',
      priority: json['priority'] as String? ?? 'NORMAL',
      status: json['status'] as String? ?? 'pending',
      dueDate: json['due_date'] as String? ?? '',
      dueLabel: json['due_label'] as String? ?? 'Pending',
      carePathway: json['care_pathway'] as String? ?? 'Routine Surveillance',
      assignedAsha: json['assigned_asha'] as String? ?? 'ASHA Worker',
      actions: rawActions.map((e) => e.toString()).toList(),
      guidanceNotes: json['guidance_notes'] as String? ?? '',
      dangerSigns: rawDangers.map((e) => e.toString()).toList(),
    );
  }
}

class PatientFollowUpDashboard {
  final AshaPatient patient;
  final FollowUpLastVisit lastVisit;
  final FollowUpReferral referral;
  final FollowUpWhatNext whatNext;

  PatientFollowUpDashboard({
    required this.patient,
    required this.lastVisit,
    required this.referral,
    required this.whatNext,
  });

  factory PatientFollowUpDashboard.fromJson(Map<String, dynamic> json) {
    return PatientFollowUpDashboard(
      patient: AshaPatient.fromJson(json['patient'] as Map<String, dynamic>),
      lastVisit: FollowUpLastVisit.fromJson(json['last_visit'] as Map<String, dynamic>),
      referral: FollowUpReferral.fromJson(json['referral'] as Map<String, dynamic>),
      whatNext: FollowUpWhatNext.fromJson(json['what_next'] as Map<String, dynamic>),
    );
  }
}

// -------------------------------------------------------------
// PATIENT MODELS
// -------------------------------------------------------------

class PatientProfile {
  final String id;
  final String? name;
  final String? healthId;
  final String? preferredLanguage;
  final String? village;

  PatientProfile({
    required this.id,
    this.name,
    this.healthId,
    this.preferredLanguage,
    this.village,
  });

  factory PatientProfile.fromJson(Map<String, dynamic> json) {
    return PatientProfile(
      id: json['id'] as String,
      name: json['name'] as String?,
      healthId: json['health_id'] as String?,
      preferredLanguage: json['preferred_language'] as String?,
      village: json['village'] as String?,
    );
  }

  String get displayName => (name != null && name!.trim().isNotEmpty) ? name! : 'Patient';
}

class PatientAppointment {
  final String id;
  final String? facilityId;
  final String? speciality;
  final int? queueNumber;
  final DateTime? scheduledTime;
  final String status;
  final String source;
  final String? prescription;
  final String? diagnosis;
  final String? doctorNotes;
  final DateTime createdAt;

  PatientAppointment({
    required this.id,
    this.facilityId,
    this.speciality,
    this.queueNumber,
    this.scheduledTime,
    required this.status,
    required this.source,
    this.prescription,
    this.diagnosis,
    this.doctorNotes,
    required this.createdAt,
  });

  factory PatientAppointment.fromJson(Map<String, dynamic> json) {
    return PatientAppointment(
      id: json['id']?.toString() ?? '',
      facilityId: json['facility_id'] as String?,
      speciality: json['speciality'] as String?,
      queueNumber: json['queue_number'] is int
          ? json['queue_number'] as int
          : int.tryParse(json['queue_number']?.toString() ?? ''),
      scheduledTime: json['scheduled_time'] != null
          ? DateTime.tryParse(json['scheduled_time'].toString())
          : null,
      status: json['status'] as String? ?? 'booked',
      source: json['source'] as String? ?? 'voice',
      prescription: json['prescription'] as String?,
      diagnosis: json['diagnosis'] as String?,
      doctorNotes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

class PatientReferral {
  final String id;
  final String? fromFacilityId;
  final String? toFacilityId;
  final String? reason;
  final String status;
  final DateTime createdAt;

  PatientReferral({
    required this.id,
    this.fromFacilityId,
    this.toFacilityId,
    this.reason,
    required this.status,
    required this.createdAt,
  });

  factory PatientReferral.fromJson(Map<String, dynamic> json) {
    return PatientReferral(
      id: json['id'] as String,
      fromFacilityId: json['from_facility_id'] as String?,
      toFacilityId: json['to_facility_id'] as String?,
      reason: json['reason'] as String?,
      status: json['status'] as String? ?? 'Created',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }
}

// -------------------------------------------------------------
// CLINICAL VOICE RESULT
// -------------------------------------------------------------

class ClinicalVoiceResult {
  final String detectedLanguage;
  final String rawTranscript;
  final String englishTranscript;
  final List<String> extractedSymptoms;
  final bool emergencyFlag;
  final String? emergencyReason;
  final String triageUrgency;
  final String suggestedSpecialty;

  ClinicalVoiceResult({
    required this.detectedLanguage,
    required this.rawTranscript,
    required this.englishTranscript,
    required this.extractedSymptoms,
    required this.emergencyFlag,
    this.emergencyReason,
    required this.triageUrgency,
    required this.suggestedSpecialty,
  });

  factory ClinicalVoiceResult.fromJson(Map<String, dynamic> json) {
    final rawSyms = (json['standardized_symptoms'] ?? json['extracted_symptoms']) as List<dynamic>? ?? [];
    final symsList = rawSyms.map((e) => e.toString()).toList();

    final emObj = json['emergency'] as Map<String, dynamic>?;
    final bool isEmergency = emObj != null
        ? (emObj['is_emergency'] as bool? ?? false)
        : (json['emergency_flag'] as bool? ?? false);
    final String? emReason = emObj != null
        ? (emObj['red_flag_type'] as String? ?? emObj['matched_symptom'] as String?)
        : (json['emergency_reason'] as String?);

    final triage = json['triage_level'] as String? ?? json['triage_urgency'] as String? ?? (isEmergency ? 'EMERGENCY' : 'ROUTINE');

    String specialty = json['suggested_specialty'] as String? ?? 'General Medicine';
    final allText = '${json['translated_text'] ?? ''} ${symsList.join(' ')}'.toLowerCase();
    if (allText.contains('chest') || allText.contains('heart') || allText.contains('cardiac')) {
      specialty = 'Cardiology';
    } else if (allText.contains('breath') || allText.contains('cough') || allText.contains('lung')) {
      specialty = 'Pulmonology';
    } else if (allText.contains('stomach') || allText.contains('vomit') || allText.contains('abdomen')) {
      specialty = 'Gastroenterology';
    }

    return ClinicalVoiceResult(
      detectedLanguage: json['detected_language'] as String? ?? 'hi-IN',
      rawTranscript: json['raw_transcript'] as String? ?? '',
      englishTranscript: json['translated_text'] as String? ?? json['english_transcript'] as String? ?? '',
      extractedSymptoms: symsList,
      emergencyFlag: isEmergency,
      emergencyReason: emReason,
      triageUrgency: triage,
      suggestedSpecialty: specialty,
    );
  }
}

// -------------------------------------------------------------
// ADMIN MODELS
// -------------------------------------------------------------

class AdminDoctorRecord {
  final String id;
  final String name;
  final String username;
  final String role;
  final String? phone;
  final String? speciality;
  final String? facilityId;
  final String facilityName;
  final int appointmentCount;
  final bool isActive;
  final DateTime createdAt;

  AdminDoctorRecord({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    this.phone,
    this.speciality,
    this.facilityId,
    required this.facilityName,
    this.appointmentCount = 0,
    required this.isActive,
    required this.createdAt,
  });

  factory AdminDoctorRecord.fromJson(Map<String, dynamic> json) {
    return AdminDoctorRecord(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Doctor',
      username: json['username'] as String? ?? '',
      role: json['role'] as String? ?? 'doctor',
      phone: json['phone'] as String?,
      speciality: json['speciality'] as String? ?? 'General Medicine',
      facilityId: json['facility_id'] as String?,
      facilityName: json['facility_name'] as String? ?? 'District Hospital',
      appointmentCount: json['appointment_count'] is int
          ? json['appointment_count'] as int
          : int.tryParse(json['appointment_count']?.toString() ?? '0') ?? 0,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

class AdminAshaRecord {
  final String id;
  final String name;
  final String phone;
  final String? facilityId;
  final String facilityName;
  final String? areaId;
  final String village;
  final String status;

  AdminAshaRecord({
    required this.id,
    required this.name,
    required this.phone,
    this.facilityId,
    required this.facilityName,
    this.areaId,
    required this.village,
    required this.status,
  });

  factory AdminAshaRecord.fromJson(Map<String, dynamic> json) {
    return AdminAshaRecord(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? 'ASHA Worker',
      phone: json['phone'] as String? ?? '',
      facilityId: json['facility_id'] as String?,
      facilityName: json['facility_name'] as String? ?? 'Primary Health Centre',
      areaId: json['area_id'] as String?,
      village: json['village'] as String? ?? json['area_id'] as String? ?? 'Village Area',
      status: json['status'] as String? ?? 'active',
    );
  }
}

class AdminAnalyticsReport {
  final Map<String, int> kpis;
  final Map<String, int> specialtyDistribution;
  final List<Map<String, dynamic>> facilityStats;
  final List<Map<String, dynamic>> villageCoverage;
  final List<Map<String, dynamic>> activityLog;

  AdminAnalyticsReport({
    required this.kpis,
    required this.specialtyDistribution,
    required this.facilityStats,
    required this.villageCoverage,
    required this.activityLog,
  });

  factory AdminAnalyticsReport.fromJson(Map<String, dynamic> json) {
    final rawKpis = json['kpis'] as Map<String, dynamic>? ?? {};
    final kpis = rawKpis.map((k, v) => MapEntry(k, (v is int ? v : int.tryParse(v.toString()) ?? 0)));

    final rawSpecs = json['specialty_distribution'] as Map<String, dynamic>? ?? {};
    final specs = rawSpecs.map((k, v) => MapEntry(k, (v is int ? v : int.tryParse(v.toString()) ?? 0)));

    final rawFacs = (json['facility_stats'] as List<dynamic>?) ?? [];
    final facs = rawFacs.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final rawVills = (json['village_coverage'] as List<dynamic>?) ?? [];
    final vills = rawVills.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final rawActs = (json['activity_log'] as List<dynamic>?) ?? [];
    final acts = rawActs.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return AdminAnalyticsReport(
      kpis: kpis,
      specialtyDistribution: specs,
      facilityStats: facs,
      villageCoverage: vills,
      activityLog: acts,
    );
  }
}

// -------------------------------------------------------------
// PHC ADMINISTRATION & QUALITY MODELS
// -------------------------------------------------------------

class PHCQualityDashboard {
  final String facilityId;
  final String facilityName;
  final int avgWaitingTimeMinutes;
  final int completedReferrals;
  final int pendingReferrals;
  final double referralRatePercent;
  final int completedFollowups;
  final int totalFollowups;
  final double followupRatePercent;
  final double noShowRatePercent;
  final int stockoutCount;
  final List<String> stockoutItems;
  final int lowStockCount;
  final List<String> lowStockItems;
  final int availableMedCount;
  final int diagAvailable;
  final int diagUnavailable;
  final int completedConsultations;
  final int activeConsultations;
  final int emergencyCount;
  final Map<String, dynamic> serviceTrends;

  PHCQualityDashboard({
    required this.facilityId,
    required this.facilityName,
    required this.avgWaitingTimeMinutes,
    required this.completedReferrals,
    required this.pendingReferrals,
    required this.referralRatePercent,
    required this.completedFollowups,
    required this.totalFollowups,
    required this.followupRatePercent,
    required this.noShowRatePercent,
    required this.stockoutCount,
    required this.stockoutItems,
    required this.lowStockCount,
    required this.lowStockItems,
    required this.availableMedCount,
    required this.diagAvailable,
    required this.diagUnavailable,
    required this.completedConsultations,
    required this.activeConsultations,
    required this.emergencyCount,
    required this.serviceTrends,
  });

  factory PHCQualityDashboard.fromJson(Map<String, dynamic> json) {
    final kpis = json['kpis'] as Map<String, dynamic>? ?? {};
    final refs = kpis['referrals'] as Map<String, dynamic>? ?? {};
    final fus = kpis['followups'] as Map<String, dynamic>? ?? {};
    final meds = kpis['medicine_stockout'] as Map<String, dynamic>? ?? {};
    final diags = kpis['diagnostic_services'] as Map<String, dynamic>? ?? {};
    final docs = kpis['doctor_activity'] as Map<String, dynamic>? ?? {};

    return PHCQualityDashboard(
      facilityId: json['facility_id'] as String? ?? 'fac-phc-001',
      facilityName: json['facility_name'] as String? ?? 'Shivaji Nagar PHC',
      avgWaitingTimeMinutes: (kpis['avg_waiting_time_minutes'] as num?)?.toInt() ?? 24,
      completedReferrals: (refs['completed'] as num?)?.toInt() ?? 1,
      pendingReferrals: (refs['pending'] as num?)?.toInt() ?? 1,
      referralRatePercent: (refs['rate_percent'] as num?)?.toDouble() ?? 50.0,
      completedFollowups: (fus['completed'] as num?)?.toInt() ?? 1,
      totalFollowups: (fus['total'] as num?)?.toInt() ?? 3,
      followupRatePercent: (fus['rate_percent'] as num?)?.toDouble() ?? 33.3,
      noShowRatePercent: (kpis['no_show_rate_percent'] as num?)?.toDouble() ?? 8.0,
      stockoutCount: (meds['stockout_count'] as num?)?.toInt() ?? 2,
      stockoutItems: (meds['stockout_items'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      lowStockCount: (meds['low_stock_count'] as num?)?.toInt() ?? 2,
      lowStockItems: (meds['low_stock_items'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      availableMedCount: (meds['available_count'] as num?)?.toInt() ?? 3,
      diagAvailable: (diags['available'] as num?)?.toInt() ?? 6,
      diagUnavailable: (diags['unavailable'] as num?)?.toInt() ?? 2,
      completedConsultations: (docs['completed_consultations'] as num?)?.toInt() ?? 1,
      activeConsultations: (docs['in_queue_or_active'] as num?)?.toInt() ?? 1,
      emergencyCount: (kpis['emergency_escalations_count'] as num?)?.toInt() ?? 1,
      serviceTrends: json['service_volume_trends'] as Map<String, dynamic>? ?? {},
    );
  }
}

// -------------------------------------------------------------
// PHARMACY MODELS
// -------------------------------------------------------------

class PharmacyPrescriptionOrder {
  final String id;
  final String? caseId;
  final String patientName;
  final String healthId;
  final String doctorName;
  final List<Map<String, dynamic>> medicines;
  final String? instructions;
  final String status;
  final String? dispensedAt;
  final String? createdAt;

  PharmacyPrescriptionOrder({
    required this.id,
    this.caseId,
    required this.patientName,
    required this.healthId,
    required this.doctorName,
    required this.medicines,
    this.instructions,
    required this.status,
    this.dispensedAt,
    this.createdAt,
  });

  factory PharmacyPrescriptionOrder.fromJson(Map<String, dynamic> json) {
    final rawMeds = (json['medicines'] as List<dynamic>?) ?? [];
    final meds = rawMeds.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return PharmacyPrescriptionOrder(
      id: json['id'] as String,
      caseId: json['case_id'] as String?,
      patientName: json['patient_name'] as String? ?? 'Patient',
      healthId: json['health_id'] as String? ?? 'HID-UNKNOWN',
      doctorName: json['doctor_name'] as String? ?? 'Doctor',
      medicines: meds,
      instructions: json['instructions'] as String?,
      status: json['status'] as String? ?? 'pending',
      dispensedAt: json['dispensed_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

class PharmacyMedicineItem {
  final String id;
  final String facilityId;
  final String medicineName;
  final int stockQuantity;
  final String unit;
  final int minThreshold;
  final String status; // available, low_stock, out_of_stock

  PharmacyMedicineItem({
    required this.id,
    required this.facilityId,
    required this.medicineName,
    required this.stockQuantity,
    required this.unit,
    required this.minThreshold,
    required this.status,
  });

  factory PharmacyMedicineItem.fromJson(Map<String, dynamic> json) {
    return PharmacyMedicineItem(
      id: json['id'] as String,
      facilityId: json['facility_id'] as String? ?? 'fac-phc-001',
      medicineName: json['medicine_name'] as String,
      stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
      unit: json['unit'] as String? ?? 'tablets',
      minThreshold: (json['min_threshold'] as num?)?.toInt() ?? 20,
      status: json['status'] as String? ?? 'available',
    );
  }
}

// -------------------------------------------------------------
// LABORATORY MODELS
// -------------------------------------------------------------

class LabTestOrder {
  final String id;
  final String? caseId;
  final String patientName;
  final String healthId;
  final String doctorName;
  final String testType;
  final String status; // pending, sample_collected, result_uploaded
  final String? resultRef;
  final String? resultSummary;
  final String? sampleCollectedAt;
  final String? completedAt;

  LabTestOrder({
    required this.id,
    this.caseId,
    required this.patientName,
    required this.healthId,
    required this.doctorName,
    required this.testType,
    required this.status,
    this.resultRef,
    this.resultSummary,
    this.sampleCollectedAt,
    this.completedAt,
  });

  factory LabTestOrder.fromJson(Map<String, dynamic> json) {
    return LabTestOrder(
      id: json['id'] as String,
      caseId: json['case_id'] as String?,
      patientName: json['patient_name'] as String? ?? 'Patient',
      healthId: json['health_id'] as String? ?? 'HID-UNKNOWN',
      doctorName: json['doctor_name'] as String? ?? 'Doctor',
      testType: json['test_type'] as String? ?? 'Diagnostic Test',
      status: json['status'] as String? ?? 'pending',
      resultRef: json['result_ref'] as String?,
      resultSummary: json['result_summary'] as String?,
      sampleCollectedAt: json['sample_collected_at'] as String?,
      completedAt: json['completed_at'] as String?,
    );
  }
}


