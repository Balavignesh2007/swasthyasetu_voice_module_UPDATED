import 'package:flutter/material.dart';

import 'services/session_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const SwasthyaSetuAshaApp());
}

class SwasthyaSetuAshaApp extends StatelessWidget {
  const SwasthyaSetuAshaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwasthyaSetu ASHA App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1976D2),
      ),
      home: const _StartupRouter(),
    );
  }
}

/// Checks for a saved ASHA session on launch and routes straight to Home if
/// one exists, otherwise shows the login screen.
class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  final _sessionService = SessionService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _sessionService.loadSession(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final session = snapshot.data;
        if (session == null) {
          return const LoginScreen();
        }
        return HomeScreen(ashaId: session.id, ashaName: session.name);
      },
    );
  }
}
