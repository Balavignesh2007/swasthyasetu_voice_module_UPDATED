import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration for the SwasthyaSetu app and dashboards.
class AppConfig {
  static const String defaultMobileHost = 'http://192.168.0.3:8000';
  static String? _customBaseUrl;

  static void setBaseUrl(String url) {
    _customBaseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  static String get apiBaseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty && host != 'localhost' && host != '127.0.0.1') {
        return 'http://$host:8000';
      }
      return 'http://127.0.0.1:8000';
    }
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return 'http://127.0.0.1:8000';
    }
    // Mobile device / emulator connected to PC Wi-Fi:
    return defaultMobileHost;
  }

  static Future<void> loadCustomBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('custom_api_base_url');
      if (saved != null && saved.trim().isNotEmpty) {
        _customBaseUrl = saved.trim().replaceAll(RegExp(r'/+$'), '');
      }
    } catch (_) {}
  }

  static Future<void> saveCustomBaseUrl(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    _customBaseUrl = clean;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_api_base_url', clean);
    } catch (_) {}
  }

  static Future<void> resetCustomBaseUrl() async {
    _customBaseUrl = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('custom_api_base_url');
    } catch (_) {}
  }

  static const Duration refreshInterval = Duration(seconds: 20);
}

