import 'package:flutter/material.dart';

import 'models/unified_models.dart';
import 'screens/unified_login_screen.dart';
import 'screens/unified_shell.dart';
import 'services/unified_session_service.dart';

import '../config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.loadCustomBaseUrl();
  runApp(const SwasthyaSetuUnifiedApp());
}

class SwasthyaSetuUnifiedApp extends StatelessWidget {
  const SwasthyaSetuUnifiedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwasthyaSetu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0F766E),
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
        fontFamily: 'Roboto',
      ),
      home: const _UnifiedAuthGate(),
    );
  }
}

class _UnifiedAuthGate extends StatefulWidget {
  const _UnifiedAuthGate();

  @override
  State<_UnifiedAuthGate> createState() => _UnifiedAuthGateState();
}

class _UnifiedAuthGateState extends State<_UnifiedAuthGate> {
  final _sessionService = UnifiedSessionService();
  bool _checking = true;
  UnifiedUserSession? _session;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final cached = await _sessionService.loadSession();
      if (mounted) {
        setState(() {
          _session = cached;
          _checking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F6F9),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0F766E))),
      );
    }
    return _session != null ? UnifiedShell(initialSession: _session!) : const UnifiedLoginScreen();
  }
}
