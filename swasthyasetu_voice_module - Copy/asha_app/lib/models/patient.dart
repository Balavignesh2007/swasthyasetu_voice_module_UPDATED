class AshaPatient {
  final String id;
  final String? name;
  final String? healthId;
  final String? village;
  final String? preferredLanguage;

  AshaPatient({
    required this.id,
    this.name,
    this.healthId,
    this.village,
    this.preferredLanguage,
  });

  factory AshaPatient.fromJson(Map<String, dynamic> json) {
    return AshaPatient(
      id: json['id'] as String,
      name: json['name'] as String?,
      healthId: json['health_id'] as String?,
      village: json['village'] as String?,
      preferredLanguage: json['preferred_language'] as String?,
    );
  }

  String get displayName => (name != null && name!.trim().isNotEmpty) ? name! : 'Unnamed patient';
}

class AshaWorkerProfile {
  final String id;
  final String name;
  final String? facilityId;
  final String? areaId;

  AshaWorkerProfile({
    required this.id,
    required this.name,
    this.facilityId,
    this.areaId,
  });

  factory AshaWorkerProfile.fromJson(Map<String, dynamic> json) {
    return AshaWorkerProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      facilityId: json['facility_id'] as String?,
      areaId: json['area_id'] as String?,
    );
  }
}
