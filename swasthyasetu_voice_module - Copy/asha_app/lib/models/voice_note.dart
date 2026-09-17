import 'dart:convert';

class VoiceNote {
  final String id;
  final String? patientId;
  final String? ashaId;
  final String? doctorId;
  final String authorRole;
  final String rawTranscript;
  final String? translatedText;
  final String language;
  final List<String> extractedSymptoms;
  final List<String> confirmedSymptoms;
  final bool isEmergency;
  final String? redFlagType;
  final String? clinicalSummary;
  final String syncStatus;
  final DateTime createdAt;

  VoiceNote({
    required this.id,
    this.patientId,
    this.ashaId,
    this.doctorId,
    required this.authorRole,
    required this.rawTranscript,
    this.translatedText,
    required this.language,
    required this.extractedSymptoms,
    required this.confirmedSymptoms,
    required this.isEmergency,
    this.redFlagType,
    this.clinicalSummary,
    required this.syncStatus,
    required this.createdAt,
  });

  factory VoiceNote.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => e.toString()).toList();
      if (val is String) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is List) return decoded.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return [];
    }

    return VoiceNote(
      id: json['id'] as String? ?? '',
      patientId: json['patient_id'] as String?,
      ashaId: json['asha_id'] as String?,
      doctorId: json['doctor_id'] as String?,
      authorRole: json['author_role'] as String? ?? 'asha',
      rawTranscript: json['raw_transcript'] as String? ?? '',
      translatedText: json['translated_text'] as String?,
      language: json['language'] as String? ?? 'en',
      extractedSymptoms: parseList(json['extracted_symptoms']),
      confirmedSymptoms: parseList(json['confirmed_symptoms']),
      isEmergency: json['is_emergency'] as bool? ?? false,
      redFlagType: json['red_flag_type'] as String?,
      clinicalSummary: json['clinical_summary'] as String?,
      syncStatus: json['sync_status'] as String? ?? 'synced',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patient_id': patientId,
        'asha_id': ashaId,
        'doctor_id': doctorId,
        'author_role': authorRole,
        'raw_transcript': rawTranscript,
        'translated_text': translatedText,
        'language': language,
        'extracted_symptoms': jsonEncode(extractedSymptoms),
        'confirmed_symptoms': jsonEncode(confirmedSymptoms),
        'is_emergency': isEmergency,
        'red_flag_type': redFlagType,
        'clinical_summary': clinicalSummary,
        'sync_status': syncStatus,
        'created_at': createdAt.toIso8601String(),
      };
}
