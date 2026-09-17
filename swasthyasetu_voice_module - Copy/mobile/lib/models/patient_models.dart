class PatientProfile {
  final String id;
  final String? name;
  final String? healthId;
  final String? preferredLanguage;

  PatientProfile({required this.id, this.name, this.healthId, this.preferredLanguage});

  factory PatientProfile.fromJson(Map<String, dynamic> json) {
    return PatientProfile(
      id: json['id'] as String,
      name: json['name'] as String?,
      healthId: json['health_id'] as String?,
      preferredLanguage: json['preferred_language'] as String?,
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
  final DateTime createdAt;

  PatientAppointment({
    required this.id,
    this.facilityId,
    this.speciality,
    this.queueNumber,
    this.scheduledTime,
    required this.status,
    required this.source,
    required this.createdAt,
  });

  factory PatientAppointment.fromJson(Map<String, dynamic> json) {
    return PatientAppointment(
      id: json['id'] as String,
      facilityId: json['facility_id'] as String?,
      speciality: json['speciality'] as String?,
      queueNumber: json['queue_number'] as int?,
      scheduledTime: json['scheduled_time'] != null ? DateTime.tryParse(json['scheduled_time']) : null,
      status: json['status'] as String? ?? 'booked',
      source: json['source'] as String? ?? 'voice',
      createdAt: DateTime.parse(json['created_at'] as String),
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
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class VoiceHistoryEntry {
  final String id;
  final String callSessionId;
  final String interactionType;
  final String inputType;
  final String? transcript;
  final String? language;
  final DateTime createdAt;

  VoiceHistoryEntry({
    required this.id,
    required this.callSessionId,
    required this.interactionType,
    required this.inputType,
    this.transcript,
    this.language,
    required this.createdAt,
  });

  factory VoiceHistoryEntry.fromJson(Map<String, dynamic> json) {
    return VoiceHistoryEntry(
      id: json['id'] as String,
      callSessionId: json['call_session_id'] as String,
      interactionType: json['interaction_type'] as String,
      inputType: json['input_type'] as String,
      transcript: json['transcript'] as String?,
      language: json['language'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
