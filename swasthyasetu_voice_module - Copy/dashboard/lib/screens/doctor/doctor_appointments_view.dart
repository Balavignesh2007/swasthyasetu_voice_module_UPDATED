import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/unified_models.dart';
import '../../services/unified_api_service.dart';
import '../../widgets/jitsi_consultation_dialog.dart';

class DoctorAppointmentsView extends StatefulWidget {
  final UnifiedApiService api;
  final UnifiedUserSession session;

  const DoctorAppointmentsView({
    super.key,
    required this.api,
    required this.session,
  });

  @override
  State<DoctorAppointmentsView> createState() => _DoctorAppointmentsViewState();
}

class _DoctorAppointmentsViewState extends State<DoctorAppointmentsView> {
  bool _loading = true;
  String? _error;
  List<DoctorAppointment> _appointments = [];
  List<DoctorFacility> _facilities = [];
  String _filter = 'ALL';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) _loadDataSilently();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDataSilently() async {
    try {
      final list = await widget.api.fetchDoctorAppointments();
      if (mounted) {
        setState(() {
          _appointments = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.fetchDoctorAppointments(),
        widget.api.fetchFacilities().catchError((_) => <DoctorFacility>[]),
      ]);
      if (mounted) {
        setState(() {
          _appointments = results[0] as List<DoctorAppointment>;
          _facilities = results[1] as List<DoctorFacility>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load appointments: $e';
          _loading = false;
        });
      }
    }
  }

  List<DoctorAppointment> get _filteredAppointments {
    if (_filter == 'ALL') return _appointments;
    if (_filter == 'PRESCRIBED') {
      return _appointments.where((a) => a.prescription != null && a.prescription!.isNotEmpty).toList();
    }
    if (_filter == 'PENDING') {
      return _appointments.where((a) => a.prescription == null || a.prescription!.isEmpty).toList();
    }
    if (_filter == 'EMERGENCY') {
      return _appointments.where((a) => a.isEmergency).toList();
    }
    return _appointments;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isMobile),
              const SizedBox(height: 12),
              _buildFilterChips(),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _buildErrorWidget()
                        : _filteredAppointments.isEmpty
                            ? _buildEmptyWidget()
                            : _buildAppointmentsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMobile ? 'Doctor OPD & Triage' : 'Doctor OPD & Triage Appointments',
                style: TextStyle(
                  fontSize: isMobile ? 18 : 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Review voice notes, symptoms & write prescriptions',
                style: TextStyle(fontSize: isMobile ? 11 : 13, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (isMobile)
          IconButton.filledTonal(
            onPressed: _loadData,
            tooltip: 'Refresh Queue',
            icon: const Icon(Icons.refresh, size: 20),
          )
        else
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh Queue'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'ALL', 'label': 'All (${_appointments.length})'},
      {'key': 'PENDING', 'label': 'Needs Review (${_appointments.where((a) => a.prescription == null || a.prescription!.isEmpty).length})'},
      {'key': 'PRESCRIBED', 'label': 'Prescribed (${_appointments.where((a) => a.prescription != null && a.prescription!.isNotEmpty).length})'},
      {'key': 'EMERGENCY', 'label': 'Red Flags (${_appointments.where((a) => a.isEmergency).length})'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _filter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(f['label']!),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _filter = f['key']!);
              },
              selectedColor: const Color(0xFF0F766E),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAppointmentsList() {
    return ListView.separated(
      itemCount: _filteredAppointments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final appt = _filteredAppointments[index];
        return _buildAppointmentCard(appt);
      },
    );
  }

  Widget _buildAppointmentCard(DoctorAppointment appt) {
    final hasPrescription = appt.prescription != null && appt.prescription!.isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: appt.isEmergency ? Colors.red.shade300 : Colors.grey.shade200,
          width: appt.isEmergency ? 1.5 : 1,
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (appt.isEmergency)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🚨 HIGH RISK PATIENT ESCALATION: ${appt.patientName ?? 'PATIENT'} - URGENT CLINICAL ATTENTION (${appt.redFlagType ?? 'CRITICAL'})',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            // Top row: Queue Number, Specialty, Status badge
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Text(
                    'Queue #${appt.queueNumber ?? 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7), fontSize: 12),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    appt.speciality ?? 'General Medicine',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155), fontSize: 12),
                  ),
                ),
                if (appt.isEmergency)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          appt.redFlagType ?? 'EMERGENCY',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasPrescription ? Colors.green.shade50 : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: hasPrescription ? Colors.green.shade400 : Colors.amber.shade400,
                    ),
                  ),
                  child: Text(
                    hasPrescription ? 'Prescription Written' : 'Awaiting Review',
                    style: TextStyle(
                      color: hasPrescription ? Colors.green.shade800 : Colors.amber.shade900,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Patient Info Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFCCFBF1),
                  child: Text(
                    (appt.patientName != null && appt.patientName!.isNotEmpty)
                        ? appt.patientName![0].toUpperCase()
                        : 'P',
                    style: const TextStyle(
                      color: Color(0xFF0F766E),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appt.patientName ?? 'Patient (ID: ${appt.patientId.substring(0, 8)})',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (appt.healthId != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.badge_outlined, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text('ABHA: ${appt.healthId}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                              ],
                            ),
                          if (appt.patientPhone != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone_outlined, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(appt.patientPhone!, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                              ],
                            ),
                          if (appt.patientVillage != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(appt.patientVillage!, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Voice Recording Symptoms Box
            if (appt.rawTranscript != null && appt.rawTranscript!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.mic, size: 16, color: Color(0xFF0F766E)),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Recorded Voice Note & Symptoms:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF0F766E),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (appt.voiceNoteId != null)
                          Text(
                            '#${appt.voiceNoteId!.substring(0, appt.voiceNoteId!.length > 8 ? 8 : appt.voiceNoteId!.length)}',
                            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '"${appt.rawTranscript}"',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 13.5,
                        color: Color(0xFF334155),
                      ),
                    ),
                    if (appt.translatedText != null && appt.translatedText!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Translation: "${appt.translatedText}"',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                    if (appt.extractedSymptoms.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: appt.extractedSymptoms.map((symptom) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              symptom,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF1E293B)),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),

            // If Prescription exists, show Rx block
            if (hasPrescription) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.medical_services_outlined, size: 16, color: Colors.green.shade800),
                        const SizedBox(width: 6),
                        Text(
                          'Doctor Prescription & Diagnosis (Rx)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (appt.diagnosis != null && appt.diagnosis!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          'Diagnosis: ${appt.diagnosis}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    Text(
                      'Prescription: ${appt.prescription}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF166534)),
                    ),
                    if (appt.notes != null && appt.notes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Doctor Notes: ${appt.notes}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    JitsiConsultationDialog.show(
                      context: context,
                      appointment: appt,
                      api: widget.api,
                      doctorName: widget.session.name,
                      onPrescriptionSaved: _loadData,
                    );
                  },
                  icon: const Icon(Icons.videocam_rounded, size: 15),
                  label: const Text('Video Consult', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF93C5FD)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showReferralDialog(appt),
                  icon: const Icon(Icons.arrow_forward, size: 15),
                  label: const Text('Refer Patient', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    foregroundColor: const Color(0xFF4338CA),
                    side: const BorderSide(color: Color(0xFFC7D2FE)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showPrescriptionDialog(appt),
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: Text(
                    hasPrescription ? 'Update Rx' : 'Add Prescription',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPrescriptionDialog(DoctorAppointment appt) {
    final diagnosisCtrl = TextEditingController(text: appt.diagnosis ?? '');
    final rxCtrl = TextEditingController(text: appt.prescription ?? '');
    final notesCtrl = TextEditingController(text: appt.notes ?? '');
    bool submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Prescription for ${appt.patientName ?? "Patient"}'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (appt.extractedSymptoms.isNotEmpty) ...[
                        Text(
                          'Reported Symptoms: ${appt.extractedSymptoms.join(", ")}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: diagnosisCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Diagnosis / Clinical Impression',
                          hintText: 'e.g., Acute Bronchitis, Angina, Viral URI',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: rxCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Prescription / Medication (Rx) *',
                          hintText: 'e.g., 1. Tab Paracetamol 500mg TDS x 3 days\n2. Syp Ambroxol 5ml BD x 5 days',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Doctor Advice & Instructions',
                          hintText: 'Drink plenty of warm fluids, return if fever persists > 48h',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          if (rxCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter prescription details')),
                            );
                            return;
                          }
                          setDialogState(() => submitting = true);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await widget.api.addPrescription(
                              appointmentId: appt.id,
                              prescription: rxCtrl.text.trim(),
                              diagnosis: diagnosisCtrl.text.trim().isNotEmpty ? diagnosisCtrl.text.trim() : null,
                              notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                            );
                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Prescription saved and sent to patient record!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadData();
                          } catch (e) {
                            setDialogState(() => submitting = false);
                            messenger.showSnackBar(
                              SnackBar(content: Text('Failed to save prescription: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                  child: submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Prescription'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReferralDialog(DoctorAppointment appt) {
    String? selectedFacilityId = _facilities.isNotEmpty ? _facilities.first.id : null;
    String selectedUrgency = 'ROUTINE';
    final reasonCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Refer ${appt.patientName ?? "Patient"}'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select receiving facility / hospital for advanced care or specialist evaluation:',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedFacilityId,
                        decoration: const InputDecoration(
                          labelText: 'Receiving Facility / Hospital',
                          border: OutlineInputBorder(),
                        ),
                        items: _facilities.map((f) {
                          return DropdownMenuItem(
                            value: f.id,
                            child: Text('${f.name} (${f.level})'),
                          );
                        }).toList(),
                        onChanged: (val) => setDialogState(() => selectedFacilityId = val),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedUrgency,
                        decoration: const InputDecoration(
                          labelText: 'Urgency Level',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ROUTINE', child: Text('Routine (Standard OPD)')),
                          DropdownMenuItem(value: 'URGENT', child: Text('Urgent (Within 24 Hours)')),
                          DropdownMenuItem(value: 'EMERGENCY', child: Text('Emergency (Immediate Transfer)')),
                        ],
                        onChanged: (val) => setDialogState(() => selectedUrgency = val ?? 'ROUTINE'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Reason for Referral / Clinical Summary',
                          hintText: 'e.g., Needs urgent cardiology evaluation, 2D-ECHO and angiography.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4338CA),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          if (selectedFacilityId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select a facility')),
                            );
                            return;
                          }
                          setDialogState(() => submitting = true);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await widget.api.createReferral(
                              patientId: appt.patientId,
                              toFacilityId: selectedFacilityId!,
                              urgency: selectedUrgency,
                              reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : null,
                            );
                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Patient successfully referred!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadData();
                          } catch (e) {
                            setDialogState(() => submitting = false);
                            messenger.showSnackBar(
                              SnackBar(content: Text('Failed to refer patient: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                  child: submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Confirm Referral'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Try Again')),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_month_outlined, size: 54, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No appointments in queue (${_filter.toLowerCase()})',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'When ASHA workers record patient symptoms via voice, they appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
