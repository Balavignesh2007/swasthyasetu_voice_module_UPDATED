import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/patient_models.dart';
import '../services/api_service.dart';

class AppointmentsScreen extends StatefulWidget {
  final String patientId;
  const AppointmentsScreen({super.key, required this.patientId});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _apiService = ApiService();
  List<PatientAppointment> _appointments = [];
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
      final data = await _apiService.fetchAppointments(widget.patientId);
      if (!mounted) return;
      setState(() {
        _appointments = data;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load appointments: ${e.message}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach the server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _appointments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _appointments.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(child: Text(_error!, textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          Center(child: OutlinedButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }
    if (_appointments.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Center(child: Text('No appointments yet.')),
          SizedBox(height: 8),
          Center(child: Text('Call the helpline to book one.', style: TextStyle(color: Colors.black54))),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _appointments.length,
      itemBuilder: (context, index) {
        final appt = _appointments[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _statusColor(appt.status).withValues(alpha: 0.15),
              child: Icon(Icons.calendar_today, color: _statusColor(appt.status)),
            ),
            title: Text(appt.speciality ?? 'General Consultation'),
            subtitle: Text([
              if (appt.queueNumber != null) 'Queue #${appt.queueNumber}',
              if (appt.scheduledTime != null) DateFormat('MMM d, h:mm a').format(appt.scheduledTime!.toLocal()),
            ].join(' · ')),
            trailing: Chip(
              label: Text(appt.status.toUpperCase(), style: const TextStyle(fontSize: 11)),
              backgroundColor: _statusColor(appt.status).withValues(alpha: 0.12),
            ),
          ),
        );
      },
    );
  }
}
