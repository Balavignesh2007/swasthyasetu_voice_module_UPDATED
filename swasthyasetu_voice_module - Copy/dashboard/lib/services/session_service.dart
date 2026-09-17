import 'package:shared_preferences/shared_preferences.dart';

import '../models/admin_models.dart';

/// Caches the logged-in doctor's JWT and basic profile locally between
/// launches, mirroring the SessionService pattern used in the ASHA/patient
/// apps. The token is a real JWT issued by POST /api/v1/auth/login and is
/// sent as `Authorization: Bearer <token>` on every admin API call.
class SessionService {
  static const _keyToken = 'doctor_token';
  static const _keyDoctorId = 'doctor_id';
  static const _keyDoctorName = 'doctor_name';
  static const _keyDoctorUsername = 'doctor_username';
  static const _keyDoctorRole = 'doctor_role';

  Future<void> saveSession({required String token, required DoctorProfile doctor}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyDoctorId, doctor.id);
    await prefs.setString(_keyDoctorName, doctor.name);
    await prefs.setString(_keyDoctorUsername, doctor.username);
    await prefs.setString(_keyDoctorRole, doctor.role);
  }

  Future<({String token, DoctorProfile doctor})?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    final id = prefs.getString(_keyDoctorId);
    final name = prefs.getString(_keyDoctorName);
    final username = prefs.getString(_keyDoctorUsername);
    final role = prefs.getString(_keyDoctorRole);
    if (token == null || id == null || name == null || username == null || role == null) {
      return null;
    }
    return (
      token: token,
      doctor: DoctorProfile(id: id, name: name, username: username, role: role),
    );
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyDoctorId);
    await prefs.remove(_keyDoctorName);
    await prefs.remove(_keyDoctorUsername);
    await prefs.remove(_keyDoctorRole);
  }
}
