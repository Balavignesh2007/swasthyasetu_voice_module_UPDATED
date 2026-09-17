import 'package:flutter/material.dart';
import '../../models/unified_models.dart';
import '../../services/unified_api_service.dart';

class LaboratoryView extends StatefulWidget {
  final UnifiedApiService api;
  final UnifiedUserSession session;

  const LaboratoryView({super.key, required this.api, required this.session});

  @override
  State<LaboratoryView> createState() => _LaboratoryViewState();
}

class _LaboratoryViewState extends State<LaboratoryView> {
  bool _loading = true;
  String? _error;
  List<LabTestOrder> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await widget.api.fetchLabOrders();
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markCollected(LabTestOrder order) async {
    try {
      await widget.api.markLabSampleCollected(order.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sample recorded as collected for ${order.testType} (${order.patientName})'),
          backgroundColor: const Color(0xFF6366F1),
        ),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _uploadResultDialog(LabTestOrder order) async {
    final refController = TextEditingController(text: 'LAB-RPT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final summaryController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Upload Test Result: ${order.testType}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Patient: ${order.patientName} (${order.healthId})'),
              const SizedBox(height: 12),
              TextField(
                controller: refController,
                decoration: const InputDecoration(labelText: 'Report Reference Number', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: summaryController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Diagnostic Findings & Normal Range Summary',
                  hintText: 'e.g. Hb: 12.4 g/dL (Normal: 12-15), WBC: 7,500/mcL. No malarial parasite detected.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
            onPressed: () async {
              if (summaryController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await widget.api.uploadLabResult(
                order.id,
                refController.text.trim(),
                summaryController.text.trim(),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Result uploaded and ordering doctor notified automatically!'),
                  backgroundColor: Color(0xFF16A34A),
                ),
              );
              _loadData();
            },
            child: const Text('Upload & Notify Doctor'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateLabOrderDialog() async {
    final defaultPatients = [
      {'id': 'usr-patient-001', 'name': 'Ramesh Patil', 'healthId': 'HID10001'},
      {'id': 'usr-patient-003', 'name': 'Kavita Shinde', 'healthId': 'HID10003'},
      {'id': 'usr-patient-004', 'name': 'Suresh Gaikwad', 'healthId': 'HID10004'},
    ];

    String selectedPatientId = defaultPatients[0]['id']!;
    String selectedPatientName = defaultPatients[0]['name']!;
    String selectedHealthId = defaultPatients[0]['healthId']!;
    bool isCustomPatient = false;

    final customNameCtrl = TextEditingController();
    final customHealthIdCtrl = TextEditingController();

    final testTemplates = {
      'Complete Blood Count (CBC)':
          'Hb: 13.5 g/dL (Normal: 12.0 - 15.5), WBC: 7,800 /mcL (Normal: 4,500 - 11,000), Platelets: 2.3 Lakhs /mcL (Normal: 1.5 - 4.5)',
      'Fasting Blood Sugar (FBS)':
          'Fasting Blood Sugar: 104 mg/dL (Normal: 70 - 99 mg/dL - Impaired Fasting Glycemia)',
      'HbA1c Glycated Hemoglobin':
          'HbA1c: 6.4% (Normal: <5.7%, Prediabetes: 5.7 - 6.4%, Diabetes: >=6.5%)',
      'Rapid Malaria Antigen':
          'Malaria Antigen (Pf/Pv): Negative for Plasmodium falciparum and Plasmodium vivax antigen.',
      'Dengue NS1 Antigen':
          'Dengue NS1 Antigen: Non-Reactive / Negative. IgG & IgM Antibodies: Non-reactive.',
      'Lipid Profile':
          'Total Cholesterol: 184 mg/dL (Desirable: <200), HDL: 44 mg/dL, LDL: 110 mg/dL, Triglycerides: 150 mg/dL',
      'Liver Function Test (LFT)':
          'Bilirubin Total: 0.9 mg/dL (Normal: 0.2 - 1.2), SGOT/AST: 28 U/L (Normal: 5 - 40), SGPT/ALT: 32 U/L (Normal: 7 - 56)',
      'Urine Routine & Micro':
          'Color: Pale Yellow, Specific Gravity: 1.020, Albumin: Nil, Sugar: Nil, Pus Cells: 1-2 /HPF',
    };

    String selectedTestType = 'Complete Blood Count (CBC)';
    final testTypeCtrl = TextEditingController(text: selectedTestType);
    final refController = TextEditingController(
      text: 'LAB-RPT-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
    );
    final summaryController = TextEditingController(
      text: testTemplates['Complete Blood Count (CBC)'],
    );
    String selectedStatus = 'result_uploaded';
    bool submitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.biotech_rounded, color: Color(0xFF6366F1), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Record & Publish Lab Test Data',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      'Adds diagnostic results to Patient Portal & notifies Doctor',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Safety Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_user_rounded, color: Color(0xFF6366F1), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Facility Scoped: PHC Rampur Laboratory. Verified by On-duty Lab Technician.',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4338CA)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Patient Selector
                  const Text('Select Target Patient:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...defaultPatients.map((p) {
                        final isSelected = !isCustomPatient && selectedPatientId == p['id'];
                        return ChoiceChip(
                          label: Text('${p['name']} (${p['healthId']})'),
                          selected: isSelected,
                          selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                          onSelected: (val) {
                            if (val) {
                              setStateModal(() {
                                isCustomPatient = false;
                                selectedPatientId = p['id']!;
                                selectedPatientName = p['name']!;
                                selectedHealthId = p['healthId']!;
                              });
                            }
                          },
                        );
                      }),
                      ChoiceChip(
                        label: const Text('+ Other Patient'),
                        selected: isCustomPatient,
                        selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                        onSelected: (val) {
                          setStateModal(() {
                            isCustomPatient = val;
                          });
                        },
                      ),
                    ],
                  ),

                  if (isCustomPatient) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Patient Full Name',
                              hintText: 'e.g. Ramesh Patil',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: customHealthIdCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Health ID (ABHA / HID)',
                              hintText: 'e.g. HID10001',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Text('Common Diagnostic Tests (Click to populate findings template):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: testTemplates.keys.map((testName) {
                      final isSelected = selectedTestType == testName;
                      return ChoiceChip(
                        label: Text(testName, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        selected: isSelected,
                        selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        onSelected: (val) {
                          if (val) {
                            setStateModal(() {
                              selectedTestType = testName;
                              testTypeCtrl.text = testName;
                              summaryController.text = testTemplates[testName] ?? '';
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),
                  TextField(
                    controller: testTypeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Diagnostic Test Name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      selectedTestType = val;
                    },
                  ),

                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: refController,
                          decoration: const InputDecoration(
                            labelText: 'Report Reference Number',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Order / Lab Status',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'result_uploaded', child: Text('Result Uploaded & Ready')),
                            DropdownMenuItem(value: 'sample_collected', child: Text('Sample Collected')),
                            DropdownMenuItem(value: 'pending', child: Text('Pending Sample')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setStateModal(() => selectedStatus = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  TextField(
                    controller: summaryController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Diagnostic Findings & Reference Ranges (Visible to Patient & Doctor)',
                      hintText: 'Enter numerical values, units, and normal benchmark ranges...',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    'Safety principle: AI-assisted suggestion only — does not diagnose. Confirmed by a licensed clinician.',
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(submitting ? 'Publishing...' : 'Add Data & Sync to Patient Portal'),
              onPressed: submitting
                  ? null
                  : () async {
                      final testName = testTypeCtrl.text.trim();
                      if (testName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please specify a test name.')));
                        return;
                      }

                      final targetPatId = isCustomPatient
                          ? (customHealthIdCtrl.text.trim().isNotEmpty ? customHealthIdCtrl.text.trim() : 'usr-patient-custom')
                          : selectedPatientId;
                      final targetPatName = isCustomPatient
                          ? (customNameCtrl.text.trim().isNotEmpty ? customNameCtrl.text.trim() : 'Patient')
                          : selectedPatientName;
                      final targetHealthId = isCustomPatient
                          ? (customHealthIdCtrl.text.trim().isNotEmpty ? customHealthIdCtrl.text.trim() : 'HID-CUSTOM')
                          : selectedHealthId;

                      setStateModal(() => submitting = true);
                      try {
                        await widget.api.createLabOrder(
                          patientId: targetPatId,
                          testType: testName,
                          healthId: targetHealthId,
                          patientName: targetPatName,
                          status: selectedStatus,
                          resultRef: refController.text.trim(),
                          resultSummary: summaryController.text.trim(),
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Lab data for "$testName" recorded & synced to Patient Portal ($targetPatName)!'),
                            backgroundColor: const Color(0xFF16A34A),
                          ),
                        );
                        _loadData();
                      } catch (e) {
                        setStateModal(() => submitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error adding lab data: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _orders.where((o) => o.status == 'pending').length;
    final collectedCount = _orders.where((o) => o.status == 'sample_collected').length;
    final completedCount = _orders.where((o) => o.status == 'result_uploaded').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Column(
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.biotech_rounded, color: Color(0xFF6366F1), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'PHC Laboratory Test Portal',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'FACILITY-SCOPED ORDERS',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pending: $pendingCount • Sample Collected: $collectedCount • Results Completed: $completedCount',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('Add Lab Test / Record Data', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _showCreateLabOrderDialog,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6366F1)),
                  onPressed: _loadData,
                ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                : _error != null
                    ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
                    : _orders.isEmpty
                        ? const Center(child: Text('No diagnostic test orders currently assigned.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(24),
                            itemCount: _orders.length,
                            itemBuilder: (context, index) {
                              final o = _orders[index];
                              Color statusColor;
                              String statusText;
                              if (o.status == 'pending') {
                                statusColor = Colors.orange;
                                statusText = 'PENDING SAMPLE';
                              } else if (o.status == 'sample_collected') {
                                statusColor = const Color(0xFF6366F1);
                                statusText = 'SAMPLE COLLECTED';
                              } else {
                                statusColor = Colors.green;
                                statusText = 'RESULT UPLOADED';
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(20),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            statusText,
                                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          o.testType,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'Ordered by: ${o.doctorName}',
                                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Patient: ${o.patientName} (${o.healthId})',
                                      style: const TextStyle(fontSize: 14, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                    ),
                                    if (o.resultRef != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Report Ref: ${o.resultRef}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                                      ),
                                    ],
                                    if (o.resultSummary != null) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Text(
                                          'Summary: ${o.resultSummary}',
                                          style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (o.status == 'pending')
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF6366F1),
                                              foregroundColor: Colors.white,
                                            ),
                                            icon: const Icon(Icons.colorize_rounded, size: 18),
                                            label: const Text('Mark Sample Collected'),
                                            onPressed: () => _markCollected(o),
                                          ),
                                        if (o.status == 'sample_collected')
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF16A34A),
                                              foregroundColor: Colors.white,
                                            ),
                                            icon: const Icon(Icons.upload_file_rounded, size: 18),
                                            label: const Text('Upload Result & Notify Doctor'),
                                            onPressed: () => _uploadResultDialog(o),
                                          ),
                                        if (o.status == 'result_uploaded')
                                          const Text(
                                            'Result archived and verified',
                                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
