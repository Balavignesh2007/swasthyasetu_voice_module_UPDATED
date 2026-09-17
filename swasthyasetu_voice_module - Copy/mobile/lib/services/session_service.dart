import 'package:shared_preferences/shared_preferences.dart';

/// Caches the logged-in patient's ID/name locally between launches.
/// See asha_app's SessionService for the same pattern and the note there
/// about upgrading to real JWT-based sessions before production.
class SessionService {
  static const _keyPatientId = 'patient_id';
  static const _keyPatientName = 'patient_name';

  Future<void> saveSession({required String patientId, required String patientName}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPatientId, patientId);
    await prefs.setString(_keyPatientName, patientName);
  }

  Future<({String id, String name})?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_keyPatientId);
    final name = prefs.getString(_keyPatientName);
    if (id == null || name == null) return null;
    return (id: id, name: name);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPatientId);
    await prefs.remove(_keyPatientName);
  }
}
