import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/unified_models.dart';
import '../../services/unified_api_service.dart';

class PatientAppointmentsView extends StatefulWidget {
  final UnifiedApiService api;
  final UnifiedUserSession session;

  const PatientAppointmentsView({super.key, required this.api, required this.session});

  @override
  State<PatientAppointmentsView> createState() => _PatientAppointmentsViewState();
}

class _PatientAppointmentsViewState extends State<PatientAppointmentsView> {
  bool _loading = true;
  String? _error;
  List<PatientAppointment> _appointments = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) _loadAppointmentsSilently();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAppointmentsSilently() async {
    try {
      final list = await widget.api.fetchPatientAppointments(widget.session.id);
      if (mounted) {
        setState(() {
          _appointments = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.api.fetchPatientAppointments(widget.session.id);
      if (mounted) {
        setState(() {
          _appointments = list;
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

  void _showBookAppointmentDialog() {
    String selectedSpecialty = 'General Medicine';
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.calendar_month, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text('Book Doctor OPD Appointment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Medical Specialty:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedSpecialty,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'General Medicine', child: Text('General Medicine')),
                    DropdownMenuItem(value: 'Cardiology', child: Text('Cardiology (Heart / Chest)')),
                    DropdownMenuItem(value: 'Pulmonology', child: Text('Pulmonology (Lungs / Cough)')),
                    DropdownMenuItem(value: 'Pediatrics', child: Text('Pediatrics (Children)')),
                    DropdownMenuItem(value: 'Orthopedics', child: Text('Orthopedics (Bones / Joints)')),
                    DropdownMenuItem(value: 'Gynecology', child: Text('Obstetrics & Gynecology')),
                    DropdownMenuItem(value: 'Dermatology', child: Text('Dermatology (Skin)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedSpecialty = val);
                  },
                ),
                const SizedBox(height: 14),
                const Text('Symptoms or Reason for Visit:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Describe your symptoms or reason...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final resp = await widget.api.createDirectPatientAppointment(
                          patientId: widget.session.id,
                          speciality: selectedSpecialty,
                          reason: reasonController.text,
                        );
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        _loadAppointments();
                        final qNum = resp['queue_number'] ?? 1;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Appointment booked in Doctor OPD Queue! Queue #$qNum'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        messenger.showSnackBar(
                          SnackBar(content: Text('Failed to book: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Confirm & Book'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: RefreshIndicator(
        onRefresh: _loadAppointments,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Doctor Consultations & Prescriptions',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Appointments scheduled by you or your ASHA worker, along with Doctor Rx',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _showBookAppointmentDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Book Appointment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAppointments),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                        : _appointments.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_month, size: 54, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    const Text('No Appointments Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    const Text('Consultations booked via voice or ASHA worker appear here.', style: TextStyle(color: Colors.grey)),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _showBookAppointmentDialog,
                                      icon: const Icon(Icons.add_circle_outline, size: 18),
                                      label: const Text('Book Doctor Appointment Now'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0F766E),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: _appointments.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 14),
                                itemBuilder: (context, index) {
                                  final appt = _appointments[index];
                                  final hasRx = appt.prescription != null && appt.prescription!.isNotEmpty;

                                  return Card(
                                    color: Colors.white,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE0F2FE),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'Queue #${appt.queueNumber ?? 1}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                appt.speciality ?? 'General Medicine',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                              const Spacer(),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: hasRx ? Colors.green.shade50 : Colors.amber.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: hasRx ? Colors.green.shade300 : Colors.amber.shade300),
                                                ),
                                                child: Text(
                                                  hasRx ? 'Prescribed' : appt.status.toUpperCase(),
                                                  style: TextStyle(
                                                    color: hasRx ? Colors.green.shade800 : Colors.amber.shade900,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Booked on ${DateFormat('dd MMM yyyy, hh:mm a').format(appt.createdAt.toLocal())}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                          ),
                                          if (hasRx) ...[
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
                                                      Icon(Icons.medication, size: 16, color: Colors.green.shade800),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        'Doctor Prescription (Rx):',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.green.shade900,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  if (appt.diagnosis != null && appt.diagnosis!.isNotEmpty)
                                                    Text('Diagnosis: ${appt.diagnosis}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                                  const SizedBox(height: 2),
                                                  Text(appt.prescription!, style: const TextStyle(color: Color(0xFF166534), fontSize: 13)),
                                                  if (appt.doctorNotes != null && appt.doctorNotes!.isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Text('Doctor Advice: ${appt.doctorNotes}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
