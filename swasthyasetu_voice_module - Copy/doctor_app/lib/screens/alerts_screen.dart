import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/doctor_models.dart';
import '../services/api_service.dart';

Color _statusColor(String status) {
  switch (status) {
    case 'UNACKNOWLEDGED':
      return const Color(0xFFD32F2F);
    case 'ACKNOWLEDGED':
      return const Color(0xFFF57C00);
    case 'CONTACTING':
      return const Color(0xFFFBC02D);
    case 'REACHED':
      return const Color(0xFF388E3C);
    case 'ESCALATED':
      return const Color(0xFF7B1FA2);
    case 'UNABLE_TO_REACH':
      return const Color(0xFF616161);
    case 'RESOLVED':
      return const Color(0xFF1976D2);
    default:
      return Colors.black54;
  }
}

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _apiService = ApiService();
  List<DoctorEmergencyEvent> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _apiService.fetchEmergencyEvents();
      if (!mounted) return;
      setState(() {
        _events = data;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load alerts: ${e.message}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach the server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _events.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _events.isEmpty) {
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
    if (_events.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No emergency alerts yet.')),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _events.length,
        itemBuilder: (context, index) {
          final e = _events[index];
          final color = _statusColor(e.status);
          final isUnacknowledged = e.status == 'UNACKNOWLEDGED';
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            elevation: isUnacknowledged ? 4 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isUnacknowledged ? const BorderSide(color: Color(0xFFD32F2F), width: 1.5) : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(e.redFlagType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color, width: 1),
                        ),
                        child: Text(
                          e.status.replaceAll('_', ' '),
                          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Patient: ${e.patientId ?? "Unverified caller"}', style: const TextStyle(color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(
                    'Severity: ${e.severity} · Assigned ASHA: ${e.assignedAshaId ?? "—"}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM d, h:mm a').format(e.createdAt.toLocal()),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
