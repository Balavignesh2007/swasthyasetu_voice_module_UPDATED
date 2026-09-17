/// Configuration for the doctor mobile app.
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const Duration refreshInterval = Duration(seconds: 20);
}
