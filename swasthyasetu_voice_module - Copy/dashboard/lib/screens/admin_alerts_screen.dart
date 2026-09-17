import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/admin_models.dart';
import '../services/api_service.dart';

Color _statusColor(String status) {
  switch (status) {
    case 'UNACKNOWLEDGED':
      return Colors.red;
    case 'ACKNOWLEDGED':
      return Colors.orange;
    case 'CONTACTING':
      return Colors.amber[800]!;
    case 'REACHED':
      return Colors.green;
    case 'ESCALATED':
      return Colors.purple;
    case 'UNABLE_TO_REACH':
      return Colors.grey[700]!;
    case 'RESOLVED':
      return Colors.blue;
    default:
      return Colors.black54;
  }
}

class AdminAlertsScreen extends StatefulWidget {
  const AdminAlertsScreen({super.key});

  @override
  State<AdminAlertsScreen> createState() => _AdminAlertsScreenState();
}

class _AdminAlertsScreenState extends State<AdminAlertsScreen> {
  final _apiService = ApiService();
  List<AdminEmergencyEvent> _events = [];
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Emergency Alerts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Red Flag')),
                    DataColumn(label: Text('Patient')),
                    DataColumn(label: Text('Severity')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Assigned ASHA')),
                    DataColumn(label: Text('Time')),
                  ],
                  rows: _events.map((e) {
                    return DataRow(cells: [
                      DataCell(Text(e.redFlagType)),
                      DataCell(Text(e.patientId ?? 'Unverified')),
                      DataCell(Text(e.severity)),
                      DataCell(Chip(
                        label: Text(e.status, style: const TextStyle(fontSize: 11, color: Colors.white)),
                        backgroundColor: _statusColor(e.status),
                      )),
                      DataCell(Text(e.assignedAshaId ?? '—')),
                      DataCell(Text(DateFormat('MMM d, h:mm a').format(e.createdAt.toLocal()))),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
