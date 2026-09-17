import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../services/session_service.dart';
import 'appointments_screen.dart';
import 'referrals_screen.dart';
import 'call_history_screen.dart';
import 'login_screen.dart';
import 'voice_symptom_screen.dart';

class HomeScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const HomeScreen({super.key, required this.patientId, required this.patientName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  final _sessionService = SessionService();

  Future<void> _logout() async {
    await _sessionService.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _callHelpline() async {
    final uri = Uri(scheme: 'tel', path: AppConfig.helplineNumber);
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _HomeTab(
        patientName: widget.patientName,
        onCallHelpline: _callHelpline,
        onOpenVoiceCheck: () => setState(() => _tabIndex = 1),
      ),
      VoiceSymptomScreen(patientId: widget.patientId),
      AppointmentsScreen(patientId: widget.patientId),
      ReferralsScreen(patientId: widget.patientId),
      CallHistoryScreen(patientId: widget.patientId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('SwasthyaSetu'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout, tooltip: 'Log out'),
        ],
      ),
      body: screens[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.mic), label: 'Voice Check'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Appointments'),
          NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Referrals'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Call History'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _callHelpline,
        backgroundColor: Colors.red,
        icon: const Icon(Icons.call),
        label: const Text('Call Helpline'),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final String patientName;
  final VoidCallback onCallHelpline;
  final VoidCallback onOpenVoiceCheck;

  const _HomeTab({
    required this.patientName,
    required this.onCallHelpline,
    required this.onOpenVoiceCheck,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome, $patientName', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            'SwasthyaSetu is a healthcare access and decision-support system. '
            'It does not replace your doctor.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),

          // Voice Symptom Checker Callout Card
          Card(
            elevation: 3,
            color: const Color(0xFFE0F2F1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Color(0xFF00695C),
                        radius: 20,
                        child: Icon(Icons.mic, color: Colors.white, size: 24),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Speak Your Symptoms (आवाज़ से लक्षण बताएं)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Talk in Hindi, Telugu, Tamil, or English',
                              style: TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Speak how you feel. SwasthyaSetu converts your speech to text in real time, screens for emergency red flags, and guides your care.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onOpenVoiceCheck,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00695C),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.record_voice_over, size: 18),
                    label: const Text('Start Voice Check (आवाज़ से बताएं)'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          Card(
            color: const Color(0xFFFFF3E0),
            child: ListTile(
              leading: const Icon(Icons.warning_amber, color: Colors.deepOrange),
              title: const Text('Medical emergency?'),
              subtitle: const Text('Call the helpline immediately or seek nearby emergency help.'),
              trailing: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: onCallHelpline,
                child: const Text('Call'),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Quick actions', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _quickAction(Icons.mic, 'Voice Symptom Check', onOpenVoiceCheck),
              _quickAction(Icons.calendar_month, 'Appointments', null),
              _quickAction(Icons.swap_horiz, 'Referrals', null),
              _quickAction(Icons.history, 'Call History', null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback? onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: const Color(0xFF00695C)),
      label: Text(label),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      onPressed: onTap,
    );
  }
}
