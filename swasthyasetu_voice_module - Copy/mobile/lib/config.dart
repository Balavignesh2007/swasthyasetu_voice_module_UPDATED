import 'package:flutter/foundation.dart';

/// App-wide configuration for the patient app.
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

  /// The SwasthyaSetu voice helpline number patients can call from any
  /// basic phone — shown prominently since many users may prefer voice
  /// over the app itself. Replace with your provisioned Twilio number.
  static const String helplineNumber = '+911800000000';
}
