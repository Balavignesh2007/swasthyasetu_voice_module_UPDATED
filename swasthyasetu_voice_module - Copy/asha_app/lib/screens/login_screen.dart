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
  final _apiService = ApiService();
  final _sessionService = SessionService();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    var phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Please enter your registered phone number.');
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
      final worker = await _apiService.lookupAshaByPhone(phone);
      await _sessionService.saveSession(ashaId: worker.id, ashaName: worker.name);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(ashaId: worker.id, ashaName: worker.name)),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.statusCode == 404
          ? 'No ASHA worker found for that phone number. Contact your facility admin.'
          : 'Could not log in: ${e.message}');
    } catch (e) {
      setState(() => _error = 'Could not reach the server. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
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
                const Icon(Icons.health_and_safety, size: 72, color: Color(0xFF1976D2)),
                const SizedBox(height: 16),
                const Text(
                  'SwasthyaSetu',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
                ),
                const Text('ASHA Worker App', style: TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 32),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Registered phone number',
                    hintText: '+919876543210',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Log in'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
