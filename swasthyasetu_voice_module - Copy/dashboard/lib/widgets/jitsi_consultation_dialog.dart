import 'package:flutter/material.dart';
import '../models/unified_models.dart';
import '../services/unified_api_service.dart';
import '../utils/jitsi_service.dart';

class JitsiConsultationDialog extends StatefulWidget {
  final DoctorAppointment appointment;
  final UnifiedApiService api;
  final String doctorName;
  final VoidCallback? onPrescriptionSaved;

  const JitsiConsultationDialog({
    super.key,
    required this.appointment,
    required this.api,
    required this.doctorName,
    this.onPrescriptionSaved,
  });

  static Future<void> show({
    required BuildContext context,
    required DoctorAppointment appointment,
    required UnifiedApiService api,
    required String doctorName,
    VoidCallback? onPrescriptionSaved,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => JitsiConsultationDialog(
        appointment: appointment,
        api: api,
        doctorName: doctorName,
        onPrescriptionSaved: onPrescriptionSaved,
      ),
    );
  }

  @override
  State<JitsiConsultationDialog> createState() => _JitsiConsultationDialogState();
}

class _JitsiConsultationDialogState extends State<JitsiConsultationDialog> {
  late final String _roomName;
  late final String _doctorMeetingUrl;
  late final String _patientInviteUrl;
  late final TextEditingController _diagnosisCtrl;
  late final TextEditingController _rxCtrl;
  late final TextEditingController _notesCtrl;

  bool _isSaving = false;
  bool _callStarted = false;

  @override
  void initState() {
    super.initState();
    _roomName = JitsiService.generateRoomName(
      appointmentId: widget.appointment.id,
      patientName: widget.appointment.patientName,
    );
    _doctorMeetingUrl = JitsiService.getDoctorMeetingUrl(
      roomName: _roomName,
      doctorName: widget.doctorName,
    );
    _patientInviteUrl = JitsiService.getPatientInviteUrl(_roomName);

    _diagnosisCtrl = TextEditingController(text: widget.appointment.diagnosis ?? '');
    _rxCtrl = TextEditingController(text: widget.appointment.prescription ?? '');
    _notesCtrl = TextEditingController(text: widget.appointment.notes ?? '');
  }

