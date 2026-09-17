import 'package:flutter/material.dart';
import '../../models/unified_models.dart';
import '../../services/unified_api_service.dart';

class DoctorStatsView extends StatefulWidget {
  final UnifiedApiService api;

  const DoctorStatsView({super.key, required this.api});

  @override
  State<DoctorStatsView> createState() => _DoctorStatsViewState();
}

class _DoctorStatsViewState extends State<DoctorStatsView> {
  bool _loading = true;
  String? _error;
  DashboardStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await widget.api.fetchDoctorStats();
      if (mounted) {
        setState(() {
          _stats = s;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load stats: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Clinical Overview & Health Analytics',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Live telemetry for voice triage, ASHA notifications, and referral queues',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadStats,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                        : _stats == null
                            ? const Center(child: Text('No stats available'))
                            : _buildStatsGrid(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final s = _stats!;
    final cards = [
      {'title': 'Total Appointments', 'val': s.appointmentBookings, 'icon': Icons.calendar_today, 'color': Colors.blue},
      {'title': 'Active Referrals', 'val': s.referralRequests, 'icon': Icons.local_hospital, 'color': Colors.indigo},
      {'title': 'Emergency Calls', 'val': s.emergencyCalls, 'icon': Icons.warning_amber_rounded, 'color': Colors.red},
      {'title': 'Total Voice Calls', 'val': s.totalCalls, 'icon': Icons.phone_in_talk, 'color': Colors.teal},
      {'title': 'ASHA Alerts Sent', 'val': s.ashaAlerts, 'icon': Icons.notifications_active, 'color': Colors.orange},
      {'title': 'Unacknowledged', 'val': s.unacknowledgedAlerts, 'icon': Icons.pending_actions, 'color': Colors.deepOrange},
      {'title': 'High Triage Cases', 'val': s.highCases, 'icon': Icons.priority_high, 'color': Colors.purple},
      {'title': 'Routine Cases', 'val': s.lowCases, 'icon': Icons.check, 'color': Colors.green},
    ];

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.6,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final c = cards[index];
        final color = c['color'] as Color;
        return Card(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      c['title'] as String,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                    ),
                    Icon(c['icon'] as IconData, color: color, size: 22),
                  ],
                ),
                Text(
                  '${c['val']}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
