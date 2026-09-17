import 'package:flutter/material.dart';
import '../../models/unified_models.dart';
import '../../services/unified_api_service.dart';
import '../../widgets/patient_followup_dashboard_dialog.dart';

class AshaPatientsView extends StatefulWidget {
  final UnifiedApiService api;
  final UnifiedUserSession session;

  const AshaPatientsView({super.key, required this.api, required this.session});

  @override
  State<AshaPatientsView> createState() => _AshaPatientsViewState();
}

class _AshaPatientsViewState extends State<AshaPatientsView> {
  bool _loading = true;
  String? _error;
  List<AshaPatient> _patients = [];

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.api.fetchAshaPatients(ashaId: widget.session.id);
      if (mounted) {
        setState(() {
          _patients = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load patients: $e';
          _loading = false;
        });
      }
    }
  }

  void _showRegisterDialog() {
    final nameCtrl = TextEditingController();
    final healthIdCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final villageCtrl = TextEditingController(text: widget.session.extra['village'] ?? '');
    final ageCtrl = TextEditingController();
    String selectedGender = 'Male';

    // Aadhaar State
    final aadhaarCtrl = TextEditingController();
    final aadhaarOtpCtrl = TextEditingController();
    bool aadhaarOtpSent = false;
    bool aadhaarVerified = false;
    String? aadhaarTxnId;
    bool aadhaarLoading = false;

    // ABHA State
    final abhaInputCtrl = TextEditingController();
    final abhaOtpCtrl = TextEditingController();
    bool abhaOtpSent = false;
    bool abhaVerified = false;
    String? abhaTxnId;
    bool abhaLoading = false;

    bool submitting = false;

    // Auto-generate initial Health ID
    final initRand = (10000 + (DateTime.now().millisecondsSinceEpoch % 90000)).toString();
    healthIdCtrl.text = 'HID-${DateTime.now().year}-$initRand';

    void autoGenerateHealthId(void Function(void Function()) setDialogState) {
      final rand = (10000 + (DateTime.now().millisecondsSinceEpoch % 90000)).toString();
      setDialogState(() {
        healthIdCtrl.text = 'HID-${DateTime.now().year}-$rand';
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── HEADER ───
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Register New Patient', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                            SizedBox(height: 2),
                            Text('ABDM Ayushman Bharat Digital Health Onboarding', style: TextStyle(fontSize: 12, color: Color(0xFFCCFBF1))),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: submitting ? null : () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                ),

                // ─── FORM BODY ───
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ══════ SECTION 1: Patient Details ══════
                        _buildSectionHeader(Icons.person_rounded, 'Patient Details', const Color(0xFF0F766E)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Full Name *',
                            hintText: 'e.g. Ramesh Patil',
                            prefixIcon: const Icon(Icons.person_outline, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: ageCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Age',
                                  hintText: 'e.g. 35',
                                  prefixIcon: const Icon(Icons.cake_outlined, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  isDense: true,
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedGender,
                                items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                                onChanged: (v) => setDialogState(() => selectedGender = v ?? 'Male'),
                                decoration: InputDecoration(
                                  labelText: 'Gender',
                                  prefixIcon: const Icon(Icons.wc_outlined, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  isDense: true,
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            hintText: '+91 98765 43210',
                            prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: villageCtrl,
                          decoration: InputDecoration(
                            labelText: 'Village / Ward',
                            hintText: 'e.g. Rampur / Ward 4',
                            prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                        ),

                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // ══════ SECTION 2: Health ID ══════
                        _buildSectionHeader(Icons.badge_rounded, 'Health ID (Auto-Generated)', const Color(0xFF0369A1)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: healthIdCtrl,
                                decoration: InputDecoration(
                                  labelText: 'ABHA / Health ID *',
                                  prefixIcon: const Icon(Icons.qr_code_2_rounded, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  isDense: true,
                                  filled: true,
                                  fillColor: const Color(0xFFEFF6FF),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0369A1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Auto-Generate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: () => autoGenerateHealthId(setDialogState),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // ══════ SECTION 3: Aadhaar OTP ══════
                        _buildSectionHeader(
                          Icons.fingerprint_rounded,
                          'Aadhaar Verification (OTP)',
                          const Color(0xFF0F766E),
                          trailing: aadhaarVerified
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 14),
                                      SizedBox(width: 4),
                                      Text('VERIFIED', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 11)),
                                    ],
                                  ),
                                )
                              : const Text('Optional', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        ),
                        const SizedBox(height: 12),
                        if (!aadhaarVerified) ...[
                          TextField(
                            controller: aadhaarCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: '12-Digit Aadhaar Number',
                              hintText: 'e.g. 9876 5432 1098',
                              prefixIcon: const Icon(Icons.credit_card_rounded, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF0FDFA),
                              suffixIcon: Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: TextButton(
                                  onPressed: aadhaarLoading
                                      ? null
                                      : () async {
                                          if (aadhaarCtrl.text.trim().length < 4) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid Aadhaar number')));
                                            return;
                                          }
                                          setDialogState(() => aadhaarLoading = true);
                                          try {
                                            final res = await widget.api.generateAadhaarOtp(aadhaarCtrl.text.trim());
                                            setDialogState(() {
                                              aadhaarLoading = false;
                                              aadhaarOtpSent = true;
                                              aadhaarTxnId = res['txn_id'];
                                            });
                                          } catch (e) {
                                            setDialogState(() => aadhaarLoading = false);
                                            if (dialogCtx.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                                            }
                                          }
                                        },
                                  child: Text(
                                    aadhaarLoading ? 'Sending...' : (aadhaarOtpSent ? 'Resend OTP' : 'Send OTP'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (aadhaarOtpSent) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, size: 14, color: Color(0xFFB45309)),
                                  SizedBox(width: 6),
                                  Text('Demo OTP: 123456', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: aadhaarOtpCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Enter 6-Digit OTP',
                                hintText: '123456',
                                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                isDense: true,
                                filled: true,
                                fillColor: Colors.white,
                                suffixIcon: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: TextButton.icon(
                                    icon: const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                                    label: const Text('Verify', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                    onPressed: aadhaarLoading
                                        ? null
                                        : () async {
                                            setDialogState(() => aadhaarLoading = true);
                                            try {
                                              final res = await widget.api.verifyAadhaarOtp(
                                                aadhaarTxnId ?? 'txn-demo',
                                                aadhaarOtpCtrl.text.trim().isEmpty ? '123456' : aadhaarOtpCtrl.text.trim(),
                                                aadhaarCtrl.text.trim(),
                                              );
                                              setDialogState(() {
                                                aadhaarLoading = false;
                                                aadhaarVerified = true;
                                                if (res['name'] != null && nameCtrl.text.isEmpty) nameCtrl.text = res['name'];
                                                if (res['health_id'] != null) healthIdCtrl.text = res['health_id'];
                                              });
                                              if (dialogCtx.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('✅ Aadhaar e-KYC Verified! Health ID synced.'), backgroundColor: Colors.green),
                                                );
                                              }
                                            } catch (e) {
                                              setDialogState(() => aadhaarLoading = false);
                                              if (dialogCtx.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification failed: $e'), backgroundColor: Colors.red));
                                              }
                                            }
                                          },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 20),
                                const SizedBox(width: 8),
                                Text('Aadhaar: ${aadhaarCtrl.text.trim()} — e-KYC Verified', style: const TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // ══════ SECTION 4: ABHA OTP ══════
                        _buildSectionHeader(
                          Icons.verified_user_rounded,
                          'ABHA ID Verification (OTP)',
                          const Color(0xFF1D4ED8),
                          trailing: abhaVerified
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 14),
                                      SizedBox(width: 4),
                                      Text('VERIFIED', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 11)),
                                    ],
                                  ),
                                )
                              : const Text('Optional', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        ),
                        const SizedBox(height: 12),
                        if (!abhaVerified) ...[
                          TextField(
                            controller: abhaInputCtrl,
                            decoration: InputDecoration(
                              labelText: 'ABHA Number or Address',
                              hintText: 'e.g. 91-1234-5678-9012 or ramesh@abdm',
                              prefixIcon: const Icon(Icons.health_and_safety_outlined, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFEFF6FF),
                              suffixIcon: Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: TextButton(
                                  onPressed: abhaLoading
                                      ? null
                                      : () async {
                                          if (abhaInputCtrl.text.trim().isEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter ABHA Number or Address')));
                                            return;
                                          }
                                          setDialogState(() => abhaLoading = true);
                                          try {
                                            final res = await widget.api.generateAbhaOtp(abhaInputCtrl.text.trim());
                                            setDialogState(() {
                                              abhaLoading = false;
                                              abhaOtpSent = true;
                                              abhaTxnId = res['txn_id'];
                                            });
                                          } catch (e) {
                                            setDialogState(() => abhaLoading = false);
                                            if (dialogCtx.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                                            }
                                          }
                                        },
                                  child: Text(
                                    abhaLoading ? 'Sending...' : (abhaOtpSent ? 'Resend OTP' : 'Send OTP'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (abhaOtpSent) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, size: 14, color: Color(0xFFB45309)),
                                  SizedBox(width: 6),
                                  Text('Demo OTP: 123456', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: abhaOtpCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Enter 6-Digit OTP',
                                hintText: '123456',
                                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                isDense: true,
                                filled: true,
                                fillColor: Colors.white,
                                suffixIcon: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: TextButton.icon(
                                    icon: const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                                    label: const Text('Verify', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                    onPressed: abhaLoading
                                        ? null
                                        : () async {
                                            setDialogState(() => abhaLoading = true);
                                            try {
                                              final res = await widget.api.verifyAbhaOtp(
                                                abhaTxnId ?? 'txn-abdm',
                                                abhaOtpCtrl.text.trim().isEmpty ? '123456' : abhaOtpCtrl.text.trim(),
                                                abhaInputCtrl.text.trim(),
                                              );
                                              setDialogState(() {
                                                abhaLoading = false;
                                                abhaVerified = true;
                                                healthIdCtrl.text = res['health_id'] ?? abhaInputCtrl.text.trim();
                                                if (nameCtrl.text.isEmpty && res['name'] != null) nameCtrl.text = res['name'];
                                              });
                                              if (dialogCtx.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('✅ ABHA ID Verified & Synced!'), backgroundColor: Colors.green),
                                                );
                                              }
                                            } catch (e) {
                                              setDialogState(() => abhaLoading = false);
                                              if (dialogCtx.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ABHA verification failed: $e'), backgroundColor: Colors.red));
                                              }
                                            }
                                          },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 20),
                                const SizedBox(width: 8),
                                Text('ABHA: ${abhaInputCtrl.text.trim()} — Verified & Linked', style: const TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),
                        // Consent Notice
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            children: [
                              Icon(Icons.shield_outlined, size: 16, color: Color(0xFF64748B)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'ABDM Consent & Security: Patient records adhere to Tier-1 consent and facility access protocols.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // ─── FOOTER ACTIONS ───
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      // Verification status summary
                      Expanded(
                        child: Row(
                          children: [
                            if (aadhaarVerified) ...[
                              const Icon(Icons.fingerprint, size: 14, color: Color(0xFF16A34A)),
                              const SizedBox(width: 4),
                              const Text('Aadhaar ✓', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                              const SizedBox(width: 10),
                            ],
                            if (abhaVerified) ...[
                              const Icon(Icons.verified_user, size: 14, color: Color(0xFF16A34A)),
                              const SizedBox(width: 4),
                              const Text('ABHA ✓', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                            ],
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: submitting ? null : () => Navigator.pop(dialogCtx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                        icon: submitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.how_to_reg_rounded, size: 18),
                        label: Text(submitting ? 'Registering...' : 'Register Patient'),
                        onPressed: submitting
                            ? null
                            : () async {
                                if (nameCtrl.text.trim().isEmpty || healthIdCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Full Name and Health ID are required')),
                                  );
                                  return;
                                }
                                setDialogState(() => submitting = true);
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  await widget.api.registerPatient(
                                    ashaId: widget.session.id,
                                    name: nameCtrl.text.trim(),
                                    healthId: healthIdCtrl.text.trim(),
                                    village: villageCtrl.text.trim(),
                                    phone: phoneCtrl.text.trim(),
                                  );
                                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('✅ ${nameCtrl.text.trim()} registered successfully!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  _loadPatients();
                                } catch (e) {
                                  setDialogState(() => submitting = false);
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color, {Widget? trailing}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: RefreshIndicator(
        onRefresh: _loadPatients,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assigned Patients Directory',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Households and patients under your community healthcare surveillance',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _showRegisterDialog,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Register Patient'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                        : _patients.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.people_outline, size: 54, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    const Text('No patients assigned yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    const Text('Click "Register Patient" to add one.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: _patients.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final p = _patients[index];
                                  return Card(
                                    color: Colors.white,
                                    elevation: 1,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () {
                                        PatientFollowUpDashboardDialog.show(
                                          context,
                                          api: widget.api,
                                          session: widget.session,
                                          patient: p,
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: Builder(
                                          builder: (context) {
                                            final isMobile = MediaQuery.of(context).size.width < 700;
                                            final patientInfo = Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                CircleAvatar(
                                                  backgroundColor: const Color(0xFFE0F2FE),
                                                  radius: 22,
                                                  child: Text(
                                                    p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7), fontSize: 16),
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
                                                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: Colors.teal.shade50,
                                                              borderRadius: BorderRadius.circular(6),
                                                              border: Border.all(color: Colors.teal.shade300),
                                                            ),
                                                            child: const Text('Active', style: TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.bold, fontSize: 11)),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'ABHA: ${p.healthId}  •  Village: ${p.village ?? "Assigned Village"}  •  Lang: ${p.preferredLanguage ?? "hi-IN"}',
                                                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          Icon(Icons.touch_app, size: 13, color: Colors.teal.shade700),
                                                          const SizedBox(width: 4),
                                                          Expanded(
                                                            child: Text(
                                                              'Click to view dynamic follow-up dashboard',
                                                              style: TextStyle(fontSize: 11, color: Colors.teal.shade800, fontWeight: FontWeight.w500),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            );

                                            final actionBtn = ElevatedButton.icon(
                                              onPressed: () {
                                                PatientFollowUpDashboardDialog.show(
                                                  context,
                                                  api: widget.api,
                                                  session: widget.session,
                                                  patient: p,
                                                );
                                              },
                                              icon: const Icon(Icons.dashboard_customize_outlined, size: 16),
                                              label: const Text('Follow-up Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF0F766E),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            );

                                            if (isMobile) {
                                              return Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  patientInfo,
                                                  const SizedBox(height: 10),
                                                  SizedBox(width: double.infinity, child: actionBtn),
                                                ],
                                              );
                                            }

                                            return Row(
                                              children: [
                                                Expanded(child: patientInfo),
                                                const SizedBox(width: 10),
                                                actionBtn,
                                              ],
                                            );
                                          },
                                        ),
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
