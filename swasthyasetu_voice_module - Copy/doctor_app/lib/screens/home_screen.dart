import 'package:flutter/material.dart';

import '../models/doctor_models.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'alerts_screen.dart';
import 'login_screen.dart';
import 'overview_screen.dart';
import 'referrals_screen.dart';

class HomeScreen extends StatefulWidget {
  final DoctorProfile doctor;

  const HomeScreen({super.key, required this.doctor});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  final _sessionService = SessionService();

  static const _screens = [
    OverviewScreen(),
    AlertsScreen(),
    ReferralsScreen(),
  ];

  static const _titles = ['Overview', 'Emergency Alerts', 'Referrals & Appointments'];

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
    Navigator.of(context).pop(); // close the drawer first
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1976D2),
        title: Text(_titles[_tabIndex]),
      ),
      body: _screens[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.warning_amber), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Referrals'),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0xFF1976D2),
                      child: Icon(Icons.person, size: 28, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(widget.doctor.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      widget.doctor.speciality ??
                          (widget.doctor.role[0].toUpperCase() + widget.doctor.role.substring(1)),
                      style: const TextStyle(color: Colors.black54),
                    ),
                    Text('@${widget.doctor.username}', style: const TextStyle(color: Colors.black38, fontSize: 12)),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log out'),
                onTap: _confirmLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
