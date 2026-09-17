import 'package:flutter/foundation.dart';

/// App-wide configuration.
///
/// Dynamically resolves the API host:
/// - Web / Windows / macOS / Linux: http://127.0.0.1:8000
/// - Android emulator: http://10.0.2.2:8000
/// - Overridable via --dart-define=API_BASE_URL=...
class AppConfig {
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return 'http://127.0.0.1:8000';
    }
    return 'http://10.0.2.2:8000';
  }

  /// How often the alerts screen polls the backend for new emergency alerts.
  static const Duration alertsPollInterval = Duration(seconds: 15);
}
