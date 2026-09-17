import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/unified_models.dart';
import '../../services/unified_api_service.dart';
import '../../utils/jitsi_service.dart';
import '../../widgets/jitsi_consultation_dialog.dart';

class DoctorTeleconsultView extends StatefulWidget {
  final UnifiedApiService api;
  final UnifiedUserSession session;

  const DoctorTeleconsultView({
    super.key,
    required this.api,
    required this.session,
  });

  @override
  State<DoctorTeleconsultView> createState() => _DoctorTeleconsultViewState();
}

class _DoctorTeleconsultViewState extends State<DoctorTeleconsultView> {
  bool _loading = true;
  String? _error;
  List<DoctorAppointment> _appointments = [];
  String _filter = 'ALL';
  String _searchQuery = '';
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
      final list = await widget.api.fetchDoctorAppointments();
      if (mounted) {
        setState(() {
          _appointments = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load teleconsultations: $e';
          _loading = false;
        });
      }
    }
  }

  List<DoctorAppointment> get _filteredAppointments {
    return _appointments.where((a) {
      // Status filter
      if (_filter == 'PENDING' && (a.prescription != null && a.prescription!.isNotEmpty)) {
        return false;
      }
      if (_filter == 'COMPLETED' && (a.prescription == null || a.prescription!.isEmpty)) {
        return false;
      }
      if (_filter == 'EMERGENCY' && !a.isEmergency) {
        return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (a.patientName ?? '').toLowerCase();
        final healthId = (a.healthId ?? '').toLowerCase();
        final village = (a.patientVillage ?? '').toLowerCase();
        final symptoms = a.extractedSymptoms.join(' ').toLowerCase();
        return name.contains(q) || healthId.contains(q) || village.contains(q) || symptoms.contains(q);
      }

      return true;
    }).toList();
  }

  int get _pendingCount => _appointments.where((a) => a.prescription == null || a.prescription!.isEmpty).length;
  int get _completedCount => _appointments.where((a) => a.prescription != null && a.prescription!.isNotEmpty).length;
  int get _emergencyCount => _appointments.where((a) => a.isEmergency).length;

  void _openConsultationDialog(DoctorAppointment appt) {
    JitsiConsultationDialog.show(
      context: context,
      appointment: appt,
      api: widget.api,
      doctorName: widget.session.name,
      onPrescriptionSaved: _loadData,
    );
  }

  void _showInstantRoomDialog() {
    final patientNameCtrl = TextEditingController();
    final patientPhoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.add_call, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Start Instant Video Consultation'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Launch an on-demand Jitsi video meeting room for a walk-in or emergency teleconsultation.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: patientNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Patient Name (Optional)',
                    hintText: 'e.g. Ramesh Kumar',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: patientPhoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Patient Phone (for WhatsApp invite)',
                    hintText: 'e.g. 9121458655',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                final pName = patientNameCtrl.text.trim();
                final pPhone = patientPhoneCtrl.text.trim();
                final roomName = JitsiService.generateInstantRoomName(
                  customLabel: pName.isNotEmpty ? pName : null,
                );
                final doctorMeetingUrl = JitsiService.getDoctorMeetingUrl(
                  roomName: roomName,
                  doctorName: widget.session.name,
                );

                // Launch Doctor Call
                await JitsiService.launchMeeting(doctorMeetingUrl);

                // If phone provided, offer WhatsApp invite
                if (pPhone.isNotEmpty && mounted) {
                  final waUrl = JitsiService.getWhatsAppInviteUrl(
                    roomName: roomName,
                    doctorName: widget.session.name,
                    patientPhone: pPhone,
                    patientName: pName.isNotEmpty ? pName : null,
                  );
                  if (waUrl != null) {
                    await JitsiService.launchMeeting(waUrl);
                  }
                }
              },
              icon: const Icon(Icons.video_call_rounded, size: 18),
              label: const Text('Launch Jitsi Room'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 768;
            final kpiWidth = constraints.maxWidth > 700
                ? (constraints.maxWidth - 36) / 4
                : (constraints.maxWidth - 12) / 2;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header & Instant CTA
                  if (isMobile)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Doctor Teleconsultation Hub',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.wifi_tethering_rounded, color: Color(0xFF2563EB), size: 13),
                                  SizedBox(width: 4),
                                  Text(
                                    'Jitsi Active',
                                    style: TextStyle(color: Color(0xFF2563EB), fontSize: 10.5, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Direct video consultations with rural patients and ASHA health centers',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showInstantRoomDialog,
                            icon: const Icon(Icons.video_call_rounded, size: 20),
                            label: const Text('Start Instant Video Room'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 1,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Doctor Teleconsultation Hub',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.wifi_tethering_rounded, color: Color(0xFF2563EB), size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Jitsi WebRTC Active',
                                        style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Direct, high-definition video consultations with rural patients and ASHA health centers',
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _showInstantRoomDialog,
                          icon: const Icon(Icons.video_call_rounded, size: 20),
                          label: const Text('Start Instant Video Room'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 2,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  // KPI Stats Grid
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _kpiCard('Scheduled Teleconsults', '${_appointments.length}', Icons.video_camera_front_rounded, const Color(0xFF2563EB), kpiWidth, isMobile: isMobile),
                      _kpiCard('Awaiting Video Call', '$_pendingCount', Icons.pending_actions_rounded, const Color(0xFFD97706), kpiWidth, isMobile: isMobile),
                      _kpiCard('Emergency Priority', '$_emergencyCount', Icons.emergency_rounded, const Color(0xFFDC2626), kpiWidth, isMobile: isMobile),
                      _kpiCard('Completed & Prescribed', '$_completedCount', Icons.check_circle_outline_rounded, const Color(0xFF16A34A), kpiWidth, isMobile: isMobile),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Search & Filter Bar
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 10.0 : 14.0),
                      child: isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 18),
                                    hintText: 'Search patients, village, ABHA...',
                                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                                const Divider(height: 10),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _filterChip('All', 'ALL'),
                                      const SizedBox(width: 6),
                                      _filterChip('Awaiting Consult', 'PENDING'),
                                      const SizedBox(width: 6),
                                      _filterChip('Emergency', 'EMERGENCY'),
                                      const SizedBox(width: 6),
                                      _filterChip('Completed', 'COMPLETED'),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                                      hintText: 'Search teleconsultation patients by name, village, ABHA, or symptoms...',
                                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _filterChip('All', 'ALL'),
                                const SizedBox(width: 6),
                                _filterChip('Awaiting Consult', 'PENDING'),
                                const SizedBox(width: 6),
                                _filterChip('Emergency', 'EMERGENCY'),
                                const SizedBox(width: 6),
                                _filterChip('Completed', 'COMPLETED'),
                              ],
                            ),
                    ),
                  ),
              const SizedBox(height: 18),

              // Appointments Content
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
                )
              else if (_error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              else if (_filteredAppointments.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.video_camera_front_outlined, size: 54, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      const Text(
                        'No patients matching this teleconsultation filter',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scheduled appointments with voice symptoms will appear here automatically.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredAppointments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, idx) {
                    final appt = _filteredAppointments[idx];
                    return _buildTeleconsultCard(appt);
                  },
                ),
            ],
          ),
        );
      },
    ),
  ),
);
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: const Color(0xFF2563EB),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF475569),
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      side: BorderSide(color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color, double width, {bool isMobile = false}) {
    return Container(
      width: width,
      padding: EdgeInsets.all(isMobile ? 10 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: isMobile ? 20 : 24),
          ),
          SizedBox(width: isMobile ? 8 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isMobile ? 10.5 : 12,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeleconsultCard(DoctorAppointment appt) {
    final hasPrescription = appt.prescription != null && appt.prescription!.isNotEmpty;
    final isEmergency = appt.isEmergency;
    final roomName = JitsiService.generateRoomName(
      appointmentId: appt.id,
      patientName: appt.patientName,
    );
    final patientInviteUrl = JitsiService.getPatientInviteUrl(roomName);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isEmergency ? Colors.red.shade300 : const Color(0xFFE2E8F0),
          width: isEmergency ? 1.5 : 1,
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Status Bar
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    'Queue #${appt.queueNumber ?? 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8), fontSize: 12),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    appt.speciality ?? 'Tele-OPD',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155), fontSize: 12),
                  ),
                ),
                if (isEmergency)
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
                          style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasPrescription ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: hasPrescription ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Text(
                    hasPrescription ? 'Prescription Written' : 'Pending Teleconsult',
                    style: TextStyle(
                      color: hasPrescription ? const Color(0xFF166534) : const Color(0xFFB45309),
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Middle: Patient info & Symptoms
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFDBEAFE),
                  child: Text(
                    (appt.patientName != null && appt.patientName!.isNotEmpty)
                        ? appt.patientName![0].toUpperCase()
                        : 'P',
                    style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appt.patientName ?? 'Patient',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (appt.healthId != null)
                            Text('ABHA: ${appt.healthId}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          if (appt.patientPhone != null)
                            Text('Phone: ${appt.patientPhone}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          if (appt.patientVillage != null)
                            Text('Village: ${appt.patientVillage}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                      if (appt.rawTranscript != null && appt.rawTranscript!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.mic, size: 14, color: Color(0xFF0F766E)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Voice Symptoms:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF0F766E)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '"${appt.rawTranscript}"',
                                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12.5, color: Color(0xFF334155)),
                              ),
                              if (appt.extractedSymptoms.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: appt.extractedSymptoms.map((s) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(s, style: const TextStyle(fontSize: 10.5, color: Color(0xFF1E293B))),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bottom Action Bar
            Container(
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
                      Icon(Icons.link, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Jitsi Room: $roomName',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey[700], fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          await JitsiService.copyInviteLink(patientInviteUrl);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Patient teleconsult link copied!'),
                              backgroundColor: Color(0xFF0F766E),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('Copy Link', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      if (appt.patientPhone != null && appt.patientPhone!.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () async {
                            final waUrl = JitsiService.getWhatsAppInviteUrl(
                              roomName: roomName,
                              doctorName: widget.session.name,
                              patientPhone: appt.patientPhone,
                              patientName: appt.patientName,
                            );
                            if (waUrl != null) await JitsiService.launchMeeting(waUrl);
                          },
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                          label: const Text('WhatsApp', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF059669),
                            side: const BorderSide(color: Color(0xFF6EE7B7)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ElevatedButton.icon(
                        onPressed: () => _openConsultationDialog(appt),
                        icon: const Icon(Icons.videocam_rounded, size: 16),
                        label: const Text('Start Video Call', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          elevation: 0,
                        ),
                      ),
                    ],
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
