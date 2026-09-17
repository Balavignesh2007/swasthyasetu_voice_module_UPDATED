import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/emergency_alert.dart';
import '../models/patient.dart';
import '../models/clinical_voice_result.dart';
import '../models/voice_note.dart';
import '../models/follow_up.dart';

/// Thrown when the backend returns a non-2xx response, carrying enough
/// detail for the UI to show a sensible error message.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  final String baseUrl;
  final http.Client _client;

  ApiService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
        _client = client ?? http.Client();

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Map<String, String> get _jsonHeaders => {'Content-Type': 'application/json'};

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
    } catch (_) {
      // response body wasn't JSON; fall back to raw body as the message
    }
    throw ApiException(response.statusCode, message);
  }

  // ---------- ASHA identity ----------

  /// Resolves an ASHA worker's ID from their registered phone number.
  /// Used on the login screen — see backend GET /api/v1/asha/lookup.
  Future<AshaWorkerProfile> lookupAshaByPhone(String phone) async {
    final response = await _client.get(_uri('/api/v1/asha/lookup', {'phone': phone}));
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    return AshaWorkerProfile.fromJson(data);
  }

  // ---------- Alerts ----------

  /// Fetches emergency alerts assigned to this ASHA worker.
  /// Pass [status] (e.g. 'UNACKNOWLEDGED') to filter, or omit for all.
  Future<List<EmergencyAlert>> fetchAlerts({required String ashaId, String? status}) async {
    final query = {'asha_id': ashaId, if (status != null) 'status': status};
    final response = await _client.get(_uri('/api/v1/asha/alerts', query));
    final data = _decodeOrThrow(response) as List<dynamic>;
    return data.map((e) => EmergencyAlert.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<EmergencyAlert> acknowledgeAlert(String alertId, String ashaId) async {
    final response = await _client.post(
      _uri('/api/v1/asha/alerts/$alertId/acknowledge'),
      headers: _jsonHeaders,
      body: jsonEncode({'asha_id': ashaId}),
    );
    return EmergencyAlert.fromJson(_decodeOrThrow(response) as Map<String, dynamic>);
  }

  Future<EmergencyAlert> markContacting(String alertId, String ashaId) async {
    final response = await _client.post(
      _uri('/api/v1/asha/alerts/$alertId/contacting'),
      headers: _jsonHeaders,
      body: jsonEncode({'asha_id': ashaId}),
    );
    return EmergencyAlert.fromJson(_decodeOrThrow(response) as Map<String, dynamic>);
  }

  Future<EmergencyAlert> markReached(String alertId, String ashaId) async {
    final response = await _client.post(
      _uri('/api/v1/asha/alerts/$alertId/reached'),
      headers: _jsonHeaders,
      body: jsonEncode({'asha_id': ashaId}),
    );
    return EmergencyAlert.fromJson(_decodeOrThrow(response) as Map<String, dynamic>);
  }

  Future<EmergencyAlert> markUnableToReach(String alertId, String ashaId) async {
    final response = await _client.post(
      _uri('/api/v1/asha/alerts/$alertId/unable-to-reach'),
      headers: _jsonHeaders,
      body: jsonEncode({'asha_id': ashaId}),
    );
    return EmergencyAlert.fromJson(_decodeOrThrow(response) as Map<String, dynamic>);
  }

  Future<EmergencyAlert> escalateAlert(String alertId, String ashaId) async {
    final response = await _client.post(
      _uri('/api/v1/asha/alerts/$alertId/escalate'),
      headers: _jsonHeaders,
      body: jsonEncode({'asha_id': ashaId}),
    );
    return EmergencyAlert.fromJson(_decodeOrThrow(response) as Map<String, dynamic>);
  }

  Future<EmergencyAlert> resolveAlert(String alertId, String ashaId) async {
    final response = await _client.post(
      _uri('/api/v1/asha/alerts/$alertId/resolve'),
      headers: _jsonHeaders,
      body: jsonEncode({'asha_id': ashaId}),
    );
    return EmergencyAlert.fromJson(_decodeOrThrow(response) as Map<String, dynamic>);
  }

  // ---------- Patients ----------

  Future<List<AshaPatient>> fetchAssignedPatients(String ashaId) async {
    final response = await _client.get(_uri('/api/v1/asha/$ashaId/patients'));
    final data = _decodeOrThrow(response) as List<dynamic>;
    return data.map((e) => AshaPatient.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AshaPatient> registerPatient({
    required String ashaId,
    required String name,
    required String phone,
    String? village,
    String? preferredLanguage,
    String? healthId,
    int? age,
    String? gender,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/asha/$ashaId/patients'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'name': name,
        'phone': phone,
        if (village != null && village.isNotEmpty) 'village': village,
        'preferred_language': preferredLanguage ?? 'hi',
        if (healthId != null && healthId.isNotEmpty) 'health_id': healthId,
        if (age != null) 'age': age,
        if (gender != null && gender.isNotEmpty) 'gender': gender,
      }),
    );
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    return AshaPatient.fromJson(data);
  }

  // ---------- Clinical Voice Processing ----------

  Future<ClinicalVoiceResult> processClinicalVoice({
    String? transcript,
    String? audioBase64,
    String language = 'auto',
    String? patientId,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/clinical/process-voice'),
      headers: _jsonHeaders,
      body: jsonEncode({
        if (transcript != null) 'transcript': transcript,
        if (audioBase64 != null) 'audio_base64': audioBase64,
        'language': language,
        if (patientId != null) 'patient_id': patientId,
      }),
    );
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    return ClinicalVoiceResult.fromJson(data);
  }

  // ---------- Clinical Voice Notes ----------

  Future<VoiceNote> saveVoiceNote(Map<String, dynamic> data) async {
    final response = await _client.post(
      _uri('/api/v1/asha/voice-notes'),
      headers: _jsonHeaders,
      body: jsonEncode(data),
    );
    final result = _decodeOrThrow(response) as Map<String, dynamic>;
    return VoiceNote.fromJson(result);
  }

  Future<List<VoiceNote>> fetchVoiceNotes({
    String? ashaId,
    String? patientId,
    int limit = 50,
  }) async {
    final query = {
      if (ashaId != null) 'asha_id': ashaId,
      if (patientId != null) 'patient_id': patientId,
      'limit': limit.toString(),
    };
    final response = await _client.get(_uri('/api/v1/asha/voice-notes', query));
    final data = _decodeOrThrow(response) as List<dynamic>;
    return data.map((e) => VoiceNote.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ---------- Follow-ups ----------

  Future<List<PatientFollowUp>> fetchFollowUps({
    required String ashaId,
    String? status,
  }) async {
    final query = {if (status != null) 'status': status};
    final response = await _client.get(_uri('/api/v1/asha/$ashaId/follow-ups', query));
    final data = _decodeOrThrow(response) as List<dynamic>;
    return data.map((e) => PatientFollowUp.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PatientFollowUp> createFollowUp(Map<String, dynamic> data) async {
    final response = await _client.post(
      _uri('/api/v1/asha/follow-ups'),
      headers: _jsonHeaders,
      body: jsonEncode(data),
    );
    final result = _decodeOrThrow(response) as Map<String, dynamic>;
    return PatientFollowUp.fromJson(result);
  }

  Future<PatientFollowUp> updateFollowUp(
    String followUpId,
    Map<String, dynamic> updates,
  ) async {
    final response = await _client.patch(
      _uri('/api/v1/asha/follow-ups/$followUpId'),
      headers: _jsonHeaders,
      body: jsonEncode(updates),
    );
    final result = _decodeOrThrow(response) as Map<String, dynamic>;
    return PatientFollowUp.fromJson(result);
  }

  // ---------- Offline Batch Sync ----------

  Future<Map<String, dynamic>> batchSync({
    required String ashaId,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/asha/sync'),
      headers: _jsonHeaders,
      body: jsonEncode({'asha_id': ashaId, 'items': items}),
    );
    return _decodeOrThrow(response) as Map<String, dynamic>;
  }

  void dispose() {
    _client.close();
  }
}
