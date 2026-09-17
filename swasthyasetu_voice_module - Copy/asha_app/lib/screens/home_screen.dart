import 'package:flutter/material.dart';

import '../services/session_service.dart';
import '../services/api_service.dart';
import '../services/offline_sync_service.dart';
import 'alerts_screen.dart';
import 'patients_screen.dart';
import 'voice_note_screen.dart';
import 'follow_ups_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String ashaId;
  final String ashaName;

  const HomeScreen({super.key, required this.ashaId, required this.ashaName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  final _sessionService = SessionService();
  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    OfflineSyncService.instance.init();
    OfflineSyncService.instance.addListener(_onSyncChanged);
  }

  @override
  void dispose() {
    OfflineSyncService.instance.removeListener(_onSyncChanged);
    _apiService.dispose();
    super.dispose();
  }

  void _onSyncChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _triggerManualSync() async {
    final pending = OfflineSyncService.instance.pendingCount;
    if (pending == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data is already in sync with the hospital server!')),
      );
      return;
    }

    final count = await OfflineSyncService.instance.syncWithBackend(_apiService, widget.ashaId);
    if (!mounted) return;

    if (count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully synced $count items with server!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not reach backend server. Items remain queued offline.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _logout() async {
    await _sessionService.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncService = OfflineSyncService.instance;
    final pendingCount = syncService.pendingCount;
    final isSyncing = syncService.isSyncing;

    final screens = [
      AlertsScreen(ashaId: widget.ashaId),
      const VoiceNoteScreen(),
      const FollowUpsScreen(),
      PatientsScreen(ashaId: widget.ashaId),
    ];

    return Scaffold(
      body: screens[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.warning_amber),
            selectedIcon: Icon(Icons.warning),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic_none),
            selectedIcon: Icon(Icons.mic),
            label: 'Voice Note',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Follow-ups',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Patients',
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF0D47A1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.medical_services, size: 28, color: Color(0xFF0D47A1)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.ashaName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Text('Accredited Social Health Activist (ASHA)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(
                  pendingCount > 0 ? Icons.sync_problem : Icons.cloud_done,
                  color: pendingCount > 0 ? Colors.orange : Colors.green,
                ),
                title: const Text('Offline Sync Queue'),
                subtitle: Text(
                  isSyncing
                      ? 'Reconciling queued records...'
                      : pendingCount > 0
                          ? '$pendingCount pending change(s)'
                          : 'Up to date with central database',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.sync),
                        tooltip: 'Sync now',
                        onPressed: _triggerManualSync,
                      ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.assignment_turned_in_outlined),
                title: const Text('My Daily Visits'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _tabIndex = 2);
                },
              ),
              ListTile(
                leading: const Icon(Icons.mic_external_on_outlined),
                title: const Text('Clinical Voice Assistant'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _tabIndex = 1);
                },
              ),
              const Spacer(),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Log out', style: TextStyle(color: Colors.red)),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
