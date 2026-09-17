import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/admin_models.dart';
import '../services/api_service.dart';

class ReferralsAppointmentsScreen extends StatefulWidget {
  const ReferralsAppointmentsScreen({super.key});

  @override
  State<ReferralsAppointmentsScreen> createState() => _ReferralsAppointmentsScreenState();
}

class _ReferralsAppointmentsScreenState extends State<ReferralsAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  late TabController _tabController;
  List<AdminReferral> _referrals = [];
  List<AdminAppointment> _appointments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final referrals = await _apiService.fetchReferrals();
      final appointments = await _apiService.fetchAppointments();
      if (!mounted) return;
      setState(() {
        _referrals = referrals;
        _appointments = appointments;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load data: ${e.message}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach the server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              const Text('Referrals & Appointments', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          tabs: const [Tab(text: 'Referrals'), Tab(text: 'Appointments')],
        ),
        Expanded(
          child: _loading && _referrals.isEmpty && _appointments.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _referrals.isEmpty && _appointments.isEmpty
                  ? Center(child: Text(_error!))
                  : TabBarView(
                      controller: _tabController,
                      children: [_buildReferralsTable(), _buildAppointmentsTable()],
                    ),
        ),
      ],
    );
  }

  Widget _buildReferralsTable() {
    if (_referrals.isEmpty) return const Center(child: Text('No referrals yet.'));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Patient')),
              DataColumn(label: Text('Destination Facility')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Created')),
            ],
            rows: _referrals.map((r) {
              return DataRow(cells: [
                DataCell(Text(r.patientId)),
                DataCell(Text(r.toFacilityId ?? '—')),
                DataCell(Chip(label: Text(r.status, style: const TextStyle(fontSize: 11)))),
                DataCell(Text(DateFormat('MMM d, h:mm a').format(r.createdAt.toLocal()))),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentsTable() {
    if (_appointments.isEmpty) return const Center(child: Text('No appointments yet.'));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Patient')),
              DataColumn(label: Text('Speciality')),
              DataColumn(label: Text('Queue #')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Created')),
            ],
            rows: _appointments.map((a) {
              return DataRow(cells: [
                DataCell(Text(a.patientId)),
                DataCell(Text(a.speciality ?? 'General Medicine')),
                DataCell(Text(a.queueNumber?.toString() ?? '—')),
                DataCell(Chip(label: Text(a.status, style: const TextStyle(fontSize: 11)))),
                DataCell(Text(DateFormat('MMM d, h:mm a').format(a.createdAt.toLocal()))),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
