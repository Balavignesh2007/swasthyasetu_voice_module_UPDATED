import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/unified_models.dart';
import '../../services/unified_api_service.dart';

class PatientReferralsView extends StatefulWidget {
  final UnifiedApiService api;
  final UnifiedUserSession session;

  const PatientReferralsView({super.key, required this.api, required this.session});

  @override
  State<PatientReferralsView> createState() => _PatientReferralsViewState();
}

class _PatientReferralsViewState extends State<PatientReferralsView> {
  bool _loading = true;
  String? _error;
  List<PatientReferral> _referrals = [];

  @override
  void initState() {
    super.initState();
    _loadReferrals();
  }

  Future<void> _loadReferrals() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.api.fetchPatientReferrals(widget.session.id);
      if (mounted) {
        setState(() {
          _referrals = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load referrals: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: RefreshIndicator(
        onRefresh: _loadReferrals,
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
                        'Hospital Referrals & Secondary Care',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Specialist facilities recommended by doctor for advanced treatment',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReferrals),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                        : _referrals.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.local_hospital_outlined, size: 54, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    const Text('No Active Referrals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    const Text('If a doctor refers you to a district hospital, it appears here.', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: _referrals.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final r = _referrals[index];
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
                                              const Icon(Icons.local_hospital, color: Color(0xFF4338CA), size: 24),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Hospital Referral (ID: ${r.id.substring(0, 8)})',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                              const Spacer(),
                                              Chip(
                                                label: Text(r.status.toUpperCase(), style: const TextStyle(fontSize: 11)),
                                                backgroundColor: const Color(0xFFEEF2FF),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          if (r.reason != null && r.reason!.isNotEmpty)
                                            Text('Reason: ${r.reason}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Created on ${DateFormat('dd MMM yyyy').format(r.createdAt.toLocal())}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                          ),
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
