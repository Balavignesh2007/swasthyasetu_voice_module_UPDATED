import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/unified_models.dart';

class UnifiedSessionService {
  static const _keySession = 'swasthyasetu_unified_session';

  Future<void> saveSession(UnifiedUserSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'role': session.role.name,
      'id': session.id,
      'name': session.name,
      'identifier': session.identifier,
      'token': session.token,
      'extra': session.extra,
    };
    await prefs.setString(_keySession, jsonEncode(data));
  }

  Future<UnifiedUserSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySession);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final roleStr = map['role'] as String? ?? 'doctor';
      final role = UserRole.values.firstWhere(
        (r) => r.name == roleStr,
        orElse: () => UserRole.doctor,
      );
      return UnifiedUserSession(
        role: role,
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        identifier: map['identifier'] as String? ?? '',
        token: map['token'] as String?,
        extra: map['extra'] as Map<String, dynamic>? ?? {},
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySession);
  }
}