  @override
  void dispose() {
    _diagnosisCtrl.dispose();
    _rxCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _launchVideoCall() async {
    setState(() => _callStarted = true);
    final launched = await JitsiService.launchMeeting(_doctorMeetingUrl);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open video call. Please check popup permissions.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _copyInvite() async {
    await JitsiService.copyInviteLink(_patientInviteUrl);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text('Patient invite link copied to clipboard!')),
          ],
        ),
        backgroundColor: Color(0xFF0F766E),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _sendWhatsAppInvite() async {
    final waUrl = JitsiService.getWhatsAppInviteUrl(
      roomName: _roomName,
      doctorName: widget.doctorName,
      patientPhone: widget.appointment.patientPhone,
      patientName: widget.appointment.patientName,
    );
    if (waUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No patient phone number available for WhatsApp invite')),
      );
      return;
    }
    final launched = await JitsiService.launchMeeting(waUrl);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  Future<void> _savePrescription() async {
    final rxText = _rxCtrl.text.trim();
    if (rxText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter prescription / medications before saving.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.api.addPrescription(
        appointmentId: widget.appointment.id,
        prescription: rxText,
        diagnosis: _diagnosisCtrl.text.trim().isNotEmpty ? _diagnosisCtrl.text.trim() : null,
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      );
      if (mounted) {
        setState(() => _isSaving = false);
      }
      widget.onPrescriptionSaved?.call();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Teleconsultation prescription saved and synchronized with patient!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to save prescription: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appt = widget.appointment;
    final isEmergency = appt.isEmergency;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 880,
        constraints: const BoxConstraints(maxHeight: 740),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(Icons.video_camera_front_rounded, color: Color(0xFF2563EB), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Teleconsultation Studio (Jitsi Meet)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'WebRTC Live',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Patient: ${appt.patientName ?? "Unknown"} • Queue #${appt.queueNumber ?? 1} • Speciality: ${appt.speciality ?? "General"}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Main Body: Left (Video Launcher & Patient Info) / Right (Live Prescription & Symptoms)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT COLUMN: Jitsi Room & Patient Details
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Video Call Banner Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.video_call_rounded, color: Colors.white, size: 22),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Jitsi Meeting Room',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const Spacer(),
                                    if (_callStarted)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Text(
                                          '● ACTIVE',
                                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _roomName,
                                  style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 12, fontFamily: 'monospace'),
                                ),
                                const SizedBox(height: 14),

                                // Big CTA: Join Call
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _launchVideoCall,
                                    icon: const Icon(Icons.videocam_rounded, size: 20),
                                    label: Text(
                                      _callStarted ? 'Rejoin Video Consultation' : 'Join Video Consultation Now',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF1E3A8A),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Quick Share Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _copyInvite,
                                        icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.white),
                                        label: const Text(
                                          'Copy Link',
                                          style: TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Color(0xFF60A5FA)),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                      ),
                                    ),
                                    if (appt.patientPhone != null && appt.patientPhone!.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _sendWhatsAppInvite,
                                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.white),
                                          label: const Text(
                                            'WhatsApp',
                                            style: TextStyle(color: Colors.white, fontSize: 12),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Color(0xFF34D399)),
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Patient Information Card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Patient Demographics',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                ),
                                const SizedBox(height: 8),
                                _infoRow(Icons.person_outline, 'Name', appt.patientName ?? 'Unknown'),
                                if (appt.healthId != null) _infoRow(Icons.badge_outlined, 'ABHA ID', appt.healthId!),
                                if (appt.patientPhone != null) _infoRow(Icons.phone_outlined, 'Phone', appt.patientPhone!),
                                if (appt.patientVillage != null) _infoRow(Icons.home_outlined, 'Village', appt.patientVillage!),
                                if (isEmergency) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.red.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          appt.redFlagType ?? 'EMERGENCY RED FLAG',
                                          style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Symptoms & Voice Note Context
                          if (appt.rawTranscript != null && appt.rawTranscript!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.mic_rounded, color: Color(0xFF16A34A), size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'Reported Audio Symptoms',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF166534)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '"${appt.rawTranscript}"',
                                    style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12.5, color: Color(0xFF14532D)),
                                  ),
                                  if (appt.translatedText != null && appt.translatedText!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Translation: "${appt.translatedText}"',
                                      style: TextStyle(fontSize: 11.5, color: Colors.green.shade900),
                                    ),
                                  ],
                                  if (appt.extractedSymptoms.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: appt.extractedSymptoms.map((s) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(s, style: const TextStyle(fontSize: 10.5, color: Color(0xFF166534))),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),
                  const VerticalDivider(width: 1),
                  const SizedBox(width: 20),

                  // RIGHT COLUMN: Live Prescription Pad & Diagnosis Editor
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.edit_note_rounded, color: Color(0xFF0F766E), size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Live Consultation Pad (Rx)',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                            ),
                            const Spacer(),
                            Text(
                              'Auto-syncs to ABHA / Health ID',
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _diagnosisCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Clinical Diagnosis / Impression',
                            hintText: 'e.g. Acute Bronchitis, Angina Pectoris, Viral URI',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: TextField(
                            controller: _rxCtrl,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: const InputDecoration(
                              labelText: 'Prescription & Medication (Rx) *',
                              hintText: '1. Tab Paracetamol 500mg TDS x 3 days\n2. Syp Ambroxol 5ml BD x 5 days\n3. Rest & warm water hydration',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Doctor Advice / Follow-up Notes',
                            hintText: 'Follow up in 3 days if fever persists or breathing difficulty occurs.',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Bottom Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _isSaving ? null : _savePrescription,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
                              label: Text(_isSaving ? 'Saving...' : 'Save & Issue Prescription'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F766E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
