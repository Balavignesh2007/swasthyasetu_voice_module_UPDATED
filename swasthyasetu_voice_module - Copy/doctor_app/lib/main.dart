import 'package:flutter/material.dart';

import 'models/doctor_models.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/session_service.dart';

void main() {
  runApp(const SwasthyaSetuDoctorApp());
}

class SwasthyaSetuDoctorApp extends StatelessWidget {
  const SwasthyaSetuDoctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwasthyaSetu Doctor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1976D2),
        scaffoldBackgroundColor: const Color(0xFFF3F5F8),
      ),
      home: const _AuthGate(),
    );
  }
}

/// Restores a cached doctor session on launch (if any) and validates it
/// against the backend before dropping straight into the app; otherwise
/// sends the user to the login screen. Mirrors the dashboard's _AuthGate.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final _sessionService = SessionService();
  bool _checking = true;
  DoctorProfile? _doctor;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final cached = await _sessionService.loadSession();
    if (cached == null) {
      setState(() => _checking = false);
      return;
    }
    final apiService = ApiService()..authToken = cached.token;
    try {
      final doctor = await apiService.fetchCurrentDoctor();
      setState(() {
        _doctor = doctor;
        _checking = false;
      });
    } catch (_) {
      // Token missing/expired/invalid — clear it and fall back to login.
      await _sessionService.clearSession();
      ApiService.clearToken();
      setState(() => _checking = false);
    } finally {
      apiService.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3F5F8),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _doctor != null ? HomeScreen(doctor: _doctor!) : const LoginScreen();
  }
}
