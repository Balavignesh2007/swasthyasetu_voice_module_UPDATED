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

class LoginResult {
  final String accessToken;
  final DoctorProfile doctor;

  LoginResult({required this.accessToken, required this.doctor});

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      accessToken: json['access_token'] as String,
      doctor: DoctorProfile.fromJson(json['doctor'] as Map<String, dynamic>),
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
  final String redFlagType;
  final String severity;
  final String status;
  final String? assignedAshaId;
  final DateTime createdAt;

  DoctorEmergencyEvent({
    required this.id,
    this.patientId,
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
      redFlagType: json['red_flag_type'] as String,
      severity: json['severity'] as String? ?? 'HIGH',
      status: json['status'] as String? ?? 'UNACKNOWLEDGED',
      assignedAshaId: json['assigned_asha_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class DoctorReferral {
  final String id;
  final String patientId;
  final String? toFacilityId;
  final String status;
  final DateTime createdAt;

  DoctorReferral({
    required this.id,
    required this.patientId,
    this.toFacilityId,
    required this.status,
    required this.createdAt,
  });

  factory DoctorReferral.fromJson(Map<String, dynamic> json) {
    return DoctorReferral(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      toFacilityId: json['to_facility_id'] as String?,
      status: json['status'] as String? ?? 'Created',
      createdAt: DateTime.parse(json['created_at'] as String),
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
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      patientName: json['patient_name'] as String?,
      patientPhone: json['patient_phone'] as String?,
      patientVillage: json['patient_village'] as String?,
      healthId: json['health_id'] as String?,
      facilityId: json['facility_id'] as String?,
      speciality: json['speciality'] as String?,
      queueNumber: json['queue_number'] as int?,
      status: json['status'] as String? ?? 'booked',
      doctorId: json['doctor_id'] as String?,
      notes: json['notes'] as String?,
      prescription: json['prescription'] as String?,
      diagnosis: json['diagnosis'] as String?,
      voiceNoteId: json['voice_note_id'] as String?,
      rawTranscript: json['raw_transcript'] as String?,
      translatedText: json['translated_text'] as String?,
      extractedSymptoms: rawSymptoms.map((e) => e.toString()).toList(),
      isEmergency: json['is_emergency'] as bool? ?? false,
      redFlagType: json['red_flag_type'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
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
