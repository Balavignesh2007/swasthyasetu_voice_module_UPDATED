import 'package:flutter/material.dart';

import 'services/session_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const SwasthyaSetuPatientApp());
}

class SwasthyaSetuPatientApp extends StatelessWidget {
  const SwasthyaSetuPatientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwasthyaSetu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2E7D32),
      ),
      home: const _StartupRouter(),
    );
  }
}

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
        return HomeScreen(patientId: session.id, patientName: session.name);
      },
    );
  }
}
