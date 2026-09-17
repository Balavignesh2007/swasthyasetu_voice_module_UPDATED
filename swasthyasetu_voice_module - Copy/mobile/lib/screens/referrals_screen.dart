import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/patient_models.dart';
import '../services/api_service.dart';

const _referralStates = ['Created', 'Accepted', 'In Progress', 'Completed'];

class ReferralsScreen extends StatefulWidget {
  final String patientId;
  const ReferralsScreen({super.key, required this.patientId});

  @override
  State<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends State<ReferralsScreen> {
  final _apiService = ApiService();
  List<PatientReferral> _referrals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _apiService.fetchReferrals(widget.patientId);
      if (!mounted) return;
      setState(() {
        _referrals = data;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load referrals: ${e.message}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach the server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(onRefresh: _load, child: _buildBody());
  }

  Widget _buildBody() {
    if (_loading && _referrals.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _referrals.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(child: Text(_error!, textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          Center(child: OutlinedButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }
    if (_referrals.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Center(child: Text('No referrals on record.')),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _referrals.length,
      itemBuilder: (context, index) => _ReferralCard(referral: _referrals[index]),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  final PatientReferral referral;
  const _ReferralCard({required this.referral});

  @override
  Widget build(BuildContext context) {
    final currentIndex = _referralStates.indexOf(referral.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              referral.reason ?? 'Referral',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d, yyyy').format(referral.createdAt.toLocal()),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 14),
            Row(
              children: List.generate(_referralStates.length * 2 - 1, (i) {
                if (i.isOdd) {
                  final passed = (i ~/ 2) < currentIndex;
                  return Expanded(
                    child: Container(height: 2, color: passed ? Colors.green : Colors.grey[300]),
                  );
                }
                final stepIndex = i ~/ 2;
                final reached = stepIndex <= currentIndex;
                return CircleAvatar(
                  radius: 10,
                  backgroundColor: reached ? Colors.green : Colors.grey[300],
                  child: reached ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                );
              }),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _referralStates
                  .map((s) => Text(s, style: const TextStyle(fontSize: 10, color: Colors.black54)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
