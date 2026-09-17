import 'package:flutter/material.dart';

import '../models/admin_models.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'overview_screen.dart';
import 'admin_alerts_screen.dart';
import 'referrals_appointments_screen.dart';
import 'manage_doctors_screen.dart';
import 'login_screen.dart';

class DashboardShell extends StatefulWidget {
  final DoctorProfile doctor;

  const DashboardShell({super.key, required this.doctor});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _index = 0;
  final _sessionService = SessionService();

  bool get _isAdmin => widget.doctor.role == 'admin';

  List<Widget> get _screens => [
        const OverviewScreen(),
        const AdminAlertsScreen(),
        const ReferralsAppointmentsScreen(),
        if (_isAdmin) ManageDoctorsScreen(currentDoctor: widget.doctor),
      ];

  Future<void> _logout() async {
    await _sessionService.clearSession();
    ApiService.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("You'll need your username and password to log back in."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed == true) await _logout();
  }

  Widget _doctorBadge({bool compact = false}) {
    final doctor = widget.doctor;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(radius: 16, backgroundColor: Color(0xFF1976D2), child: Icon(Icons.person, size: 18, color: Colors.white)),
          if (!compact) ...[
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(doctor.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  doctor.speciality ?? doctor.role[0].toUpperCase() + doctor.role.substring(1),
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ],
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout, size: 20),
            onPressed: _confirmLogout,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: isWide
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1976D2),
              title: const Text('SwasthyaSetu'),
              actions: [_doctorBadge(compact: true)],
            ),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              extended: true,
              backgroundColor: Colors.white,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    const Icon(Icons.health_and_safety, size: 40, color: Color(0xFF1976D2)),
                    const SizedBox(height: 8),
                    const Text('SwasthyaSetu', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text('Doctor Dashboard', style: TextStyle(fontSize: 11, color: Colors.black54)),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    _doctorBadge(),
                    const Divider(height: 1),
                  ],
                ),
              ),
              destinations: [
                const NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Overview')),
                const NavigationRailDestination(icon: Icon(Icons.warning_amber), label: Text('Alerts')),
                const NavigationRailDestination(icon: Icon(Icons.swap_horiz), label: Text('Referrals & Appts')),
                if (_isAdmin)
                  const NavigationRailDestination(icon: Icon(Icons.admin_panel_settings), label: Text('Doctors')),
              ],
            ),
          Expanded(child: _screens[_index]),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                const NavigationDestination(icon: Icon(Icons.dashboard), label: 'Overview'),
                const NavigationDestination(icon: Icon(Icons.warning_amber), label: 'Alerts'),
                const NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Referrals'),
                if (_isAdmin)
                  const NavigationDestination(icon: Icon(Icons.admin_panel_settings), label: 'Doctors'),
              ],
            ),
    );
  }
}
