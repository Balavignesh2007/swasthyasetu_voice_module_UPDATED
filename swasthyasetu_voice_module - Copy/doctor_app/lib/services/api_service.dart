import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/doctor_models.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  /// True when the backend rejected/expired the doctor's session — the
  /// caller should send them back to the login screen.
  bool get isAuthError => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Talks to the same JWT-secured endpoints as the dashboard
/// (see swasthyasetu backend app/api/auth.py + app/api/admin.py, gated by
/// app/utils/security.py's get_current_doctor). Any active doctor_users
/// account can sign in here — there's no separate "mobile" login.
class ApiService {
  final String baseUrl;
  final http.Client _client;

  /// The doctor's JWT bearer token. Every screen constructs its own
  /// ApiService() instance, so this is kept as a static "current session"
  /// value (set at login / restored session, cleared at logout) rather than
  /// threaded through every widget constructor — any ApiService instance
  /// then automatically authenticates as the signed-in doctor.
  static String? _sharedToken;

  ApiService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
        _client = client ?? http.Client();

  String? get authToken => _sharedToken;
  set authToken(String? token) => _sharedToken = token;

  static void clearToken() => _sharedToken = null;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Map<String, String> get _authHeaders {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authToken != null) headers['Authorization'] = 'Bearer $authToken';
    return headers;
  }

  dynamic _decodeOrThrow(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    String message = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) message = decoded['detail'].toString();
    } catch (_) {}
    throw ApiException(response.statusCode, message);
  }

  // ---------- Auth ----------

  /// Doctor login: POST /api/v1/auth/login with username + password.
  /// On success, stores the returned JWT on this instance so subsequent
  /// calls are authenticated, and returns it (plus the doctor profile) for
  /// the caller to persist via SessionService.
  Future<LoginResult> login({required String username, required String password}) async {
    final response = await _client.post(
      _uri('/api/v1/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final result = LoginResult.fromJson(_decodeOrThrow(response) as Map<String, dynamic>);
    authToken = result.accessToken;
    return result;
  }

  /// Validates a cached token on app startup (GET /api/v1/auth/me).
  /// Throws ApiException(401) if the token is missing/expired/invalid.
  Future<DoctorProfile> fetchCurrentDoctor() async {
    final response = await _client.get(_uri('/api/v1/auth/me'), headers: _authHeaders);
    return DoctorProfile.fromJson(_decodeOrThrow(response) as Map<String, dynamic>);
  }

  // ---------- Dashboard data (any signed-in doctor) ----------

  Future<DashboardStats> fetchStats() async {
    final response = await _client.get(_uri('/api/v1/admin/dashboard'), headers: _authHeaders);
    return DashboardStats.fromJson(_decodeOrThrow(response) as Map<String, dynamic>);
  }

  Future<List<DoctorEmergencyEvent>> fetchEmergencyEvents({int limit = 100}) async {
    final response = await _client.get(
      _uri('/api/v1/admin/emergency-events', {'limit': '$limit'}),
      headers: _authHeaders,
    );
    final data = _decodeOrThrow(response) as List<dynamic>;
    return data.map((e) => DoctorEmergencyEvent.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<DoctorReferral>> fetchReferrals({int limit = 100}) async {
    final response = await _client.get(
      _uri('/api/v1/admin/referrals', {'limit': '$limit'}),
      headers: _authHeaders,
    );
    final data = _decodeOrThrow(response) as List<dynamic>;
    return data.map((e) => DoctorReferral.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<DoctorAppointment>> fetchAppointments({int limit = 100}) async {
    final response = await _client.get(
      _uri('/api/v1/admin/appointments', {'limit': '$limit'}),
      headers: _authHeaders,
    );
    final data = _decodeOrThrow(response) as List<dynamic>;
    return data.map((e) => DoctorAppointment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> addPrescription({
    required String appointmentId,
    required String prescription,
    String? diagnosis,
    String? notes,
    String status = 'completed',
  }) async {
    final response = await _client.post(
      _uri('/api/v1/admin/appointments/$appointmentId/prescribe'),
      headers: _authHeaders,
      body: jsonEncode({
        'prescription': prescription,
        if (diagnosis != null) 'diagnosis': diagnosis,
        if (notes != null) 'notes': notes,
        'status': status,
      }),
    );
    _decodeOrThrow(response);
  }

  Future<DoctorReferral> createReferral({
    required String patientId,
    required String toFacilityId,
    String? reason,
    String? fromFacilityId,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/referrals'),
      headers: _authHeaders,
      body: jsonEncode({
        'patient_id': patientId,
        'to_facility_id': toFacilityId,
        if (fromFacilityId != null) 'from_facility_id': fromFacilityId,
        if (reason != null) 'reason': reason,
      }),
    );
    final data = _decodeOrThrow(response) as Map<String, dynamic>;
    return DoctorReferral.fromJson(data);
  }

  Future<List<DoctorFacility>> fetchFacilities() async {
    final response = await _client.get(_uri('/api/v1/admin/facilities'), headers: _authHeaders);
    final data = _decodeOrThrow(response) as List<dynamic>;
    return data.map((e) => DoctorFacility.fromJson(e as Map<String, dynamic>)).toList();
  }

  void dispose() => _client.close();
}
