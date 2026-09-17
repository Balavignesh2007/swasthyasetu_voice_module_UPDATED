import 'dart:async';
import 'package:flutter/material.dart';

import '../config.dart';
import '../models/doctor_models.dart';
import '../services/api_service.dart';
import '../widgets/stat_card.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  final _apiService = ApiService();
  DashboardStats? _stats;
  String? _error;
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(AppConfig.refreshInterval, (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final stats = await _apiService.fetchStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load dashboard: ${e.message}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach the backend at ${AppConfig.apiBaseUrl}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _stats == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _stats == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final s = _stats!;
    final cards = [
      StatCard(label: 'Total Calls', value: s.totalCalls, icon: Icons.call, color: Colors.blueGrey),
      StatCard(label: 'Active Calls', value: s.activeCalls, icon: Icons.phone_in_talk, color: Colors.blue),
      StatCard(label: 'Completed Calls', value: s.completedCalls, icon: Icons.check_circle, color: Colors.green),
      StatCard(label: 'Emergency Calls', value: s.emergencyCalls, icon: Icons.warning, color: Colors.red),
      StatCard(label: 'HIGH Cases', value: s.highCases, icon: Icons.priority_high, color: Colors.deepOrange),
      StatCard(label: 'LOW Cases', value: s.lowCases, icon: Icons.low_priority, color: Colors.teal),
      StatCard(label: 'ASHA Alerts', value: s.ashaAlerts, icon: Icons.notifications_active, color: Colors.purple),
      StatCard(
        label: 'Unack. Alerts',
        value: s.unacknowledgedAlerts,
        icon: Icons.notification_important,
        color: Colors.red[700]!,
      ),
      StatCard(label: 'Referrals', value: s.referralRequests, icon: Icons.swap_horiz, color: Colors.indigo),
      StatCard(label: 'Appointments', value: s.appointmentBookings, icon: Icons.calendar_month, color: Colors.brown),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Voice Helpline Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Emergency alerts receive the highest operational priority.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: cards,
            ),
          ],
        ),
      ),
    );
  }
}
