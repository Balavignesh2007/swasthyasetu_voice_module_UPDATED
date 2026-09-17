import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/emergency_alert.dart';
import '../services/api_service.dart';
import '../widgets/status_badge.dart';

class AlertDetailScreen extends StatefulWidget {
  final EmergencyAlert alert;
  final String ashaId;

  const AlertDetailScreen({super.key, required this.alert, required this.ashaId});

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  final _apiService = ApiService();
  late EmergencyAlert _alert;
  bool _updating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _alert = widget.alert;
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _performAction(
    Future<EmergencyAlert> Function(String alertId, String ashaId) action,
    String confirmMessage,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm action'),
        content: Text(confirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _updating = true;
      _error = null;
    });
    try {
      final updated = await action(_alert.id, widget.ashaId);
      if (!mounted) return;
      setState(() => _alert = updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Update failed: ${e.message}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach the server. Try again.');
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = DateFormat('EEEE, MMM d — h:mm a').format(_alert.createdAt.toLocal());

    return Scaffold(
      appBar: AppBar(title: const Text('Alert Details')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _alert.redFlagType,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  StatusBadge(status: _alert.status),
                ],
              ),
              const SizedBox(height: 16),
              _infoRow('Patient ID', _alert.patientId ?? 'Unverified caller'),
              _infoRow('Severity', _alert.severity),
              _infoRow('Call time', timeLabel),
              if (_alert.acknowledgedAt != null)
                _infoRow('Acknowledged at', DateFormat('h:mm a').format(_alert.acknowledgedAt!.toLocal())),
              if (_alert.resolvedAt != null)
                _infoRow('Resolved at', DateFormat('h:mm a').format(_alert.resolvedAt!.toLocal())),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Action: Please contact/assist the patient immediately.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              if (_updating) const Center(child: CircularProgressIndicator()),
              if (!_updating) Expanded(child: _buildActionButtons()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label, style: TextStyle(color: Colors.grey[600]))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    // Present only the actions that make sense from the current status,
    // mirroring the ASHA alert status flow from the backend spec:
    // UNACKNOWLEDGED -> ACKNOWLEDGED -> CONTACTING -> REACHED -> RESOLVED
    // with ESCALATED / UNABLE_TO_REACH as side branches.
    final buttons = <Widget>[];

    if (_alert.status == AlertStatus.unacknowledged) {
      buttons.add(_actionButton(
        'Acknowledge Alert', Icons.check, Colors.orange,
        () => _performAction(_apiService.acknowledgeAlert, 'Acknowledge this emergency alert?'),
      ));
    }
    if (_alert.status == AlertStatus.acknowledged) {
      buttons.add(_actionButton(
        'Mark Contacting Patient', Icons.phone_forwarded, Colors.amber[800]!,
        () => _performAction(_apiService.markContacting, 'Mark that you are contacting the patient?'),
      ));
    }
    if (_alert.status == AlertStatus.contacting) {
      buttons.add(_actionButton(
        'Mark Reached', Icons.person_pin_circle, Colors.green,
        () => _performAction(_apiService.markReached, 'Confirm you have reached the patient?'),
      ));
      buttons.add(_actionButton(
        'Unable to Reach', Icons.phone_missed, Colors.grey[700]!,
        () => _performAction(_apiService.markUnableToReach, 'Mark that you were unable to reach the patient?'),
      ));
    }
    if (_alert.isOpen && _alert.status != AlertStatus.escalated) {
      buttons.add(_actionButton(
        'Escalate', Icons.priority_high, Colors.purple,
        () => _performAction(_apiService.escalateAlert, 'Escalate this case for further support?'),
      ));
    }
    if (_alert.isOpen) {
      buttons.add(_actionButton(
        'Mark Resolved', Icons.done_all, Colors.blue,
        () => _performAction(_apiService.resolveAlert, 'Mark this emergency as resolved?'),
      ));
    }
    if (buttons.isEmpty) {
      return const Center(child: Text('This alert has been resolved.'));
    }

    return ListView.separated(
      itemCount: buttons.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => buttons[index],
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: color),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
