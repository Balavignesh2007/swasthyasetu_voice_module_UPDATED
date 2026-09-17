import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _healthIdController = TextEditingController();
  final _apiService = ApiService();
  final _sessionService = SessionService();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    var phone = _phoneController.text.trim();
    final healthId = _healthIdController.text.trim();
    if (phone.isEmpty || healthId.isEmpty) {
      setState(() => _error = 'Please enter both your phone number and health ID.');
      return;
    }
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      phone = '+91$digits';
    } else if (!phone.startsWith('+') && digits.isNotEmpty) {
      phone = '+$digits';
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _apiService.login(phone: phone, healthId: healthId);
      await _sessionService.saveSession(patientId: profile.id, patientName: profile.displayName);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(patientId: profile.id, patientName: profile.displayName)),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.statusCode == 404
          ? 'No record found. Check your phone number and health ID, or call the helpline for help.'
          : 'Could not log in: ${e.message}');
    } catch (_) {
      setState(() => _error = 'Could not reach the server. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _healthIdController.dispose();
    _apiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.health_and_safety, size: 72, color: Color(0xFF2E7D32)),
                const SizedBox(height: 16),
                const Text(
                  'SwasthyaSetu',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                ),
                const Text('Patient Portal', style: TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 32),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Registered phone number',
                    hintText: '9000000001 or +919000000001',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _healthIdController,
                  decoration: const InputDecoration(
                    labelText: 'Health ID',
                    hintText: 'HID10001',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 16),

                // Quick Demo Accounts
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Demo Accounts (Tap to fill):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('Demo Patient (HID10001)', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        _phoneController.text = '9000000001';
                        _healthIdController.text = 'HID10001';
                      },
                    ),
                    ActionChip(
                      label: const Text('Ramesh Kumar (HID10002)', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        _phoneController.text = '9000000002';
                        _healthIdController.text = 'HID10002';
                      },
                    ),
                    ActionChip(
                      label: const Text('Sunita Devi (HID10003)', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        _phoneController.text = '9000000003';
                        _healthIdController.text = 'HID10003';
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                    ),
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Log in to Patient Portal', style: TextStyle(fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Don't have the app or can't log in? You can always call the "
                  'SwasthyaSetu helpline from any phone.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
