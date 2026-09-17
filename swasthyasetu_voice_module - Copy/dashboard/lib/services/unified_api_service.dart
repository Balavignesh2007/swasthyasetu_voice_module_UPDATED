import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/unified_models.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class UnifiedApiService {
  final String? _explicitBaseUrl;
  final http.Client _client;
  String? authToken;

  String get baseUrl => _explicitBaseUrl ?? AppConfig.apiBaseUrl;

  UnifiedApiService({String? baseUrl, http.Client? client})
      : _explicitBaseUrl = baseUrl,
        _client = client ?? http.Client();

  void dispose() {
    _client.close();
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Uri getAlertsWebSocketUri() {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    if (cleanBase.startsWith('https://')) {
      return Uri.parse('wss://${cleanBase.substring(8)}/ws/alerts');
    } else if (cleanBase.startsWith('http://')) {
      return Uri.parse('ws://${cleanBase.substring(7)}/ws/alerts');
    }
    return Uri.parse('$cleanBase/ws/alerts');
  }

  Map<String, String> get _headers {
    final map = <String, String>{'Content-Type': 'application/json'};
    if (authToken != null && authToken!.isNotEmpty) {
      map['Authorization'] = 'Bearer $authToken';
    }
    return map;
  }

  dynamic _decodeOrThrow(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    String message = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }
    } catch (_) {}
    throw ApiException(response.statusCode, message);
  }

  // =============================================================
  // AUTHENTICATION & SESSIONS
  // =============================================================

  Future<UnifiedUserSession> doctorLogin(String username, String password) async {
    final response = await _client.post(
      _uri('/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username.trim(), 'password': password}),
    );
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    final token = data['access_token'] as String;
    final doctor = DoctorProfile.fromJson(data['doctor'] as Map<String, dynamic>);
    authToken = token;

    return UnifiedUserSession(
      role: UserRole.doctor,
      id: doctor.id,
      name: doctor.name,
      identifier: doctor.username,
      token: token,
      extra: {
        'speciality': doctor.speciality,
        'facility_id': doctor.facilityId,
        'role': doctor.role,
      },
    );
  }

  Future<UnifiedUserSession> ashaLogin(String phone) async {
    final response = await _client.get(
      _uri('/api/v1/asha/lookup', {'phone': phone.trim()}),
      headers: {'Content-Type': 'application/json'},
    );
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    final asha = AshaWorkerProfile.fromJson(data);

    return UnifiedUserSession(
      role: UserRole.asha,
      id: asha.id,
      name: asha.name,
      identifier: asha.phone.isNotEmpty ? asha.phone : phone.trim(),
      extra: {
        'village': asha.village,
        'assigned_phc_id': asha.assignedPhcId,
      },
    );
  }

  Future<UnifiedUserSession> patientLogin(String phone, String healthId) async {
    final response = await _client.get(
      _uri('/api/v1/patients/login', {
        'caller_phone': phone.trim(),
        'health_id': healthId.trim(),
      }),
      headers: {'Content-Type': 'application/json'},
    );
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    final patient = PatientProfile.fromJson(data);

    return UnifiedUserSession(
      role: UserRole.patient,
      id: patient.id,
      name: patient.displayName,
      identifier: patient.healthId ?? phone.trim(),
      extra: {
        'phone': phone.trim(),
        'preferred_language': patient.preferredLanguage,
        'village': patient.village,
      },
    );
  }

  // =============================================================
  // DOCTOR PORTAL APIS
  // =============================================================

  Future<DashboardStats> fetchDoctorStats() async {
    try {
      final response = await _client.get(_uri('/api/v1/admin/dashboard'), headers: _headers);
      final data = _decodeOrThrow(response) as Map<String, dynamic>;
      return DashboardStats.fromJson(data);
    } catch (_) {
      final response = await _client.get(_uri('/api/v1/admin/stats'), headers: _headers);
      final data = _decodeOrThrow(response) as Map<String, dynamic>;
      return DashboardStats.fromJson(data);
    }
  }

  Future<List<DoctorEmergencyEvent>> fetchDoctorAlerts() async {
    final response = await _client.get(_uri('/api/v1/admin/alerts'), headers: _headers);
    final list = _decodeOrThrow(response) as List<dynamic>;
    return list.map((e) => DoctorEmergencyEvent.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> acknowledgeDoctorAlert(String alertId) async {
    await _client.post(
      _uri('/api/v1/admin/alerts//ack'),
      headers: _headers,
    );
  }

  Future<void> escalatePatientEmergency({
    required String patientId,
    required String redFlagType,
    String? symptoms,
    String? severity,
  }) async {
    await _client.post(
      _uri('/api/v1/patients//escalate-emergency'),
      headers: _headers,
      body: jsonEncode({
        'red_flag_type': redFlagType,
        'symptoms': symptoms,
        'severity': severity ?? 'HIGH',
      }),
    );
  }

  Future<List<DoctorAppointment>> fetchDoctorAppointments() async {
    final response = await _client.get(_uri('/api/v1/admin/appointments'), headers: _headers);
    final list = _decodeOrThrow(response) as List<dynamic>;
    return list.map((e) => DoctorAppointment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> addPrescription({
    required String appointmentId,
    required String prescription,
    String? diagnosis,
    String? notes,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/admin/appointments/$appointmentId/prescribe'),
      headers: _headers,
      body: jsonEncode({
        'prescription': prescription,
        'diagnosis': diagnosis,
        'notes': notes,
      }),
    );
    _decodeOrThrow(response);
  }

  Future<void> createReferral({
    required String patientId,
    required String toFacilityId,
    String? urgency,
    String? reason,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/admin/referrals'),
      headers: _headers,
      body: jsonEncode({
        'patient_id': patientId,
        'to_facility_id': toFacilityId,
        'urgency': urgency ?? 'ROUTINE',
        'reason': reason,
      }),
    );
    _decodeOrThrow(response);
  }

  Future<List<DoctorFacility>> fetchFacilities() async {
    final response = await _client.get(_uri('/api/v1/admin/facilities'), headers: _headers);
    final list = _decodeOrThrow(response) as List<dynamic>;
    return list.map((e) => DoctorFacility.fromJson(e as Map<String, dynamic>)).toList();
  }

  // =============================================================
  // ASHA WORKER PORTAL APIS
  // =============================================================

  Future<List<AshaPatient>> fetchAshaPatients({String? ashaId}) async {
    final query = ashaId != null ? {'asha_id': ashaId} : null;
    final response = await _client.get(_uri('/api/v1/asha/patients', query), headers: _headers);
    final list = _decodeOrThrow(response) as List<dynamic>;
    return list.map((e) => AshaPatient.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AshaEmergencyAlert>> fetchAshaAlerts({String? ashaId}) async {
    final query = ashaId != null ? {'asha_id': ashaId} : null;
    final response = await _client.get(_uri('/api/v1/asha/alerts', query), headers: _headers);
    final list = _decodeOrThrow(response) as List<dynamic>;
    return list.map((e) => AshaEmergencyAlert.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> ackAshaAlert(String alertId, {String? notes}) async {
    final response = await _client.post(
      _uri('/api/v1/asha/alerts/$alertId/ack'),
      headers: _headers,
      body: jsonEncode({'notes': notes}),
    );
    _decodeOrThrow(response);
  }

  Future<void> resolveAshaAlert(String alertId, {required String resolutionNotes}) async {
    final response = await _client.post(
      _uri('/api/v1/asha/alerts/$alertId/resolve'),
      headers: _headers,
      body: jsonEncode({'resolution_summary': resolutionNotes}),
    );
    _decodeOrThrow(response);
  }

  Future<List<AshaFollowUp>> fetchAshaFollowUps(String ashaId) async {
    final response = await _client.get(_uri('/api/v1/asha/follow-ups', {'asha_id': ashaId}), headers: _headers);
    final list = _decodeOrThrow(response) as List<dynamic>;
    return list.map((e) => AshaFollowUp.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PatientFollowUpDashboard> fetchPatientFollowUpDashboard(String patientId) async {
    final response = await _client.get(_uri('/api/v1/patients/$patientId/followup-dashboard'), headers: _headers);
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    return PatientFollowUpDashboard.fromJson(data);
  }

  Future<Map<String, dynamic>> recordPatientFollowUpVisit({
    required String patientId,
    String? notes,
    Map<String, dynamic>? vitals,
    String? status,
    String? medicationAdherence,
    int? nextDueDays,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/patients/$patientId/record-followup'),
      headers: _headers,
      body: jsonEncode({
        'notes': notes,
        'vitals': vitals,
        'status': status ?? 'completed',
        'medication_adherence': medicationAdherence ?? 'Adherent',
        'next_due_days': nextDueDays ?? 7,
      }),
    );
    return _decodeOrThrow(response) as Map<String, dynamic>;
  }

  Future<ClinicalVoiceResult> processClinicalVoice({
    required String text,
    String? language,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/clinical/process-voice'),
      headers: _headers,
      body: jsonEncode({
        'transcript': text,
        'language': language ?? 'hi-IN',
      }),
    );
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    return ClinicalVoiceResult.fromJson(data);
  }

  Future<Map<String, dynamic>> saveAshaVoiceNote({
    required String ashaId,
    required String patientId,
    required ClinicalVoiceResult result,
    String? audioUrl,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/asha/voice-notes'),
      headers: _headers,
      body: jsonEncode({
        'asha_id': ashaId,
        'patient_id': patientId,
        'audio_url': audioUrl ?? 'web_mic_input.wav',
        'raw_transcript': result.rawTranscript,
        'translated_text': result.englishTranscript,
        'extracted_symptoms': result.extractedSymptoms,
        'is_emergency': result.emergencyFlag,
        'red_flag_type': result.emergencyReason,
        'sync_status': 'synced',
      }),
    );
    return _decodeOrThrow(response) as Map<String, dynamic>;
  }

  Future<AshaPatient> registerPatient({
    required String ashaId,
    required String name,
    required String healthId,
    String? village,
    String? phone,
    String? preferredLanguage,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/asha/patients'),
      headers: _headers,
      body: jsonEncode({
        'asha_id': ashaId,
        'name': name,
        'health_id': healthId,
        'village': village,
        'phone': phone,
        'preferred_language': preferredLanguage ?? 'hi-IN',
      }),
    );
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    return AshaPatient.fromJson(data);
  }

  // =============================================================
  // PATIENT PORTAL APIS
  // =============================================================

  Future<PatientProfile> fetchPatientProfile(String patientId) async {
    final response = await _client.get(_uri('/api/v1/patients/$patientId'), headers: _headers);
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    return PatientProfile.fromJson(data);
  }

  Future<List<PatientAppointment>> fetchPatientAppointments(String patientId) async {
    final response = await _client.get(_uri('/api/v1/patients/$patientId/appointments'), headers: _headers);
    final list = _decodeOrThrow(response) as List<dynamic>;
    return list.map((e) => PatientAppointment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<PatientReferral>> fetchPatientReferrals(String patientId) async {
    final response = await _client.get(_uri('/api/v1/patients/$patientId/referrals'), headers: _headers);
    final list = _decodeOrThrow(response) as List<dynamic>;
    return list.map((e) => PatientReferral.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> submitPatientVoiceSymptom({
    required String patientId,
    required String text,
    String? language,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/voice/patient-symptom-submission'),
      headers: _headers,
      body: jsonEncode({
        'patient_id': patientId,
        'transcript': text,
        'language': language ?? 'hi-IN',
      }),
    );
    // If patient-symptom-submission doesn't exist, fallback to clinical-voice/process-text
    return _decodeOrThrow(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createPatientAppointment({
    required String patientId,
    required ClinicalVoiceResult result,
    String? language,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/patients/$patientId/appointments'),
      headers: _headers,
      body: jsonEncode({
        'speciality': result.suggestedSpecialty,
        'transcript': result.rawTranscript,
        'translated_text': result.englishTranscript,
        'language': language ?? 'hi',
        'extracted_symptoms': result.extractedSymptoms,
        'is_emergency': result.emergencyFlag,
        'red_flag_type': result.emergencyReason,
      }),
    );
    return _decodeOrThrow(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createDirectPatientAppointment({
    required String patientId,
    required String speciality,
    String? reason,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/patients/$patientId/appointments'),
      headers: _headers,
      body: jsonEncode({
        'speciality': speciality,
        'transcript': (reason != null && reason.trim().isNotEmpty)
            ? reason.trim()
            : 'Direct OPD appointment requested by patient.',
        'translated_text': (reason != null && reason.trim().isNotEmpty)
            ? reason.trim()
            : 'Direct OPD appointment requested by patient.',
        'language': 'en',
        'extracted_symptoms': (reason != null && reason.trim().isNotEmpty)
            ? [reason.trim()]
            : ['General Consultation'],
        'is_emergency': false,
      }),
    );
    return _decodeOrThrow(response) as Map<String, dynamic>;
  }

  // =============================================================
  // ADMIN PORTAL APIS
  // =============================================================

  Future<UnifiedUserSession> adminLogin(String username, String password) async {
    final response = await _client.post(
      _uri('/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username.trim(), 'password': password}),
    );
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    final token = data['access_token'] as String;
    authToken = token;

    final meRes = await _client.get(_uri('/api/v1/auth/me'), headers: _headers);
    final meData = _decodeOrThrow(meRes) as Map<String, dynamic>;

    return UnifiedUserSession(
      role: UserRole.phcAdmin,
      id: meData['id'] as String,
      name: meData['name'] as String,
      identifier: meData['username'] as String,
      token: token,
      extra: {
        'role': meData['role'],
        'speciality': meData['speciality'],
        'facility_id': meData['facility_id'],
      },
    );
  }

  Future<AdminAnalyticsReport> fetchAdminAnalytics() async {
    final response = await _client.get(_uri('/api/v1/admin/analytics/summary'), headers: _headers);
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    return AdminAnalyticsReport.fromJson(data);
  }

  Future<List<AdminDoctorRecord>> fetchAdminDoctors() async {
    final response = await _client.get(_uri('/api/v1/admin/doctors'), headers: _headers);
    final list = _decodeOrThrow(response) as List<dynamic>;
    return list.map((e) => AdminDoctorRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminDoctorRecord> registerDoctor({
    required String name,
    required String username,
    required String password,
    String? phone,
    String? speciality,
    String? facilityId,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/admin/doctors'),
      headers: _headers,
      body: jsonEncode({
        'name': name.trim(),
        'username': username.trim(),
        'password': password,
        'role': 'doctor',
        'phone': phone?.trim(),
        'speciality': speciality ?? 'General Medicine',
        'facility_id': facilityId,
      }),
    );
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    return AdminDoctorRecord.fromJson(data);
  }

  Future<void> toggleDoctorStatus(String doctorId, bool isActive) async {
    final response = await _client.patch(
      _uri('/api/v1/admin/doctors/$doctorId/status'),
      headers: _headers,
      body: jsonEncode({'is_active': isActive}),
    );
    _decodeOrThrow(response);
  }

  Future<List<AdminAshaRecord>> fetchAdminAshaWorkers() async {
    final response = await _client.get(_uri('/api/v1/admin/asha-workers'), headers: _headers);
    final list = _decodeOrThrow(response) as List<dynamic>;
    return list.map((e) => AdminAshaRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminAshaRecord> registerAshaWorker({
    required String name,
    required String phone,
    String? village,
    String? facilityId,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/admin/asha-workers'),
      headers: _headers,
      body: jsonEncode({
        'name': name.trim(),
        'phone': phone.trim(),
        'village': village?.trim(),
        'facility_id': facilityId,
      }),
    );
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    return AdminAshaRecord.fromJson(data);
  }

  Future<void> updateAshaStatus(String ashaId, String status) async {
    final response = await _client.patch(
      _uri('/api/v1/admin/asha-workers/$ashaId/status'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    _decodeOrThrow(response);
  }

  Future<void> deleteAshaWorker(String ashaId) async {
    final response = await _client.delete(
      _uri('/api/v1/admin/asha-workers/$ashaId'),
      headers: _headers,
    );
    _decodeOrThrow(response);
  }

  // =============================================================
  // 6-ROLE UNIFIED AUTH & 2FA
  // =============================================================

  Future<UnifiedUserSession> unifiedLogin(String username, String password) async {
    final response = await _client.post(
      _uri('/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username.trim(), 'password': password}),
    );
    final data = _decodeOrThrow(response) as Map<String, dynamic>;

    if (data['requires_2fa'] == true) {
      return UnifiedUserSession(
        role: UserRole.fromString(data['role'] as String? ?? 'doctor'),
        id: data['user_id'] as String,
        name: data['name'] as String? ?? username,
        identifier: username,
        extra: {
          'requires_2fa': true,
          'challenge_id': data['challenge_id'],
          'facility_id': data['facility_id'],
        },
      );
    }

    final token = data['access_token'] as String;
    authToken = token;
    final userMap = data['user'] as Map<String, dynamic>? ?? {};
    final roleStr = userMap['role'] as String? ?? data['role'] as String? ?? 'doctor';

    return UnifiedUserSession(
      role: UserRole.fromString(roleStr),
      id: userMap['id'] as String? ?? data['doctor']?['id'] as String? ?? 'usr-001',
      name: userMap['name'] as String? ?? data['doctor']?['name'] as String? ?? username,
      identifier: username,
      token: token,
      extra: {
        'facility_id': userMap['facility_id'],
        'permissions': userMap['permissions'] ?? [],
      },
    );
  }

  Future<UnifiedUserSession> verify2FA({
    required String userId,
    required String code,
    String? challengeId,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/auth/verify-2fa'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'code': code.trim(),
        'challenge_id': challengeId,
      }),
    );
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    final token = data['access_token'] as String;
    authToken = token;
    final userMap = data['user'] as Map<String, dynamic>? ?? {};

    return UnifiedUserSession(
      role: UserRole.fromString(userMap['role'] as String? ?? 'doctor'),
      id: userMap['id'] as String,
      name: userMap['name'] as String? ?? 'User',
      identifier: userMap['username'] as String? ?? userId,
      token: token,
      extra: {
        'facility_id': userMap['facility_id'],
        'permissions': userMap['permissions'] ?? [],
      },
    );
  }

  Future<UnifiedUserSession> demoLogin(UserRole targetRole) async {
    String roleStr;
    switch (targetRole) {
      case UserRole.patient: roleStr = 'patient'; break;
      case UserRole.asha: roleStr = 'health_worker'; break;
      case UserRole.doctor: roleStr = 'doctor'; break;
      case UserRole.pharmacy: roleStr = 'pharmacy'; break;
      case UserRole.lab: roleStr = 'lab'; break;
      case UserRole.phcAdmin: roleStr = 'phc_admin'; break;
    }

    final response = await _client.post(
      _uri('/api/v1/auth/demo-login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'role': roleStr}),
    );
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    final token = data['access_token'] as String;
    authToken = token;
    final userMap = data['user'] as Map<String, dynamic>? ?? {};

    return UnifiedUserSession(
      role: targetRole,
      id: userMap['id'] as String,
      name: userMap['name'] as String,
      identifier: userMap['username'] as String,
      token: token,
      extra: {
        'facility_id': userMap['facility_id'] ?? 'fac-phc-001',
        'permissions': userMap['permissions'] ?? [],
      },
    );
  }

  // =============================================================
  // PHC ADMINISTRATION & QUALITY DASHBOARD
  // =============================================================

  Future<Map<String, dynamic>> fetchPHCFacilityStatus([String facilityId = 'fac-phc-001']) async {
    final response = await _client.get(_uri('/api/v1/phc-admin/facility-status', {'facility_id': facilityId}), headers: _headers);
    return _decodeOrThrow(response) as Map<String, dynamic>;
  }

  Future<PHCQualityDashboard> fetchPHCQualityDashboard([String facilityId = 'fac-phc-001']) async {
    final response = await _client.get(_uri('/api/v1/phc-admin/quality', {'facility_id': facilityId}), headers: _headers);
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    return PHCQualityDashboard.fromJson(data);
  }

  Future<void> togglePHCAvailability({
    required String facilityId,
    required bool isAvailable,
    int? bedsAvailable,
    String? doctorId,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/phc-admin/facility/toggle-availability'),
      headers: _headers,
      body: jsonEncode({
        'facility_id': facilityId,
        'is_available': isAvailable,
        'beds_available': bedsAvailable,
        'doctor_id': doctorId,
      }),
    );
    _decodeOrThrow(response);
  }

  // =============================================================
  // PHARMACY PORTAL
  // =============================================================

  Future<List<PharmacyPrescriptionOrder>> fetchPharmacyOrders([String facilityId = 'fac-phc-001']) async {
    final response = await _client.get(_uri('/api/v1/pharmacy/orders', {'facility_id': facilityId}), headers: _headers);
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    final list = (data['orders'] as List<dynamic>?) ?? [];
    return list.map((e) => PharmacyPrescriptionOrder.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> dispensePharmacyOrder(String orderId, {String? notes}) async {
    final response = await _client.post(
      _uri('/api/v1/pharmacy/orders/$orderId/dispense'),
      headers: _headers,
      body: jsonEncode({'notes': notes, 'dispensed_by': 'pharma_demo'}),
    );
    _decodeOrThrow(response);
  }

  Future<List<PharmacyMedicineItem>> fetchPharmacyInventory([String facilityId = 'fac-phc-001']) async {
    final response = await _client.get(_uri('/api/v1/pharmacy/inventory', {'facility_id': facilityId}), headers: _headers);
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    final list = (data['inventory'] as List<dynamic>?) ?? [];
    return list.map((e) => PharmacyMedicineItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> updatePharmacyStock({
    required String facilityId,
    required String medicineName,
    required int quantity,
    String? status,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/pharmacy/inventory/update'),
      headers: _headers,
      body: jsonEncode({
        'facility_id': facilityId,
        'medicine_name': medicineName,
        'stock_quantity': quantity,
        'status': status,
      }),
    );
    _decodeOrThrow(response);
  }

  // =============================================================
  // LABORATORY PORTAL
  // =============================================================

  Future<List<LabTestOrder>> fetchLabOrders([String facilityId = 'fac-phc-001']) async {
    final response = await _client.get(_uri('/api/v1/laboratory/orders', {'facility_id': facilityId}), headers: _headers);
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    final list = (data['orders'] as List<dynamic>?) ?? [];
    return list.map((e) => LabTestOrder.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> markLabSampleCollected(String orderId) async {
    final response = await _client.post(
      _uri('/api/v1/laboratory/orders/$orderId/sample-collected'),
      headers: _headers,
      body: jsonEncode({'technician_name': 'Pooja Shinde'}),
    );
    _decodeOrThrow(response);
  }

  Future<void> uploadLabResult(String orderId, String ref, String summary) async {
    final response = await _client.post(
      _uri('/api/v1/laboratory/orders/$orderId/upload-result'),
      headers: _headers,
      body: jsonEncode({
        'result_ref': ref,
        'result_summary': summary,
        'technician_name': 'Pooja Shinde',
      }),
    );
    _decodeOrThrow(response);
  }

  Future<LabTestOrder> createLabOrder({
    required String patientId,
    required String testType,
    String? healthId,
    String? patientName,
    String? doctorId,
    String? facilityId,
    String? status,
    String? resultRef,
    String? resultSummary,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/laboratory/orders'),
      headers: _headers,
      body: jsonEncode({
        'patient_id': patientId,
        'health_id': healthId,
        'patient_name': patientName,
        'test_type': testType,
        'doctor_id': doctorId ?? 'usr-doctor-001',
        'facility_id': facilityId ?? 'fac-phc-001',
        'status': status ?? 'result_uploaded',
        'result_ref': resultRef,
        'result_summary': resultSummary,
      }),
    );
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    return LabTestOrder.fromJson(data);
  }

  Future<List<LabTestOrder>> fetchPatientLabResults(String patientId) async {
    final response = await _client.get(_uri('/api/v1/patients/$patientId/lab-results'), headers: _headers);
    final list = _decodeOrThrow(response) as List<dynamic>;
    return list.map((e) => LabTestOrder.fromJson(e as Map<String, dynamic>)).toList();
  }

  // =============================================================
  // ABDM, AADHAAR & ABHA OTP VERIFICATION
  // =============================================================

  Future<String> generateHealthId() async {
    try {
      final response = await _client.get(_uri('/api/v1/abdm/health-id/generate'), headers: _headers);
      final data = _decodeOrThrow(response) as Map<String, dynamic>;
      return data['health_id'] as String;
    } catch (_) {
      final rand = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
      return 'HID-${DateTime.now().year}-$rand';
    }
  }

  Future<Map<String, dynamic>> generateAadhaarOtp(String aadhaarNumber) async {
    final response = await _client.post(
      _uri('/api/v1/abdm/aadhaar/generate-otp'),
      headers: _headers,
      body: jsonEncode({'aadhaar_number': aadhaarNumber}),
    );
    return _decodeOrThrow(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyAadhaarOtp(String txnId, String otp, [String? aadhaarNumber]) async {
    final response = await _client.post(
      _uri('/api/v1/abdm/aadhaar/verify-otp'),
      headers: _headers,
      body: jsonEncode({
        'txn_id': txnId,
        'otp': otp,
        'aadhaar_number': aadhaarNumber,
      }),
    );
    return _decodeOrThrow(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generateAbhaOtp(String abhaId) async {
    final response = await _client.post(
      _uri('/api/v1/abdm/abha/generate-otp'),
      headers: _headers,
      body: jsonEncode({'abha_id': abhaId}),
    );
    return _decodeOrThrow(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyAbhaOtp(String txnId, String otp, [String? abhaId]) async {
    final response = await _client.post(
      _uri('/api/v1/abdm/abha/verify-otp'),
      headers: _headers,
      body: jsonEncode({
        'txn_id': txnId,
        'otp': otp,
        'abha_id': abhaId,
      }),
    );
    return _decodeOrThrow(response) as Map<String, dynamic>;
  }

  // =============================================================
  // LOCATION-BASED SERVICES (PATIENT PORTAL)
  // =============================================================

  Future<Map<String, dynamic>> fetchNearbyPharmacies({
    double lat = 18.5314,
    double lng = 73.8446,
    double radiusKm = 10.0,
    String? medicine,
  }) async {
    final queryParams = <String, String>{
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radius_km': radiusKm.toString(),
    };
    if (medicine != null && medicine.trim().isNotEmpty) {
      queryParams['medicine'] = medicine.trim();
    }
    final response = await _client.get(
      _uri('/api/v1/patient/nearby-pharmacies', queryParams),
      headers: _headers,
    );
    return _decodeOrThrow(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchNearbyDiagnostics({
    double lat = 18.5314,
    double lng = 73.8446,
    double radiusKm = 15.0,
    String? testType,
  }) async {
    final queryParams = <String, String>{
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radius_km': radiusKm.toString(),
    };
    if (testType != null && testType.trim().isNotEmpty) {
      queryParams['test_type'] = testType.trim();
    }
    final response = await _client.get(
      _uri('/api/v1/patient/nearby-diagnostics', queryParams),
      headers: _headers,
    );
    return _decodeOrThrow(response) as Map<String, dynamic>;
  }
}
