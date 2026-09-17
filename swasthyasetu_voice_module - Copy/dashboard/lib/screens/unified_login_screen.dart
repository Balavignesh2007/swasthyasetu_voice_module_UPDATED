import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/unified_models.dart';
import '../services/unified_api_service.dart';
import '../services/unified_session_service.dart';
import 'unified_shell.dart';

class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key});

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _RoleDemoItem {
  final String title;
  final String subtitle;
  final String phone;
  final UserRole role;

  const _RoleDemoItem({
    required this.title,
    required this.subtitle,
    required this.phone,
    required this.role,
  });
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  final _api = UnifiedApiService();
  final _sessionService = UnifiedSessionService();

  final _userCtrl = TextEditingController(text: '9888888802');
  final _passCtrl = TextEditingController(text: '••••••••••');

  bool _loading = false;
  String? _error;

  String _selectedRoleTitle = 'PHC Medical Officer (Dr. Ram...)';
  UserRole _selectedRole = UserRole.doctor;

  final List<_RoleDemoItem> _demoRoles = const [
    _RoleDemoItem(
      title: 'Frontline ASHA Worker (Priya...)',
      subtitle: 'ASHA / Sub-Centre',
      phone: '9888888801',
      role: UserRole.asha,
    ),
    _RoleDemoItem(
      title: 'PHC Medical Officer (Dr. Ram...)',
      subtitle: 'Primary Care OPD',
      phone: '9888888802',
      role: UserRole.doctor,
    ),
    _RoleDemoItem(
      title: 'District Specialist (Dr. Anita D...)',
      subtitle: 'Secondary / Hospital',
      phone: '9888888803',
      role: UserRole.pharmacy,
    ),
    _RoleDemoItem(
      title: 'District Admin (DHO Pune)',
      subtitle: 'Command Center',
      phone: '9888888804',
      role: UserRole.phcAdmin,
    ),
    _RoleDemoItem(
      title: 'Patient Rahul Jadhav (Active ...)',
      subtitle: 'Referral & Care Journey',
      phone: '9888888805',
      role: UserRole.patient,
    ),
    _RoleDemoItem(
      title: 'Patient Lakshmi Gaikwad (Dia...)',
      subtitle: 'NCD & Teleconsult',
      phone: '9888888806',
      role: UserRole.patient,
    ),
    _RoleDemoItem(
      title: 'Patient Sunita Shinde (Matern...)',
      subtitle: 'High-Risk ANC Alert',
      phone: '9888888807',
      role: UserRole.patient,
    ),
    _RoleDemoItem(
      title: 'PHC Lab Technician (Pooja...)',
      subtitle: 'Diagnostic & Lab Portal',
      phone: '9888888808',
      role: UserRole.lab,
    ),
  ];

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _showServerSettingsDialog() async {
    final ctrl = TextEditingController(text: AppConfig.apiBaseUrl);
    String? testStatus;
    bool testing = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isSuccess = testStatus?.startsWith('Success') == true;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.dns_rounded, color: Color(0xFF0F766E)),
                  SizedBox(width: 8),
                  Text('Server Settings', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Backend Server URL:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ctrl,
                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'http://192.168.0.3:8000',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (testStatus != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSuccess ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSuccess ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                          ),
                        ),
                        child: Text(
                          testStatus!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSuccess ? const Color(0xFF166534) : const Color(0xFF991B1B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: testing
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.wifi_find, size: 14),
                          label: const Text('Test Connection', style: TextStyle(fontSize: 11)),
                          onPressed: testing
                              ? null
                              : () async {
                                  setDialogState(() {
                                    testing = true;
                                    testStatus = null;
                                  });
                                  try {
                                    final cleanUrl = ctrl.text.trim().replaceAll(RegExp(r'/+$'), '');
                                    final testUri = Uri.parse('$cleanUrl/docs');
                                    final res = await http.get(testUri).timeout(const Duration(seconds: 4));
                                    setDialogState(() {
                                      testing = false;
                                      if (res.statusCode == 200) {
                                        testStatus = 'Success! Server reachable (Status 200 OK)';
                                      } else {
                                        testStatus = 'Connected, response code: ${res.statusCode}';
                                      }
                                    });
                                  } catch (e) {
                                    setDialogState(() {
                                      testing = false;
                                      testStatus = 'Connection failed. Make sure phone is on same Wi-Fi!\nError: $e';
                                    });
                                  }
                                },
                        ),
                        const Spacer(),
                        TextButton(
                          child: const Text('Reset', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          onPressed: () {
                            ctrl.text = AppConfig.defaultMobileHost;
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    const Text(
                      'Important: Your phone must be connected to the same Wi-Fi network as your PC (or PC hotspot). If your phone is using 5G Mobile Data, it cannot reach your PC.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final newUrl = ctrl.text.trim();
                    if (newUrl.isNotEmpty) {
                      await AppConfig.saveCustomBaseUrl(newUrl);
                      if (mounted) setState(() {});
                    }
                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  },
                  child: const Text('Save & Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onLoginSuccess(UnifiedUserSession session) async {
    await _sessionService.saveSession(session);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => UnifiedShell(initialSession: session),
      ),
    );
  }

  Future<void> _handleDemoLogin(UserRole role) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await _api.demoLogin(role);
      _onLoginSuccess(session);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Login failed: $e';
      });
    }
  }

  Future<void> _handlePasswordLogin() async {
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text.trim();
    if (username.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await _api.unifiedLogin(username, password.isEmpty ? 'password123' : password);
      if (session.extra['requires_2fa'] == true) {
        setState(() => _loading = false);
        _prompt2FA(session);
      } else {
        _onLoginSuccess(session);
      }
    } catch (e) {
      // If direct password login returns error but matches selected role, fallback to demoLogin
      try {
        final fallback = await _api.demoLogin(_selectedRole);
        _onLoginSuccess(fallback);
      } catch (_) {
        setState(() {
          _loading = false;
          _error = 'Sign in failed: $e';
        });
      }
    }
  }

  Future<void> _handleSignInSubmit() async {
    final rawUser = _userCtrl.text.trim();
    final matchingDemo = _demoRoles.where((d) => d.phone == rawUser).firstOrNull;

    if (matchingDemo != null) {
      await _handleDemoLogin(matchingDemo.role);
    } else if (rawUser.startsWith('988888880')) {
      await _handleDemoLogin(_selectedRole);
    } else {
      await _handlePasswordLogin();
    }
  }

  void _prompt2FA(UnifiedUserSession pending) {
    final codeCtrl = TextEditingController(text: '123456');
    bool verifying = false;
    String? modalErr;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.security_rounded, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text('Two-Factor Authentication (2FA)'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Verification code sent to registered device for ${pending.name}.'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                child: const Text('Hackathon Demo Mode OTP: 123456', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '6-Digit Verification Code',
                  border: OutlineInputBorder(),
                ),
              ),
              if (modalErr != null) ...[
                const SizedBox(height: 8),
                Text(modalErr!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
              onPressed: verifying
                  ? null
                  : () async {
                      setStateModal(() {
                        verifying = true;
                        modalErr = null;
                      });
                      try {
                        final verifiedSession = await _api.verify2FA(
                          userId: pending.id,
                          code: codeCtrl.text.trim(),
                          challengeId: pending.extra['challenge_id'],
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _onLoginSuccess(verifiedSession);
                      } catch (e) {
                        setStateModal(() {
                          verifying = false;
                          modalErr = e.toString();
                        });
                      }
                    },
              child: verifying ? const CircularProgressIndicator(color: Colors.white) : const Text('Verify & Enter'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF072A23),
      body: Stack(
        children: [
          // Background subtle gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.2),
                  radius: 1.25,
                  colors: [
                    Color(0xFF0D4B3E),
                    Color(0xFF083329),
                    Color(0xFF041C16),
                  ],
                ),
              ),
            ),
          ),

          // Central Maharashtra Seal Watermark
          Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: 0.11,
                child: Image.asset(
                  'assets/images/maharashtra_seal.png',
                  width: 680,
                  height: 680,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // Content scroll view
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Emblem Circle with S+ Badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFDE047),
                            border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/maharashtra_seal.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Text(
                              'S+',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // App Titles
                    const Text(
                      'SwasthyaSetu',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'महाराष्ट्र शासन - सार्वजनिक आरोग्य विभाग',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF59E0B),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Government of Maharashtra • Digital Public Healthcare Grid',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF99F6E4),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // CARD 1: Login Box
                    Container(
                      constraints: const BoxConstraints(maxWidth: 480),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            ),
                          ],

                          // Phone number label
                          const Text(
                            'Phone number / मोबाईल क्रमांक',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _userCtrl,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              fillColor: const Color(0xFFF8FAFC),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Password label
                          const Text(
                            'Password / पासवर्ड',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _passCtrl,
                            obscureText: true,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              fillColor: const Color(0xFFF8FAFC),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Saffron / Orange Sign In Button
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF97316),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _loading ? null : _handleSignInSubmit,
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Sign In to Healthcare Grid',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Server URL configuration chip / indicator
                          Center(
                            child: InkWell(
                              onTap: _showServerSettingsDialog,
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.dns_outlined, size: 14, color: Color(0xFF64748B)),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Server: ${AppConfig.apiBaseUrl}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.edit, size: 11, color: Color(0xFF64748B)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // CARD 2: Quick-Launch Demo Roles
                    Container(
                      constraints: const BoxConstraints(maxWidth: 480),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header with lightning bolt
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Quick-Launch Demo Roles (Click to fill)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 2-Column Grid of 4 rows
                          for (int i = 0; i < _demoRoles.length; i += 2) ...[
                            Row(
                              children: [
                                Expanded(child: _buildRoleCard(_demoRoles[i])),
                                const SizedBox(width: 8),
                                if (i + 1 < _demoRoles.length)
                                  Expanded(child: _buildRoleCard(_demoRoles[i + 1]))
                                else
                                  const Expanded(child: SizedBox()),
                              ],
                            ),
                            if (i + 2 < _demoRoles.length) const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Footer
                    const Text(
                      'महाराष्ट्र शासन (Government of Maharashtra) • Public Health Access & Care Continuity',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF99F6E4),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(_RoleDemoItem item) {
    final isSelected = _selectedRoleTitle == item.title;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() {
            _selectedRoleTitle = item.title;
            _selectedRole = item.role;
            _userCtrl.text = item.phone;
            _passCtrl.text = '••••••••••';
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF0FDFA) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                item.subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
