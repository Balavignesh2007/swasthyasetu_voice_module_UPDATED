import 'dart:async';
import 'package:flutter/material.dart';
import '../models/unified_models.dart';
import '../services/unified_api_service.dart';
import '../services/unified_session_service.dart';
import '../services/localization_service.dart';
import '../services/patient_location_service.dart';
import '../widgets/chatbot/global_chatbot.dart';
import 'unified_login_screen.dart';

// Doctor views
import 'doctor/doctor_appointments_view.dart';
import 'doctor/doctor_teleconsult_view.dart';
import 'doctor/doctor_alerts_view.dart';
import 'doctor/doctor_stats_view.dart';

// ASHA views
import 'asha/asha_voice_note_view.dart';
import 'asha/asha_patients_view.dart';
import 'asha/asha_alerts_view.dart';

// Patient views
import 'patient/patient_home_view.dart';
import 'patient/patient_voice_symptom_view.dart';
import 'patient/patient_appointments_view.dart';
import 'patient/patient_referrals_view.dart';

// PHC Admin view (Replacing District Admin)
import 'admin/phc_admin_view.dart';

// Pharmacy view
import 'pharmacy/pharmacy_view.dart';

// Laboratory view
import 'lab/laboratory_view.dart';

class UnifiedShell extends StatefulWidget {
  final UnifiedUserSession initialSession;

  const UnifiedShell({super.key, required this.initialSession});

  @override
  State<UnifiedShell> createState() => _UnifiedShellState();
}

