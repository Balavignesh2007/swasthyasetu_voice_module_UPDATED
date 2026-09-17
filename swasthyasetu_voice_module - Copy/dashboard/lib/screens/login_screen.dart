import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import 'dashboard_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  final _sessionService = SessionService();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _apiService.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      await _sessionService.saveSession(token: result.accessToken, doctor: result.doctor);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => DashboardShell(doctor: result.doctor)),
      );
    } on ApiException catch (e) {
      setState(() {
        _error = e.statusCode == 401
            ? 'Incorrect username or password.'
            : 'Could not log in: ${e.message}';
      });
    } catch (_) {
      setState(() => _error = 'Could not reach the server. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _apiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.health_and_safety, size: 72, color: Color(0xFF1976D2)),
                    const SizedBox(height: 16),
                    const Text(
                      'SwasthyaSetu',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
                    ),
                    const Text('Doctor Login', style: TextStyle(fontSize: 14, color: Colors.black54)),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _usernameController,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: 'dr.sharma',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your username' : null,
                      onFieldSubmitted: (_) => _loading ? null : _login(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                      onFieldSubmitted: (_) => _loading ? null : _login(),
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
                        'Demo Staff Accounts (Tap to fill):',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.medical_services, size: 14),
                          label: const Text('Dr. Sharma (Doctor)', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            _usernameController.text = 'dr.sharma';
                            _passwordController.text = 'doctor123';
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.local_hospital, size: 14),
                          label: const Text('Facility Admin', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            _usernameController.text = 'fac.admin';
                            _passwordController.text = 'admin123';
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.admin_panel_settings, size: 14),
                          label: const Text('System Admin', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            _usernameController.text = 'admin';
                            _passwordController.text = 'admin12345';
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.headset_mic, size: 14),
                          label: const Text('Helpline Worker', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            _usernameController.text = 'helpline.worker';
                            _passwordController.text = 'helpline123';
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
                          backgroundColor: const Color(0xFF1976D2),
                        ),
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Log in to Clinical Portal', style: TextStyle(fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Access restricted to registered doctors and program staff. '
                      "Contact your facility admin if you don't have credentials.",
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
