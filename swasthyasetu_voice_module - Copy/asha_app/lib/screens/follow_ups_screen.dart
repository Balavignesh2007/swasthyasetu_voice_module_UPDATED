import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/follow_up.dart';
import '../models/patient.dart';
import '../services/api_service.dart';
import '../services/offline_sync_service.dart';
import '../services/session_service.dart';

class FollowUpsScreen extends StatefulWidget {
  const FollowUpsScreen({super.key});

  @override
  State<FollowUpsScreen> createState() => _FollowUpsScreenState();
}

class _FollowUpsScreenState extends State<FollowUpsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  List<PatientFollowUp> _allFollowUps = [];
  List<AshaPatient> _patients = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final asha = await SessionService.getProfile();
    if (asha == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final followUps = await _api.fetchFollowUps(ashaId: asha.id);
      final patients = await _api.fetchAssignedPatients(asha.id);

      if (mounted) {
        setState(() {
          _allFollowUps = followUps;
          _patients = patients;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load follow-up tasks: $e';
        });
      }
    }
  }

  String _getPatientName(String patientId) {
    final match = _patients.where((p) => p.id == patientId);
    if (match.isNotEmpty) {
      return match.first.name ?? 'Patient ($patientId)';
    }
    return 'Patient ID: ${patientId.length > 8 ? patientId.substring(0, 8) : patientId}';
  }

  Future<void> _completeFollowUp(PatientFollowUp item) async {
    final notesController = TextEditingController(text: item.notes ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Complete: ${item.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient: ${_getPatientName(item.patientId)}'),
            const SizedBox(height: 12),
            const Text('Visit Observations / Notes:'),
            const SizedBox(height: 6),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Vitals normal, medication given, advised rest...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Mark Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final updates = {
      'status': 'completed',
      'notes': notesController.text.trim(),
      'completed_at': DateTime.now().toIso8601String(),
    };

    try {
      await _api.updateFollowUp(item.id, updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Follow-up marked completed!'), backgroundColor: Colors.green),
        );
        _fetchData();
      }
    } catch (e) {
      // Queue offline
      await OfflineSyncService.instance.queueFollowUpUpdate(item.id, updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved offline. Will sync status when connected.'),
            backgroundColor: Colors.orange,
          ),
        );
        _fetchData();
      }
    }
  }

  Future<void> _showCreateDialog() async {
    final asha = await SessionService.getProfile();
    if (asha == null) return;
    if (!mounted) return;

    String? selectedPatientId = _patients.isNotEmpty ? _patients.first.id : null;
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    String priority = 'NORMAL';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Schedule Follow-up Visit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Patient:'),
                DropdownButtonFormField<String>(
                  initialValue: selectedPatientId,
                  isExpanded: true,
                  items: _patients.map((p) {
                    return DropdownMenuItem(
                      value: p.id,
                      child: Text('${p.name ?? "Unknown"} • ${p.village ?? ""}'),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedPatientId = val),
                ),
                const SizedBox(height: 12),
                const Text('Visit Purpose / Title:'),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Blood pressure monitoring, Neonatal check...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Priority: '),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: priority,
                      items: const [
                        DropdownMenuItem(value: 'NORMAL', child: Text('NORMAL')),
                        DropdownMenuItem(value: 'HIGH', child: Text('HIGH')),
                        DropdownMenuItem(value: 'URGENT', child: Text('URGENT')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => priority = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Additional Notes:'),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Special instructions from doctor or clinic...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty || selectedPatientId == null) {
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await _api.createFollowUp({
                    'patient_id': selectedPatientId,
                    'asha_id': asha.id,
                    'title': titleController.text.trim(),
                    'due_date': selectedDate.toIso8601String(),
                    'priority': priority,
                    'notes': notesController.text.trim(),
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Follow-up task created!'), backgroundColor: Colors.green),
                    );
                    _fetchData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Follow-ups'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amberAccent,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Due Today'),
            Tab(text: 'Overdue'),
            Tab(text: 'Pending (All)'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task),
        label: const Text('New Follow-up'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _fetchData, child: const Text('Retry')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTaskList(_filterToday()),
                    _buildTaskList(_filterOverdue()),
                    _buildTaskList(_filterPending()),
                    _buildTaskList(_filterCompleted()),
                  ],
                ),
    );
  }

  List<PatientFollowUp> _filterToday() {
    final now = DateTime.now();
    return _allFollowUps.where((item) {
      if (item.status == 'completed') return false;
      final due = item.dueDate.toLocal();
      return due.year == now.year && due.month == now.month && due.day == now.day;
    }).toList();
  }

  List<PatientFollowUp> _filterOverdue() {
    final startOfToday = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _allFollowUps.where((item) {
      if (item.status == 'completed') return false;
      return item.dueDate.toLocal().isBefore(startOfToday) || item.status == 'overdue';
    }).toList();
  }

  List<PatientFollowUp> _filterPending() {
    return _allFollowUps.where((item) => item.status != 'completed').toList();
  }

  List<PatientFollowUp> _filterCompleted() {
    return _allFollowUps.where((item) => item.status == 'completed').toList();
  }

  Widget _buildTaskList(List<PatientFollowUp> list) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchData,
        child: ListView(
          children: const [
            SizedBox(height: 100),
            Center(
              child: Column(
                children: [
                  Icon(Icons.assignment_turned_in_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No tasks in this category.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = list[index];
          final isCompleted = item.status == 'completed';
          final isHighPriority = item.priority == 'HIGH' || item.priority == 'URGENT';
          final dueFormatted = DateFormat('dd MMM yyyy').format(item.dueDate.toLocal());

          return Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isHighPriority && !isCompleted ? Colors.orange.shade400 : Colors.grey.shade300,
                width: isHighPriority && !isCompleted ? 1.5 : 0.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: isCompleted
                            ? Colors.green.shade100
                            : isHighPriority
                                ? Colors.orange.shade100
                                : Colors.blue.shade100,
                        child: Icon(
                          isCompleted
                              ? Icons.check
                              : isHighPriority
                                  ? Icons.priority_high
                                  : Icons.calendar_today,
                          color: isCompleted
                              ? Colors.green.shade800
                              : isHighPriority
                                  ? Colors.orange.shade900
                                  : Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                decoration: isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Patient: ${_getPatientName(item.patientId)}',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(
                          item.priority,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isHighPriority ? Colors.red.shade900 : Colors.blue.shade900,
                          ),
                        ),
                        backgroundColor: isHighPriority ? Colors.red.shade50 : Colors.blue.shade50,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (item.notes != null && item.notes!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.notes!,
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Due: $dueFormatted',
                        style: TextStyle(
                          fontSize: 12,
                          color: item.status == 'overdue' ? Colors.red : Colors.grey.shade700,
                          fontWeight: item.status == 'overdue' ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (!isCompleted)
                        ElevatedButton.icon(
                          onPressed: () => _completeFollowUp(item),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Mark Visited'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade600,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
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
