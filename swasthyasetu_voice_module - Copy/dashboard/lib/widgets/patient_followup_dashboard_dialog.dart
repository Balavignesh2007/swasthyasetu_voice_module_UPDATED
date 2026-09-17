import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/unified_models.dart';
import '../services/unified_api_service.dart';

class PatientFollowUpDashboardDialog extends StatefulWidget {
  final UnifiedApiService api;
  final UnifiedUserSession session;
  final AshaPatient patient;

  const PatientFollowUpDashboardDialog({
    super.key,
    required this.api,
    required this.session,
    required this.patient,
  });

  static Future<void> show(
    BuildContext context, {
    required UnifiedApiService api,
    required UnifiedUserSession session,
    required AshaPatient patient,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PatientFollowUpDashboardDialog(
        api: api,
        session: session,
        patient: patient,
      ),
    );
  }

  @override
  State<PatientFollowUpDashboardDialog> createState() => _PatientFollowUpDashboardDialogState();
}

class _PatientFollowUpDashboardDialogState extends State<PatientFollowUpDashboardDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _error;
  PatientFollowUpDashboard? _dashboard;
  final Set<int> _checkedActionIndices = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDashboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.fetchPatientFollowUpDashboard(widget.patient.id);
      if (mounted) {
        setState(() {
          _dashboard = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load follow-up dashboard: $e';
          _loading = false;
        });
      }
    }
  }

  void _showRecordVisitDialog() {
    final bpCtrl = TextEditingController(text: '124/82');
    final pulseCtrl = TextEditingController(text: '74');
    final sugarCtrl = TextEditingController(text: '110');
    final tempCtrl = TextEditingController(text: '98.4');
    final notesCtrl = TextEditingController();
    String adherence = 'Adherent';
    int nextDueDays = 7;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.health_and_safety, color: Color(0xFF0F766E)),
              ),
              const SizedBox(width: 12),
              const Text(
                'Record Home Visit & Vitals',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patient: ${widget.patient.name} (${widget.patient.healthId})',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  const Text('Vital Signs Measured', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: bpCtrl,
                          decoration: const InputDecoration(
                            labelText: 'BP (mmHg)',
                            hintText: '120/80',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: pulseCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Pulse (bpm)',
                            hintText: '72',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: sugarCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Blood Sugar (mg/dL)',
                            hintText: '105',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: tempCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Temp (°F)',
                            hintText: '98.6',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Medication Adherence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: adherence,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'Adherent', child: Text('Regular (Taking as prescribed)')),
                      DropdownMenuItem(value: 'Partial', child: Text('Partial (Missed a few doses)')),
                      DropdownMenuItem(value: 'Non-Adherent', child: Text('Non-Adherent (Not taking medication)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => adherence = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Next Follow-up Interval', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: nextDueDays,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    items: const [
                      DropdownMenuItem(value: 3, child: Text('After 3 days (High Surveillance)')),
                      DropdownMenuItem(value: 7, child: Text('After 7 days (Weekly Check-in)')),
                      DropdownMenuItem(value: 14, child: Text('After 14 days (Bi-weekly Review)')),
                      DropdownMenuItem(value: 30, child: Text('After 30 days (Monthly Routine)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => nextDueDays = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ASHA Observation Notes',
                      hintText: 'e.g., Patient feeling better, no chest pain. Diet advice given.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      try {
                        await widget.api.recordPatientFollowUpVisit(
                          patientId: widget.patient.id,
                          notes: notesCtrl.text.trim().isNotEmpty
                              ? notesCtrl.text.trim()
                              : 'Home visit completed. Vitals stable.',
                          vitals: {
                            'blood_pressure': bpCtrl.text.trim(),
                            'pulse': pulseCtrl.text.trim(),
                            'blood_sugar': sugarCtrl.text.trim(),
                            'temperature': tempCtrl.text.trim(),
                          },
                          medicationAdherence: adherence,
                          nextDueDays: nextDueDays,
                        );
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Follow-up visit and vitals logged successfully!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          _loadDashboard();
                        }
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error saving visit: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save & Complete Visit'),
            ),
          ],
        ),
      ),
    );
  }

  void _escalateEmergency() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Confirm Emergency Escalation'),
          ],
        ),
        content: Text(
          'Are you sure you want to escalate an emergency alert for ${widget.patient.name} to Dr. Rajesh Sharma and PHC Rampur?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.api.escalatePatientEmergency(
                  patientId: widget.patient.id,
                  redFlagType: 'ASHA Field Emergency Alert',
                  symptoms: _dashboard?.lastVisit.diagnosis ?? 'Severe acute symptoms during home visit',
                  severity: 'HIGH',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🚨 Emergency alert dispatched to Doctor & PHC triage!'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Escalation error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Escalate Immediately'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 24, vertical: isMobile ? 12 : 24),
      child: Container(
        width: isMobile ? double.infinity : 820,
        height: isMobile ? MediaQuery.of(context).size.height * 0.92 : 650,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // 1. Header with Patient Banner
            _buildHeader(),

            // 2. Tab Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: const Color(0xFF0F766E),
                unselectedLabelColor: Colors.blueGrey.shade600,
                indicatorColor: const Color(0xFF0F766E),
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.history_edu, size: 20), text: 'Last Visit & Clinical Rx'),
                  Tab(icon: Icon(Icons.alt_route, size: 20), text: 'Referral Details ("Referral To")'),
                  Tab(icon: Icon(Icons.next_plan_outlined, size: 20), text: 'What Next Going to Happen'),
                ],
              ),
            ),

            // 3. Tab Body
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _loadDashboard, child: const Text('Try Again')),
                            ],
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildLastVisitTab(_dashboard!.lastVisit),
                            _buildReferralTab(_dashboard!.referral),
                            _buildWhatNextTab(_dashboard!.whatNext),
                          ],
                        ),
            ),

            // 4. Action Footer Bar
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF0F766E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white,
            child: Text(
              widget.patient.name.isNotEmpty ? widget.patient.name[0].toUpperCase() : 'P',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F766E)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      widget.patient.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Dynamic Follow-up',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'ABHA: ${widget.patient.healthId}  •  Village: ${widget.patient.village ?? "Rampur"}  •  Lang: ${widget.patient.preferredLanguage ?? "hi"}',
                  style: TextStyle(fontSize: 11, color: Colors.teal.shade50),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildLastVisitTab(FollowUpLastVisit v) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Doctor & Facility Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.teal.shade300),
                  ),
                  child: const Icon(Icons.medical_information, color: Color(0xFF0F766E), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.doctorName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${v.speciality}  •  ${v.facilityName}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              v.status.toUpperCase(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                            ),
                          ),
                          Text(
                            v.visitDate,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Clinical Diagnosis Card
          const Text('Clinical Diagnosis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.medical_services, color: Colors.blue, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    v.diagnosis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Symptoms Reported
          if (v.symptoms.isNotEmpty) ...[
            const Text('Symptoms & Complaints', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: v.symptoms.map((s) {
                return Chip(
                  avatar: const Icon(Icons.fiber_manual_record, size: 12, color: Colors.amber),
                  label: Text(s, style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.amber.shade50,
                  side: BorderSide(color: Colors.amber.shade300),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
          ],

          // Prescribed Medicines (Rx)
          const Text('Prescribed Medication & Doctor Advice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.medication, color: Color(0xFF0F766E), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        v.prescription,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
                      ),
                    ),
                  ],
                ),
                if (v.clinicalNotes.isNotEmpty) ...[
                  const Divider(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notes, color: Colors.grey, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Doctor Notes: ${v.clinicalNotes}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralTab(FollowUpReferral r) {
    final bool isEmergency = r.urgency.toUpperCase() == 'EMERGENCY';
    final bool isUrgent = r.urgency.toUpperCase() == 'URGENT';
    final Color urgencyColor = isEmergency ? Colors.red : (isUrgent ? Colors.orange.shade800 : const Color(0xFF0F766E));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Referral Pathway Flow Diagram
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isEmergency ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isEmergency ? Colors.red.shade200 : Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Facility Referral Route', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: urgencyColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: urgencyColor),
                      ),
                      child: Text(
                        '${r.urgency.toUpperCase()} REFERRAL',
                        style: TextStyle(color: urgencyColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Builder(
                  builder: (context) {
                    final isMobile = MediaQuery.of(context).size.width < 768;
                    final fromBox = Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('FROM (Origin)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(r.fromFacility, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    );

                    final toBox = Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: urgencyColor.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('REFERRAL TO (Target)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(r.toFacility, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: urgencyColor)),
                        ],
                      ),
                    );

                    if (isMobile) {
                      return Column(
                        children: [
                          fromBox,
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Icon(Icons.arrow_downward_rounded, color: Color(0xFF0F766E), size: 22),
                          ),
                          toBox,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: fromBox),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward_rounded, color: Color(0xFF0F766E), size: 24),
                        ),
                        Expanded(child: toBox),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Clinical Rationale for Referral
          const Text('Clinical Rationale & Speciality Justification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.reason,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emergency_share, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 4),
                        Text('Status: ${r.status.toUpperCase()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.airport_shuttle, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 4),
                        Text('Transit: ${r.transportMode}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Referral Advice for ASHA
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb, color: Colors.amber.shade900, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    r.hasReferral
                        ? 'ASHA Directive: Facilitate patient transit and ensure family brings previous prescription and ABHA card to ${r.toFacility}.'
                        : 'No specialist referral needed at this time. Patient condition is manageable with routine community checkups.',
                    style: TextStyle(fontSize: 13, color: Colors.amber.shade900, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatNextTab(FollowUpWhatNext w) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Due Date & Target Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.green.shade400),
                      ),
                      child: const Icon(Icons.event_note, color: Colors.green, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w.title,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Care Pathway: ${w.carePathway}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade400),
                  ),
                  child: Text(
                    w.dueLabel,
                    style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Interactive ASHA Action Checklist
          const Row(
            children: [
              Text('ASHA Worker Action Checklist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              SizedBox(width: 8),
              Text('(Tick items as completed during home visit)', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(w.actions.length, (idx) {
            final action = w.actions[idx];
            final isDone = _checkedActionIndices.contains(idx);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isDone ? Colors.teal.shade50 : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: isDone ? Colors.teal.shade300 : Colors.grey.shade300),
              ),
              child: CheckboxListTile(
                dense: true,
                value: isDone,
                activeColor: const Color(0xFF0F766E),
                title: Text(
                  action,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone ? const Color(0xFF0F766E) : Colors.black87,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _checkedActionIndices.add(idx);
                    } else {
                      _checkedActionIndices.remove(idx);
                    }
                  });
                },
              ),
            );
          }),
          const SizedBox(height: 14),

          // Danger Signs Warning Container
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Danger Signs to Screen for (Immediate Escalation Required)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...w.dangerSigns.map((d) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(d, style: TextStyle(fontSize: 12, color: Colors.red.shade900)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final pPhone = widget.patient.phone ?? '+919000000001';

    final callBtn = OutlinedButton.icon(
      onPressed: () {
        Clipboard.setData(ClipboardData(text: pPhone));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📞 Patient Phone copied: $pPhone'),
            backgroundColor: const Color(0xFF0F766E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      icon: const Icon(Icons.phone, size: 16),
      label: Text('CALL ($pPhone)'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF0F766E),
        side: const BorderSide(color: Color(0xFF0F766E)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );

    final escalateBtn = OutlinedButton.icon(
      onPressed: _escalateEmergency,
      icon: const Icon(Icons.emergency, color: Colors.red, size: 16),
      label: const Text('ESCALATE RED FLAG', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.red),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );

    final logVisitBtn = ElevatedButton.icon(
      onPressed: _showRecordVisitDialog,
      icon: const Icon(Icons.check_circle_outline, size: 18),
      label: const Text('LOG HOME VISIT & VITALS', style: TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: isMobile
          ? Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                callBtn,
                escalateBtn,
                SizedBox(width: double.infinity, child: logVisitBtn),
              ],
            )
          : Row(
              children: [
                callBtn,
                const SizedBox(width: 10),
                escalateBtn,
                const Spacer(),
                logVisitBtn,
              ],
            ),
    );
  }
}
