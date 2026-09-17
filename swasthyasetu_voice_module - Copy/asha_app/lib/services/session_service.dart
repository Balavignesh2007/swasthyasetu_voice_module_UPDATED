import 'package:shared_preferences/shared_preferences.dart';

/// Stores the logged-in ASHA worker's identity locally between app launches.
///
/// This is intentionally lightweight for the prototype: the backend's
/// GET /api/v1/asha/lookup resolves a phone number to a worker ID, and we
/// cache that ID + name locally. Before production, replace this with a
/// real authenticated session (JWT issued by the backend, refreshed
/// periodically) — see app/utils/security.py on the backend for the
/// token helpers already in place.
class SessionService {
  static const _keyAshaId = 'asha_id';
  static const _keyAshaName = 'asha_name';

  Future<void> saveSession({required String ashaId, required String ashaName}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAshaId, ashaId);
    await prefs.setString(_keyAshaName, ashaName);
  }

  static Future<({String id, String name})?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_keyAshaId);
    final name = prefs.getString(_keyAshaName);
    if (id == null || name == null) return null;
    return (id: id, name: name);
  }

  Future<({String id, String name})?> loadSession() => getProfile();

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAshaId);
    await prefs.remove(_keyAshaName);
  }
}