class _UnifiedShellState extends State<UnifiedShell> {
  late UnifiedUserSession _session;
  late UnifiedApiService _api;
  final _sessionService = UnifiedSessionService();
  int _selectedIndex = 0;
  Timer? _alertPollTimer;
  int _unackDoctorAlerts = 0;

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
    _api = UnifiedApiService();
    if (_session.token != null) {
      _api.authToken = _session.token;
    }
    _startAlertMonitoring();
  }

  void _startAlertMonitoring() {
    _checkAlertsSilently();
    _alertPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkAlertsSilently();
    });
  }

  Future<void> _checkAlertsSilently() async {
    if (!mounted || _session.role != UserRole.doctor) return;
    try {
      final alerts = await _api.fetchDoctorAlerts();
      final unack = alerts.where((a) => a.status.toUpperCase() == 'UNACKNOWLEDGED').toList();
      if (mounted) {
        setState(() {
          _unackDoctorAlerts = unack.length;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _alertPollTimer?.cancel();
    _api.dispose();
    super.dispose();
  }

  Color get _themeColor {
    switch (_session.role) {
      case UserRole.patient:
        return const Color(0xFF1D4ED8); // Royal Blue
      case UserRole.asha:
        return const Color(0xFF0D9488); // Emerald / Teal
      case UserRole.doctor:
        return const Color(0xFF0F766E); // Deep Teal
      case UserRole.pharmacy:
        return const Color(0xFF059669); // Forest Green
      case UserRole.lab:
        return const Color(0xFF6366F1); // Indigo / Purple
      case UserRole.phcAdmin:
        return const Color(0xFF4338CA); // Royal Indigo
    }
  }

  Future<void> _switchRole(UserRole targetRole) async {
    if (targetRole == _session.role) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final newSession = await _api.demoLogin(targetRole);
      await _sessionService.saveSession(newSession);
      if (!mounted) return;
      setState(() {
        _session = newSession;
        if (newSession.token != null) {
          _api.authToken = newSession.token;
        }
        _selectedIndex = 0;
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text('Switched to ${newSession.role.displayName} Portal (${newSession.name})'),
          backgroundColor: _themeColor,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to switch role: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _logout() async {
    await _sessionService.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const UnifiedLoginScreen()),
    );
  }

  void _triggerEmergencySos() {
    final loc = AppLocalizationService.instance;
    final locService = PatientLocationService.instance;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.emergency_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text(loc.t('emergency_sos'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🚨 Emergency SOS Triggered! (Maharashtra Grid)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            const Text('• 108 Emergency Cardiac & Trauma Ambulance Alerted (Maharashtra)'),
            const Text('• Shivaji Nagar PHC Emergency Duty Staff Notified'),
            const Text('• Assigned ASHA Worker Alerted for Rapid First Aid'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Dispatched Patient GPS: ${locService.locationName} (${locService.coordinatesDisplay})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.t('btn_close')),
          ),
        ],
      ),
    );
  }

  List<NavigationDestination> _getDestinations(bool isMobile) {
    final loc = AppLocalizationService.instance;
    switch (_session.role) {
      case UserRole.patient:
        return [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: isMobile ? 'Home' : loc.t('nav_patient_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_today_outlined),
            selectedIcon: const Icon(Icons.calendar_today),
            label: isMobile ? 'Consults' : loc.t('nav_my_consultations'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.local_hospital_outlined),
            selectedIcon: const Icon(Icons.local_hospital),
            label: isMobile ? 'Referrals' : loc.t('nav_hospital_referrals'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.mic_none_rounded),
            selectedIcon: const Icon(Icons.mic_rounded),
            label: isMobile ? 'Voice Check' : loc.t('nav_voice_checker'),
          ),
        ];

      case UserRole.asha:
        return [
          NavigationDestination(
            icon: const Icon(Icons.mic_outlined),
            selectedIcon: const Icon(Icons.mic),
            label: isMobile ? 'Voice Note' : loc.t('nav_voice_symptoms'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: isMobile ? 'Patients' : loc.t('nav_patients_followups'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.notifications_outlined),
            selectedIcon: const Icon(Icons.notifications),
            label: isMobile ? 'Alerts' : loc.t('nav_alerts_visits'),
          ),
        ];

      case UserRole.doctor:
        return [
          NavigationDestination(
            icon: const Icon(Icons.assignment_outlined),
            selectedIcon: const Icon(Icons.assignment),
            label: isMobile ? 'OPD Queue' : loc.t('nav_opd_appointments'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.video_call_outlined),
            selectedIcon: const Icon(Icons.video_call_rounded),
            label: isMobile ? 'Teleconsult' : loc.t('nav_teleconsultation'),
          ),
          NavigationDestination(
            icon: _unackDoctorAlerts > 0
                ? Badge.count(
                    count: _unackDoctorAlerts,
                    backgroundColor: const Color(0xFFDC2626),
                    child: const Icon(Icons.warning_amber_rounded),
                  )
                : const Icon(Icons.warning_amber_rounded),
            selectedIcon: const Icon(Icons.warning_rounded),
            label: isMobile ? 'Alerts' : loc.t('nav_emergency_alerts'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: isMobile ? 'Analytics' : loc.t('nav_clinical_kpi'),
          ),
        ];

      case UserRole.pharmacy:
        return [
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long_rounded),
            label: isMobile ? 'Pharmacy' : loc.t('nav_pharmacy_inventory'),
          ),
        ];

      case UserRole.lab:
        return [
          NavigationDestination(
            icon: const Icon(Icons.biotech_outlined),
            selectedIcon: const Icon(Icons.biotech_rounded),
            label: isMobile ? 'Lab' : loc.t('nav_lab_records'),
          ),
        ];

      case UserRole.phcAdmin:
        return [
          NavigationDestination(
            icon: const Icon(Icons.speed_rounded),
            selectedIcon: const Icon(Icons.speed_rounded),
            label: isMobile ? 'Overview' : loc.t('nav_phc_overview'),
          ),
        ];
    }
  }

  Widget _buildBody() {
    switch (_session.role) {
      case UserRole.patient:
        if (_selectedIndex == 0) {
          return PatientHomeView(
            api: _api,
            session: _session,
            onNavigateTab: (tabIdx) => setState(() => _selectedIndex = tabIdx),
          );
        }
        if (_selectedIndex == 1) return PatientAppointmentsView(api: _api, session: _session);
        if (_selectedIndex == 2) return PatientReferralsView(api: _api, session: _session);
        return PatientVoiceSymptomView(api: _api, session: _session);

      case UserRole.asha:
        if (_selectedIndex == 0) return AshaVoiceNoteView(api: _api, session: _session);
        if (_selectedIndex == 1) return AshaPatientsView(api: _api, session: _session);
        return AshaAlertsView(api: _api, session: _session);

      case UserRole.doctor:
        if (_selectedIndex == 0) return DoctorAppointmentsView(api: _api, session: _session);
        if (_selectedIndex == 1) return DoctorTeleconsultView(api: _api, session: _session);
        if (_selectedIndex == 2) return DoctorAlertsView(api: _api);
        return DoctorStatsView(api: _api);

      case UserRole.pharmacy:
        return PharmacyView(api: _api, session: _session);

      case UserRole.lab:
        return LaboratoryView(api: _api, session: _session);

      case UserRole.phcAdmin:
        return PHCAdminView(api: _api, session: _session);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizationService.instance;
    final locService = PatientLocationService.instance;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final destinations = _getDestinations(isMobile);

    return AnimatedBuilder(
      animation: Listenable.merge([loc, locService]),
      builder: (context, _) {
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(isMobile ? 58 : 68),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 20,
                vertical: isMobile ? 6 : 8,
              ),
              child: Row(
                children: [
                  // Logo
                  Container(
                    padding: EdgeInsets.all(isMobile ? 6 : 8),
                    decoration: BoxDecoration(
                      color: _themeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.local_hospital, color: _themeColor, size: isMobile ? 20 : 26),
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                loc.t('platform_title'),
                                style: TextStyle(
                                  fontSize: isMobile ? 15 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _themeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _session.role.displayName.toUpperCase(),
                                style: TextStyle(
                                  fontSize: isMobile ? 9 : 11,
                                  fontWeight: FontWeight.bold,
                                  color: _themeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!isMobile)
                          Text(
                            loc.t('platform_subtitle'),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          )
                        else if (_session.role == UserRole.patient)
                          Text(
                            '📍 ${locService.locationName.split(',').first}, MH',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: locService.isLiveGps ? const Color(0xFF059669) : const Color(0xFF1D4ED8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  if (isMobile) ...[
                    // Mobile Touch Actions
                    IconButton(
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.translate, color: Color(0xFF334155), size: 20),
                      tooltip: 'Language',
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          builder: (sheetCtx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(14.0),
                                  child: Text('Select Language / भाषा निवडा', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                                const Divider(height: 1),
                                ...AppLanguage.values.map((lang) {
                                  final isSel = lang == loc.currentLanguage;
                                  return ListTile(
                                    dense: true,
                                    title: Text(lang.label, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                                    trailing: isSel ? const Icon(Icons.check, color: Color(0xFF0F766E)) : null,
                                    onTap: () {
                                      loc.setLanguage(lang);
                                      Navigator.pop(sheetCtx);
                                    },
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.swap_horiz, color: Color(0xFF334155), size: 22),
                      tooltip: 'Switch Portal',
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          builder: (sheetCtx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(14.0),
                                  child: Text('Switch Portal / Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                                const Divider(height: 1),
                                ...[
                                  (UserRole.patient, Icons.person, 'Patient Portal', const Color(0xFF1D4ED8)),
                                  (UserRole.asha, Icons.volunteer_activism, 'ASHA Worker', const Color(0xFF0D9488)),
                                  (UserRole.doctor, Icons.medical_services, 'Doctor Portal', const Color(0xFF0F766E)),
                                  (UserRole.pharmacy, Icons.local_pharmacy, 'Pharmacy Staff', const Color(0xFF059669)),
                                  (UserRole.lab, Icons.biotech, 'Lab Technician', const Color(0xFF6366F1)),
                                  (UserRole.phcAdmin, Icons.admin_panel_settings, 'PHC Admin', const Color(0xFF4338CA)),
                                ].map((item) {
                                  final isSel = item.$1 == _session.role;
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(item.$2, color: item.$4),
                                    title: Text(item.$3, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                                    trailing: isSel ? const Icon(Icons.check, color: Color(0xFF0F766E)) : null,
                                    onTap: () {
                                      Navigator.pop(sheetCtx);
                                      _switchRole(item.$1);
                                    },
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.emergency_rounded, color: Colors.red, size: 20),
                      tooltip: '108 SOS',
                      onPressed: _triggerEmergencySos,
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.logout, color: Color(0xFF64748B), size: 20),
                      tooltip: 'Logout',
                      onPressed: _logout,
                    ),
                  ] else ...[
                    // Desktop Language Selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<AppLanguage>(
                          value: loc.currentLanguage,
                          icon: const Icon(Icons.language, color: Color(0xFF334155), size: 16),
                          items: AppLanguage.values.map((lang) {
                            return DropdownMenuItem<AppLanguage>(
                              value: lang,
                              child: Text(lang.label, style: const TextStyle(fontSize: 12)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              loc.setLanguage(val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Desktop Role Switcher
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<UserRole>(
                          value: _session.role,
                          icon: const Icon(Icons.swap_horiz, color: Color(0xFF334155), size: 20),
                          items: const [
                            DropdownMenuItem(
                              value: UserRole.patient,
                              child: Row(
                                children: [
                                  Icon(Icons.person, size: 16, color: Color(0xFF1D4ED8)),
                                  SizedBox(width: 6),
                                  Text('Patient Portal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: UserRole.asha,
                              child: Row(
                                children: [
                                  Icon(Icons.volunteer_activism, size: 16, color: Color(0xFF0D9488)),
                                  SizedBox(width: 6),
                                  Text('ASHA Worker', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: UserRole.doctor,
                              child: Row(
                                children: [
                                  Icon(Icons.medical_services, size: 16, color: Color(0xFF0F766E)),
                                  SizedBox(width: 6),
                                  Text('Doctor Portal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: UserRole.pharmacy,
                              child: Row(
                                children: [
                                  Icon(Icons.local_pharmacy, size: 16, color: Color(0xFF059669)),
                                  SizedBox(width: 6),
                                  Text('Pharmacy Staff', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: UserRole.lab,
                              child: Row(
                                children: [
                                  Icon(Icons.biotech, size: 16, color: Color(0xFF6366F1)),
                                  SizedBox(width: 6),
                                  Text('Lab Technician', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: UserRole.phcAdmin,
                              child: Row(
                                children: [
                                  Icon(Icons.admin_panel_settings, size: 16, color: Color(0xFF4338CA)),
                                  SizedBox(width: 6),
                                  Text('PHC Admin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (role) {
                            if (role != null) _switchRole(role);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Emergency SOS Button
                    IconButton(
                      icon: const Icon(Icons.emergency_rounded, color: Colors.red),
                      tooltip: 'Emergency SOS (108 Dispatch)',
                      onPressed: _triggerEmergencySos,
                    ),

                    // Logout
                    IconButton(
                      icon: const Icon(Icons.logout, color: Color(0xFF64748B)),
                      tooltip: 'Logout',
                      onPressed: _logout,
                    ),
                  ],
                ],
              ),
            ),
          ),
          body: Stack(
            children: [
              _buildBody(),
              // Global Chatbot Assistant
              GlobalChatbot(session: _session, themeColor: _themeColor),
            ],
          ),
          bottomNavigationBar: destinations.length > 1
              ? NavigationBar(
                  height: isMobile ? 64 : 76,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  selectedIndex: _selectedIndex < destinations.length ? _selectedIndex : 0,
                  onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
                  destinations: destinations,
                  indicatorColor: _themeColor.withValues(alpha: 0.15),
                )
              : null,
        );
      },
    );
  }
}
