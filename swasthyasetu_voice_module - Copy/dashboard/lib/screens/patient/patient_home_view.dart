import 'package:flutter/material.dart';
import '../../models/unified_models.dart';
import '../../services/unified_api_service.dart';
import '../../services/patient_location_service.dart';
import '../../services/localization_service.dart';
import '../../widgets/patient_nearby_services_dialogs.dart';

class PatientHomeView extends StatefulWidget {
  final UnifiedApiService api;
  final UnifiedUserSession session;
  final Function(int)? onNavigateTab;

  const PatientHomeView({
    super.key,
    required this.api,
    required this.session,
    this.onNavigateTab,
  });

  @override
  State<PatientHomeView> createState() => _PatientHomeViewState();
}

class _PatientHomeViewState extends State<PatientHomeView> {
  // Mock/Live active state
  final int _queuePosition = 1;
  final int _estimatedWaitMinutes = 24;
  bool _checkedIn = false;

  void _showReportSymptomsDialog({bool isVoice = false}) {
    final textController = TextEditingController(text: isVoice ? 'Severe cough and breathing difficulty for 2 days' : '');
    bool submitting = false;
    String? triageResult;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          title: Row(
            children: [
              Icon(isVoice ? Icons.mic_rounded : Icons.edit_note_rounded, color: const Color(0xFF1D4ED8)),
              const SizedBox(width: 8),
              Text(isVoice ? 'Voice Symptom Intake' : 'Report Symptoms'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mandatory Safety Principle Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI-assisted suggestion only — does not diagnose. Confirmed by a licensed clinician.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (isVoice) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.graphic_eq_rounded, color: Color(0xFF1D4ED8)),
                        SizedBox(width: 8),
                        Text('Whisper STT Active • Hindi / English / Marathi', style: TextStyle(fontSize: 12, color: Color(0xFF1D4ED8))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: textController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Describe Symptoms',
                    hintText: 'e.g. Mild fever, headache, sore throat...',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (triageResult != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF16A34A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Triage Guidance: $triageResult', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                        const SizedBox(height: 4),
                        const Text(
                          'AI-assisted suggestion only — does not diagnose. Confirmed by a licensed clinician.',
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            if (triageResult == null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8), foregroundColor: Colors.white),
                onPressed: submitting
                    ? null
                    : () async {
                        setStateModal(() => submitting = true);
                        await Future.delayed(const Duration(milliseconds: 600));
                        setStateModal(() {
                          submitting = false;
                          triageResult = textController.text.toLowerCase().contains('breath') || textController.text.toLowerCase().contains('chest')
                              ? 'REVIEW / URGENT (Recommended to see PHC Doctor today)'
                              : 'ROUTINE CARE (OPD Queue Slot #2)';
                        });
                      },
                child: submitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit & Triage'),
              ),
          ],
        ),
      ),
    );
  }

  void _showQueueStatusDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.queue_rounded, color: Color(0xFF1D4ED8)),
              SizedBox(width: 8),
              Text('Live PHC Queue Status'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Column(
                  children: [
                    const Text('YOUR QUEUE NUMBER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                    const SizedBox(height: 8),
                    Text('#$_queuePosition', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                    const SizedBox(height: 4),
                    Text('Estimated Wait: $_estimatedWaitMinutes min', style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('OPD Status:'),
                  Text(_checkedIn ? 'Checked-In (Waiting)' : 'Booked (Arrive at PHC)', style: TextStyle(fontWeight: FontWeight.bold, color: _checkedIn ? Colors.green : Colors.orange)),
                ],
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Assigned Clinician:'),
                  Text('Dr. Rajesh Sharma', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          actions: [
            if (!_checkedIn)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Check In at PHC'),
                onPressed: () {
                  setStateModal(() => _checkedIn = true);
                  setState(() => _checkedIn = true);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checked in! Doctor notified.')));
                },
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ],
        ),
      ),
    );
  }

  void _showHealthRecordsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.folder_shared_rounded, color: Color(0xFF1D4ED8)),
            SizedBox(width: 8),
            Text('My Health Records (ABHA / ABDM)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Text('ABHA ID: ${widget.session.identifier} • Verified', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Linked Clinical Encounters:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            _recordTile('PHC General OPD Encounter', '16 Sep 2026', 'Tier 2 Consent Active'),
            _recordTile('CBC & Rapid Malaria Lab Report', '15 Sep 2026', 'Verified by Lab Tech'),
            _recordTile('Cardiology Referral (Sassoon General Hospital, Pune)', '14 Sep 2026', 'Completed'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _recordTile(String title, String date, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, size: 16, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text('$date • $status', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPrescriptionsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.medication_liquid_rounded, color: Color(0xFF1D4ED8)),
            SizedBox(width: 8),
            Text('My Prescriptions'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Rx #RX-2026-001', style: TextStyle(fontWeight: FontWeight.bold)),
                      Spacer(),
                      Text('Dr. Rajesh Sharma', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                  Divider(height: 16),
                  Text('• Paracetamol 500mg — 1 tablet TDS (3 days)', style: TextStyle(fontSize: 13)),
                  Text('• Cetirizine 10mg — 1 tablet HS (3 days)', style: TextStyle(fontSize: 13)),
                  SizedBox(height: 8),
                  Text('Status: Dispensed at Shivaji Nagar PHC Pharmacy', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showLabResultsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.biotech_rounded, color: Color(0xFF1D4ED8), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Diagnostic Lab Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  Text('Official lab findings verified by PHC Laboratory', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 520),
          width: double.maxFinite,
          child: FutureBuilder<List<LabTestOrder>>(
            future: widget.api.fetchPatientLabResults(widget.session.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: Color(0xFF1D4ED8)),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Unable to load lab reports: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  ),
                );
              }

              final results = snapshot.data ?? [];
              if (results.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No lab tests recorded yet for this patient profile.'),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                itemCount: results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final item = results[idx];
                  Color statusColor;
                  String statusLabel;
                  if (item.status == 'result_uploaded') {
                    statusColor = Colors.green;
                    statusLabel = 'RESULT UPLOADED';
                  } else if (item.status == 'sample_collected') {
                    statusColor = const Color(0xFF1D4ED8);
                    statusLabel = 'SAMPLE COLLECTED';
                  } else {
                    statusColor = Colors.orange;
                    statusLabel = 'PENDING SAMPLE';
                  }

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Spacer(),
                            if (item.resultRef != null)
                              Text(
                                item.resultRef!,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.testType,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ordered by: ${item.doctorName}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        if (item.resultSummary != null && item.resultSummary!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              item.resultSummary!,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showTeleconsultationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.video_camera_front_rounded, color: Color(0xFF1D4ED8)),
            SizedBox(width: 8),
            Text('Teleconsultation Room'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_rounded, color: Colors.white, size: 48),
                    SizedBox(height: 8),
                    Text('WebRTC Video Consultation Active', style: TextStyle(color: Colors.white, fontSize: 13)),
                    Text('🟢 GOOD INTERNET (Connected to Dr. Rajesh Sharma)', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Safety Notice: AI-assisted suggestion only — does not diagnose. Confirmed by a licensed clinician.',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Leave Call'),
          ),
        ],
      ),
    );
  }

  void _triggerEmergency() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emergency_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('108 EMERGENCY ASSISTANCE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🚨 Immediate Emergency Protocol Initiated:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 8),
            Text('1. Mock 108 Emergency Ambulance Dispatched.'),
            Text('2. Shivaji Nagar PHC Emergency Ward Notified.'),
            Text('3. Assigned ASHA Worker (Sunita Kamble) Alerted.'),
            SizedBox(height: 12),
            Text(
              'If conscious, remain seated and keep airway clear. First aid team is responding.',
              style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Acknowledge'),
          ),
        ],
      ),
    );
  }

  void _showNearbyMedicineDialog() {
    final locService = PatientLocationService.instance;
    NearbyMedicineAvailabilityDialog.show(
      context,
      api: widget.api,
      locationName: locService.locationName,
      lat: locService.latitude,
      lng: locService.longitude,
    );
  }

  void _showNearbyDiagnosticsDialog() {
    final locService = PatientLocationService.instance;
    NearbyDiagnosticCentresDialog.show(
      context,
      api: widget.api,
      locationName: locService.locationName,
      lat: locService.latitude,
      lng: locService.longitude,
    );
  }

  void _showMaharashtraDistrictSelector() {
    final locService = PatientLocationService.instance;
    final loc = AppLocalizationService.instance;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.location_city_rounded, color: Color(0xFF1D4ED8), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.t('btn_switch_district'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            const Text(
                              'Maharashtra Health Grid • District Health Services',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Select your active Maharashtra district to scope nearby PHCs, hospitals, pharmacies, and 108 ambulance response:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: PatientLocationService.maharashtraPresets.length,
                      itemBuilder: (context, index) {
                        final item = PatientLocationService.maharashtraPresets[index];
                        final isSelected = (locService.latitude - item.lat).abs() < 0.001 &&
                            (locService.longitude - item.lng).abs() < 0.001;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          elevation: isSelected ? 1.5 : 0,
                          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFF1D4ED8) : Colors.grey.shade300,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFFF1F5F9),
                              child: Icon(
                                Icons.location_on,
                                color: isSelected ? Colors.white : const Color(0xFF475569),
                                size: 18,
                              ),
                            ),
                            title: Text(
                              item.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF1E293B),
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              '${item.nearbyFacility} • ${item.lat.toStringAsFixed(4)}° N, ${item.lng.toStringAsFixed(4)}° E',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF1D4ED8))
                                : const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                            onTap: () {
                              locService.selectPreset(item);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Active location set to ${item.name}, Maharashtra'),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: const Color(0xFF1D4ED8),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLiveGpsCard(PatientLocationService locService, AppLocalizationService loc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: locService.isLiveGps ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (locService.isLiveGps ? const Color(0xFF10B981) : const Color(0xFF3B82F6)).withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              // Pulsing / glowing radar badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: locService.isLiveGps
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: locService.isLiveGps
                        ? const Color(0xFF34D399)
                        : const Color(0xFF93C5FD),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      locService.isDetecting
                          ? Icons.satellite_alt_rounded
                          : (locService.isLiveGps ? Icons.gps_fixed_rounded : Icons.location_on_rounded),
                      size: 13,
                      color: locService.isLiveGps ? const Color(0xFF059669) : const Color(0xFF1D4ED8),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      locService.isDetecting
                          ? loc.t('gps_status_detecting')
                          : (locService.isLiveGps
                              ? loc.t('live_gps_chip').toUpperCase()
                              : 'MAHARASHTRA HEALTH GRID SCOPED'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                        color: locService.isLiveGps ? const Color(0xFF065F46) : const Color(0xFF1E40AF),
                      ),
                    ),
                  ],
                ),
              ),
              // Accuracy Tag
              Text(
                '±${locService.accuracyMeters.toStringAsFixed(1)} m ${loc.t('gps_accuracy')}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                locService.locationName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.explore_outlined, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        locService.coordinatesDisplay,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Maharashtra, India',
                      style: TextStyle(fontSize: 10, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (locService.errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      locService.errorMessage!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Action Buttons: Fetch Live GPS & Change District
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: locService.isDetecting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded, size: 16),
                label: Text(
                  locService.isDetecting ? 'Detecting GPS...' : loc.t('btn_fetch_live_gps'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: locService.isDetecting ? null : () => locService.detectLiveGps(),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1D4ED8),
                  side: const BorderSide(color: Color(0xFF93C5FD)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: Text(
                  loc.t('btn_switch_district'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: _showMaharashtraDistrictSelector,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locService = PatientLocationService.instance;
    final loc = AppLocalizationService.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([locService, loc]),
      builder: (context, _) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 768;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F9),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 12 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient Welcome Banner
                Container(
                  padding: EdgeInsets.all(isMobile ? 16 : 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF1D4ED8).withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                                  child: const Icon(Icons.person, color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${loc.t('welcome_patient')} ${widget.session.name}',
                                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Health ID: ${widget.session.identifier} • ${locService.locationName}',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.warning_amber_rounded),
                                label: Text(loc.t('emergency_sos'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: _triggerEmergency,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              child: const Icon(Icons.person, color: Colors.white, size: 32),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${loc.t('welcome_patient')} ${widget.session.name}',
                                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Health ID: ${widget.session.identifier} • ${locService.locationName}',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            // Emergency Quick Button
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              icon: const Icon(Icons.warning_amber_rounded),
                              label: Text(loc.t('emergency_sos'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: _triggerEmergency,
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),

                // Mandatory Safety Principle Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: Color(0xFFB45309), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          loc.t('ai_safety_notice'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // LIVE PATIENT GPS LOCATION CARD (MAHARASHTRA)
                _buildLiveGpsCard(locService, loc),

                // LOCATION-BASED HEALTHCARE SERVICES (MEDICINE & DIAGNOSTIC AVAILABILITY)
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.near_me_rounded, color: Color(0xFF059669), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          loc.t('nearby_healthcare_title'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, size: 12, color: Color(0xFF059669)),
                          const SizedBox(width: 4),
                          Text(
                            locService.isLiveGps ? 'Live GPS Active' : 'Maharashtra Scoped',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                final medCard = Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF065F46), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF059669).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(loc.t('medicine_availability'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text(loc.t('medicine_availability_sub'), style: const TextStyle(fontSize: 11, color: Colors.white70)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                         'Live real-time inventory from Shivaji Nagar PHC, Jan Aushadhi Stores & Govt Hospitals within 10 km.',
                         style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.3),
                       ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.search_rounded, size: 16),
                          label: Text(loc.t('check_medicine_stock'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF065F46),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _showNearbyMedicineDialog,
                        ),
                      ),
                    ],
                  ),
                );

                final diagCard = Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3730A3), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.biotech_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(loc.t('diagnostic_centres'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text(loc.t('diagnostic_centres_sub'), style: const TextStyle(fontSize: 11, color: Colors.white70)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'CBC, Blood Sugar, Thyroid, X-Ray & ECG test slots with transparent pricing and turnaround times.',
                        style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.3),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.location_searching_rounded, size: 16),
                          label: Text(loc.t('find_diagnostic_centres'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF3730A3),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _showNearbyDiagnosticsDialog,
                        ),
                      ),
                    ],
                  ),
                );

                return isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: medCard),
                          const SizedBox(width: 16),
                          Expanded(child: diagCard),
                        ],
                      )
                    : Column(
                        children: [
                          medCard,
                          const SizedBox(height: 12),
                          diagCard,
                        ],
                      );
              },
            ),
            const SizedBox(height: 24),

            Text(
              loc.t('patient_services_title'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 16),

            // The 11 Patient Action Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final isMedium = constraints.maxWidth > 600;
                final crossAxisCount = isWide ? 4 : (isMedium ? 3 : 2);

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.15,
                  children: [
                    _buildServiceCard(
                      title: loc.t('svc_report_symptoms'),
                      subtitle: loc.t('svc_report_symptoms_sub'),
                      icon: Icons.edit_note_rounded,
                      color: const Color(0xFF1D4ED8),
                      onTap: () => _showReportSymptomsDialog(isVoice: false),
                    ),
                    _buildServiceCard(
                      title: loc.t('svc_voice_report'),
                      subtitle: loc.t('svc_voice_report_sub'),
                      icon: Icons.mic_rounded,
                      color: const Color(0xFF0F766E),
                      onTap: () => _showReportSymptomsDialog(isVoice: true),
                    ),
                    _buildServiceCard(
                      title: loc.t('svc_book_appt'),
                      subtitle: loc.t('svc_book_appt_sub'),
                      icon: Icons.calendar_month_rounded,
                      color: const Color(0xFF0D9488),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(loc.t('appt_booked_snackbar'))),
                        );
                      },
                    ),
                    _buildServiceCard(
                      title: loc.t('svc_my_appts'),
                      subtitle: loc.t('svc_my_appts_sub'),
                      icon: Icons.event_note_rounded,
                      color: const Color(0xFF2563EB),
                      onTap: () => widget.onNavigateTab?.call(1),
                    ),
                    _buildServiceCard(
                      title: loc.t('svc_queue'),
                      subtitle: loc.t('svc_queue_sub'),
                      icon: Icons.timer_outlined,
                      color: const Color(0xFFEA580C),
                      onTap: _showQueueStatusDialog,
                    ),
                    _buildServiceCard(
                      title: loc.t('svc_records'),
                      subtitle: loc.t('svc_records_sub'),
                      icon: Icons.folder_shared_rounded,
                      color: const Color(0xFF7C3AED),
                      onTap: _showHealthRecordsDialog,
                    ),
                    _buildServiceCard(
                      title: loc.t('svc_rx'),
                      subtitle: loc.t('svc_rx_sub'),
                      icon: Icons.medication_liquid_rounded,
                      color: const Color(0xFF059669),
                      onTap: _showPrescriptionsDialog,
                    ),
                    _buildServiceCard(
                      title: loc.t('svc_lab'),
                      subtitle: loc.t('svc_lab_sub'),
                      icon: Icons.biotech_rounded,
                      color: const Color(0xFF6366F1),
                      onTap: _showLabResultsDialog,
                    ),
                    _buildServiceCard(
                      title: loc.t('svc_referrals'),
                      subtitle: loc.t('svc_referrals_sub'),
                      icon: Icons.alt_route_rounded,
                      color: const Color(0xFF4338CA),
                      onTap: () => widget.onNavigateTab?.call(2),
                    ),
                    _buildServiceCard(
                      title: loc.t('svc_teleconsult'),
                      subtitle: loc.t('svc_teleconsult_sub'),
                      icon: Icons.video_camera_front_rounded,
                      color: const Color(0xFF0284C7),
                      onTap: _showTeleconsultationDialog,
                    ),
                    _buildServiceCard(
                      title: loc.t('svc_medicines'),
                      subtitle: loc.t('svc_medicines_sub'),
                      icon: Icons.local_pharmacy_rounded,
                      color: const Color(0xFF059669),
                      onTap: _showNearbyMedicineDialog,
                    ),
                    _buildServiceCard(
                      title: loc.t('svc_diagnostics'),
                      subtitle: loc.t('svc_diagnostics_sub'),
                      icon: Icons.biotech_rounded,
                      color: const Color(0xFF4F46E5),
                      onTap: _showNearbyDiagnosticsDialog,
                    ),
                    _buildServiceCard(
                      title: loc.t('svc_emergency_assist'),
                      subtitle: loc.t('svc_emergency_assist_sub'),
                      icon: Icons.emergency_rounded,
                      color: Colors.red.shade700,
                      isSpecial: true,
                      onTap: _triggerEmergency,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  },
);
}

  Widget _buildServiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isSpecial = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSpecial ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSpecial ? Colors.red.shade300 : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSpecial ? Colors.red.shade900 : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isSpecial ? Colors.red.shade700 : const Color(0xFF64748B),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
