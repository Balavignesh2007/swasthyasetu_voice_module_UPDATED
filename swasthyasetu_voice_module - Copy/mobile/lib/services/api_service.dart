import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/patient_models.dart';
import '../models/clinical_voice_result.dart';

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

  /// Logs the patient in using their phone number + health ID — the same
  /// two-factor identity check used by the voice IVR (spec section 4).
  Future<PatientProfile> login({required String phone, required String healthId}) async {
    final response = await _client.get(
      _uri('/api/v1/patients/login', {'caller_phone': phone, 'health_id': healthId}),
    );
    return PatientProfile.fromJson(_decodeOrThrow(response) as Map<String, dynamic>);
  }

  Future<PatientProfile> fetchProfile(String patientId) async {
    final response = await _client.get(_uri('/api/v1/patients/$patientId'));
    return PatientProfile.fromJson(_decodeOrThrow(response) as Map<String, dynamic>);
  }

  Future<List<PatientAppointment>> fetchAppointments(String patientId) async {
    final response = await _client.get(_uri('/api/v1/patients/$patientId/appointments'));
    final data = _decodeOrThrow(response) as List<dynamic>;
    return data.map((e) => PatientAppointment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<PatientReferral>> fetchReferrals(String patientId) async {
    final response = await _client.get(_uri('/api/v1/patients/$patientId/referrals'));
    final data = _decodeOrThrow(response) as List<dynamic>;
    return data.map((e) => PatientReferral.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<VoiceHistoryEntry>> fetchVoiceHistory(String patientId) async {
    final response = await _client.get(_uri('/api/v1/patients/$patientId/voice-history'));
    final data = _decodeOrThrow(response) as List<dynamic>;
    return data.map((e) => VoiceHistoryEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ClinicalVoiceResult> processClinicalVoice({
    String? transcript,
    String? audioBase64,
    String language = 'auto',
    String? patientId,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/clinical/process-voice'),
      headers: {'Content-Type': 'application/json'},
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

  void dispose() => _client.close();
}
