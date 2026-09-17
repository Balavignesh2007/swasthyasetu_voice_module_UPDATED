import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/doctor_models.dart';
import '../services/api_service.dart';

class ReferralsScreen extends StatefulWidget {
  const ReferralsScreen({super.key});

  @override
  State<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends State<ReferralsScreen> with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  late TabController _tabController;
  List<DoctorReferral> _referrals = [];
  List<DoctorAppointment> _appointments = [];
  List<DoctorFacility> _facilities = [];
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
      List<DoctorFacility> facilities = [];
      try {
        facilities = await _apiService.fetchFacilities();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _referrals = referrals;
        _appointments = appointments;
        _facilities = facilities;
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

  void _openPatientConsultationDialog(DoctorAppointment appointment) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PatientConsultationDialog(
        appointment: appointment,
        facilities: _facilities,
        apiService: _apiService,
        onSuccess: () {
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_month, size: 18),
                  const SizedBox(width: 6),
                  Text('Appointments (${_appointments.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.swap_horiz, size: 18),
                  const SizedBox(width: 6),
                  Text('Referrals (${_referrals.length})'),
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: _loading && _referrals.isEmpty && _appointments.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _referrals.isEmpty && _appointments.isEmpty
                  ? Center(
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
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [_buildAppointmentsList(), _buildReferralsList()],
                    ),
        ),
      ],
    );
  }

  Widget _buildAppointmentsList() {
    if (_appointments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No appointments yet. ASHA voice notes will appear here automatically.')),
            )
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        itemCount: _appointments.length,
        itemBuilder: (context, index) {
          final a = _appointments[index];
          final isEmergency = a.isEmergency;
          final isCompleted = a.status.toLowerCase() == 'completed';
          final isReferred = a.status.toLowerCase() == 'referred';

          return Card(
            elevation: isEmergency ? 4 : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isEmergency ? const BorderSide(color: Colors.red, width: 2) : BorderSide.none,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openPatientConsultationDialog(a),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top header row: Patient Name & Status Chips
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.patientName ?? 'Patient ID: ${a.patientId.substring(0, 8)}...',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${a.patientVillage ?? "Community Village"} • Queue #${a.queueNumber ?? "—"}',
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (isEmergency)
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '🚨 RED FLAG',
                                  style: TextStyle(
                                    color: Colors.red.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? Colors.green.shade100
                                    : (isReferred ? Colors.purple.shade100 : Colors.amber.shade100),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isCompleted
                                    ? 'Prescribed'
                                    : (isReferred ? 'Referred' : 'Pending Review'),
                                style: TextStyle(
                                  color: isCompleted
                                      ? Colors.green.shade900
                                      : (isReferred ? Colors.purple.shade900 : Colors.brown.shade900),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Voice symptoms snippet if available
                    if (a.rawTranscript != null && a.rawTranscript!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.record_voice_over, size: 16, color: Colors.blueGrey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '"${a.rawTranscript!}"',
                                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Extracted symptom tags
                    if (a.extractedSymptoms.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: a.extractedSymptoms.take(4).map((s) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(s, style: const TextStyle(fontSize: 11, color: Color(0xFF0D47A1))),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${a.speciality ?? "General Medicine"} · ${DateFormat('MMM d, h:mm a').format(a.createdAt.toLocal())}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => _openPatientConsultationDialog(a),
                          icon: const Icon(Icons.edit_note, size: 16),
                          label: Text(isCompleted ? 'View / Edit' : 'Consult & Prescribe'),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReferralsList() {
    if (_referrals.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No referrals yet.')))],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        itemCount: _referrals.length,
        itemBuilder: (context, index) {
          final r = _referrals[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8EAF6),
                child: Icon(Icons.swap_horiz, color: Color(0xFF3F51B5)),
              ),
              title: Text('Referral for Patient: ${r.patientId.substring(0, 8)}...'),
              subtitle: Text(
                'To Facility: ${r.toFacilityId ?? "District Hospital"}\n${DateFormat('MMM d, h:mm a').format(r.createdAt.toLocal())}',
              ),
              isThreeLine: true,
              trailing: Chip(
                label: Text(r.status, style: const TextStyle(fontSize: 11)),
                backgroundColor: Colors.indigo.shade50,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PatientConsultationDialog extends StatefulWidget {
  final DoctorAppointment appointment;
  final List<DoctorFacility> facilities;
  final ApiService apiService;
  final VoidCallback onSuccess;

  const _PatientConsultationDialog({
    required this.appointment,
    required this.facilities,
    required this.apiService,
    required this.onSuccess,
  });

  @override
  State<_PatientConsultationDialog> createState() => _PatientConsultationDialogState();
}

class _PatientConsultationDialogState extends State<_PatientConsultationDialog>
    with SingleTickerProviderStateMixin {
  late TabController _consultationTabController;
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _prescriptionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Referral state
  String? _selectedFacilityId;
  String _selectedSpeciality = 'Cardiology';
  final TextEditingController _referralReasonController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  final List<String> _specialitiesList = [
    'Cardiology',
    'Pulmonology',
    'General Medicine',
    'Orthopedics',
    'Pediatrics',
    'Neurology',
    'Gastroenterology',
    'Obstetrics & Gynecology',
  ];

  @override
  void initState() {
    super.initState();
    _consultationTabController = TabController(length: 2, vsync: this);
    _diagnosisController.text = widget.appointment.diagnosis ?? '';
    _prescriptionController.text = widget.appointment.prescription ?? '';
    _notesController.text = widget.appointment.notes ?? '';

    if (widget.facilities.isNotEmpty) {
      _selectedFacilityId = widget.facilities.first.id;
    }
  }

  @override
  void dispose() {
    _consultationTabController.dispose();
    _diagnosisController.dispose();
    _prescriptionController.dispose();
    _notesController.dispose();
    _referralReasonController.dispose();
    super.dispose();
  }

  Future<void> _submitPrescription() async {
    final rx = _prescriptionController.text.trim();
    if (rx.isEmpty) {
      setState(() => _errorMessage = 'Please enter prescription medicines and dosage.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.apiService.addPrescription(
        appointmentId: widget.appointment.id,
        prescription: rx,
        diagnosis: _diagnosisController.text.trim().isNotEmpty ? _diagnosisController.text.trim() : null,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        status: 'completed',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prescription successfully recorded for ${widget.appointment.patientName ?? "patient"}!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to save prescription: $e';
        });
      }
    }
  }

  Future<void> _submitReferral() async {
    if (_selectedFacilityId == null) {
      setState(() => _errorMessage = 'Please select a destination healthcare facility.');
      return;
    }
    final reason = _referralReasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _errorMessage = 'Please provide a clinical justification / reason for referral.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.apiService.createReferral(
        patientId: widget.appointment.patientId,
        toFacilityId: _selectedFacilityId!,
        reason: '[$_selectedSpeciality] $reason',
        fromFacilityId: widget.appointment.facilityId,
      );

      // Update appointment status to referred
      await widget.apiService.addPrescription(
        appointmentId: widget.appointment.id,
        prescription: _prescriptionController.text.trim().isNotEmpty
            ? _prescriptionController.text.trim()
            : 'Referred to specialist facility',
        diagnosis: _diagnosisController.text.trim().isNotEmpty
            ? _diagnosisController.text.trim()
            : 'Referred for specialist evaluation',
        notes: 'Referral reason: $reason',
        status: 'referred',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient successfully referred to specialist facility!'),
            backgroundColor: Colors.purple,
          ),
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to issue referral: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final isEmergency = a.isEmergency;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 750),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isEmergency ? const Color(0xFFB71C1C) : const Color(0xFF1976D2),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(
                      isEmergency ? Icons.warning_amber_rounded : Icons.medical_services_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.patientName ?? 'Patient Consultation',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          'Village: ${a.patientVillage ?? "Unknown"} • Health ID: ${a.healthId ?? "—"} • Queue #${a.queueNumber ?? "—"}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Emergency Alert Banner inside dialog
            if (isEmergency)
              Container(
                color: Colors.red.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.emergency, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'CRITICAL RED FLAG DETECTED: ${a.redFlagType ?? "Immediate medical attention required"}',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Patient Voice Intake & Symptoms summary
            Container(
              color: Colors.grey.shade50,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.record_voice_over, size: 16, color: Color(0xFF1976D2)),
                      const SizedBox(width: 6),
                      const Text(
                        'Patient Spoken Symptoms (Voice Note):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        'Specialty: ${a.speciality ?? "General Medicine"}',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    a.rawTranscript != null && a.rawTranscript!.isNotEmpty
                        ? a.rawTranscript!
                        : (a.notes ?? 'No audio transcript recorded.'),
                    style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                  if (a.translatedText != null && a.translatedText != a.rawTranscript) ...[
                    const SizedBox(height: 4),
                    Text(
                      'English Pivot: ${a.translatedText!}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                    ),
                  ],
                  if (a.extractedSymptoms.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: a.extractedSymptoms.map((s) {
                        return Chip(
                          label: Text(s, style: const TextStyle(fontSize: 11)),
                          backgroundColor: Colors.blue.shade50,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),

            // Tab bar for Prescription vs Referral
            TabBar(
              controller: _consultationTabController,
              labelColor: const Color(0xFF1976D2),
              unselectedLabelColor: Colors.black54,
              indicatorColor: const Color(0xFF1976D2),
              tabs: const [
                Tab(icon: Icon(Icons.edit_note), text: 'Add Prescription / Prediction'),
                Tab(icon: Icon(Icons.swap_horiz), text: 'Refer to Another Doctor / Hospital'),
              ],
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _consultationTabController,
                children: [
                  // Tab 1: Prescription Writer
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _diagnosisController,
                          decoration: InputDecoration(
                            labelText: 'Clinical Diagnosis / Prediction (निदान)',
                            hintText: 'e.g. Acute Coronary Syndrome, Bronchial Asthma, Viral Pyrexia',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _prescriptionController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Prescription & Dosage (दवा और खुराक) *',
                            hintText: 'e.g.\n1. Tab Sorbitrate 5mg SL SOS\n2. Tab Aspirin 75mg OD for 30 days\n3. Tab Pantocid 40mg OD AC',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Advice / Follow-up Instructions (सलाह)',
                            hintText: 'e.g. Bed rest, avoid exertion, revisit if chest discomfort recurs.',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                          ),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _submitPrescription,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(_isSaving ? 'Saving...' : 'Save Prescription & Complete Consultation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab 2: Referral to Specialist / Hospital
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Refer Patient to Specialty Care or Higher Center',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedFacilityId,
                          decoration: InputDecoration(
                            labelText: 'Destination Facility (अस्पताल / केंद्र)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: widget.facilities.map((f) {
                            return DropdownMenuItem(
                              value: f.id,
                              child: Text('${f.name} (${f.level})'),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedFacilityId = val),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedSpeciality,
                          decoration: InputDecoration(
                            labelText: 'Speciality / Department (विभाग)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: _specialitiesList.map((s) {
                            return DropdownMenuItem(value: s, child: Text(s));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedSpeciality = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _referralReasonController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Reason for Referral (रेफरल का कारण) *',
                            hintText: 'e.g. Needs immediate cardiology evaluation, 2D ECHO, and coronary angiography.',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                          ),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _submitReferral,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.swap_horiz),
                          label: Text(_isSaving ? 'Processing Referral...' : 'Issue Medical Referral'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A1B9A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
