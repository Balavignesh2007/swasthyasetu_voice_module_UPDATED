class ExtractedEntity {
  final String entity;
  final String label;
  final String? normalized;
  final double confidence;

  ExtractedEntity({
    required this.entity,
    required this.label,
    this.normalized,
    required this.confidence,
  });

  factory ExtractedEntity.fromJson(Map<String, dynamic> json) {
    return ExtractedEntity(
      entity: json['entity'] as String? ?? '',
      label: json['label'] as String? ?? '',
      normalized: json['normalized'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'entity': entity,
        'label': label,
        'normalized': normalized,
        'confidence': confidence,
      };
}

class EmergencyScreenResult {
  final bool isEmergency;
  final String? redFlagType;
  final String? matchedSymptom;

  EmergencyScreenResult({
    required this.isEmergency,
    this.redFlagType,
    this.matchedSymptom,
  });

  factory EmergencyScreenResult.fromJson(Map<String, dynamic> json) {
    return EmergencyScreenResult(
      isEmergency: json['is_emergency'] as bool? ?? false,
      redFlagType: json['red_flag_type'] as String?,
      matchedSymptom: json['matched_symptom'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'is_emergency': isEmergency,
        'red_flag_type': redFlagType,
        'matched_symptom': matchedSymptom,
      };
}

class ClinicalVoiceResult {
  final String rawTranscript;
  final String detectedLanguage;
  final String translatedText;
  final String normalizedText;
  final List<ExtractedEntity> extractedEntities;
  final List<String> standardizedSymptoms;
  final EmergencyScreenResult emergency;
  final String? triageLevel;
  final double? triageProbability;
  final String? suggestedAction;

  ClinicalVoiceResult({
    required this.rawTranscript,
    required this.detectedLanguage,
    required this.translatedText,
    required this.normalizedText,
    required this.extractedEntities,
    required this.standardizedSymptoms,
    required this.emergency,
    this.triageLevel,
    this.triageProbability,
    this.suggestedAction,
  });

  factory ClinicalVoiceResult.fromJson(Map<String, dynamic> json) {
    final rawEntities = json['extracted_entities'] as List<dynamic>? ?? [];
    final rawSymptoms = json['standardized_symptoms'] as List<dynamic>? ?? [];

    return ClinicalVoiceResult(
      rawTranscript: json['raw_transcript'] as String? ?? '',
      detectedLanguage: json['detected_language'] as String? ?? 'en',
      translatedText: json['translated_text'] as String? ?? '',
      normalizedText: json['normalized_text'] as String? ?? '',
      extractedEntities: rawEntities
          .map((e) => ExtractedEntity.fromJson(e as Map<String, dynamic>))
          .toList(),
      standardizedSymptoms: rawSymptoms.map((e) => e.toString()).toList(),
      emergency: EmergencyScreenResult.fromJson(
        json['emergency'] as Map<String, dynamic>? ?? {},
      ),
      triageLevel: json['triage_level'] as String?,
      triageProbability: (json['triage_probability'] as num?)?.toDouble(),
      suggestedAction: json['suggested_action'] as String?,
    );
  }
}
