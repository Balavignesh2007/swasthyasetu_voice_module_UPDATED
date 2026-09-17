import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/admin_models.dart';

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

class ApiService {
  final String? _explicitBaseUrl;
  final http.Client _client;

  String get baseUrl => _explicitBaseUrl ?? AppConfig.apiBaseUrl;

  /// The doctor's JWT bearer token. Every screen constructs its own
  /// ApiService() instance, so this is kept as a static "current session"
  /// value (set at login / restored session, cleared at logout) rather than
  /// threaded through every widget constructor — any ApiService instance
  /// then automatically authenticates as the signed-in doctor.
  static String? _sharedToken;

  ApiService({String? baseUrl, http.Client? client})
      : _explicitBaseUrl = baseUrl,
        _client = client ?? http.Client();

  // ignore: unnecessary_getters_setters
  String? get authToken => _sharedToken;
  // ignore: unnecessary_getters_setters
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

  Future<DashboardStats> fetchStats() async {
    final response = await _client.get(_uri('/api/v1/admin/dashboard'), headers: _authHeaders);
    return DashboardStats.fromJson(_decodeOrThrow(response) as Map<String, dynamic>);
  }

  Future<List<AdminEmergencyEvent>> fetchEmergencyEvents({int limit = 100}) async {
    final response = await _client.get(
      _uri('/api/v1/admin/emergency-events', {'limit': '$limit'}),
      headers: _authHeaders,
    );
    final data = _decodeOrThrow(response) as List<dynamic>;
    return data.map((e) => AdminEmergencyEvent.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AdminReferral>> fetchReferrals({int limit = 100}) async {
    final response = await _client.get(
      _uri('/api/v1/admin/referrals', {'limit': '$limit'}),
      headers: _authHeaders,
    );
    final data = _decodeOrThrow(response) as List<dynamic>;
    return data.map((e) => AdminReferral.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AdminAppointment>> fetchAppointments({int limit = 100}) async {
    final response = await _client.get(
      _uri('/api/v1/admin/appointments', {'limit': '$limit'}),
      headers: _authHeaders,
    );
    final data = _decodeOrThrow(response) as List<dynamic>;
    return data.map((e) => AdminAppointment.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ---------- Doctor account management (admin-only) ----------

  Future<List<DoctorAccount>> fetchDoctors() async {
    final response = await _client.get(_uri('/api/v1/admin/doctors'), headers: _authHeaders);
    final data = _decodeOrThrow(response) as List<dynamic>;
    return data.map((e) => DoctorAccount.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Creates a new doctor/admin login. Requires the current user to be an
  /// admin (POST /api/v1/admin/doctors) — a 403 means the signed-in account
  /// isn't an admin, a 409 means the username is already taken.
  Future<DoctorAccount> createDoctor({
    required String name,
    required String username,
    required String password,
    String role = 'doctor',
    String? phone,
    String? speciality,
    String? facilityId,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/admin/doctors'),
      headers: _authHeaders,
      body: jsonEncode({
        'name': name,
        'username': username,
        'password': password,
        'role': role,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (speciality != null && speciality.isNotEmpty) 'speciality': speciality,
        if (facilityId != null && facilityId.isNotEmpty) 'facility_id': facilityId,
      }),
    );
    return DoctorAccount.fromJson(_decodeOrThrow(response) as Map<String, dynamic>);
  }

  Future<DoctorAccount> setDoctorActive(String doctorId, bool isActive) async {
    final response = await _client.patch(
      _uri('/api/v1/admin/doctors/$doctorId/status'),
      headers: _authHeaders,
      body: jsonEncode({'is_active': isActive}),
    );
    return DoctorAccount.fromJson(_decodeOrThrow(response) as Map<String, dynamic>);
  }

  void dispose() => _client.close();
}
