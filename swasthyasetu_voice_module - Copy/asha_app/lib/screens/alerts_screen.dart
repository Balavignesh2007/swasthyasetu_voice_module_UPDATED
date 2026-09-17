import 'dart:async';
import 'package:flutter/material.dart';

import '../config.dart';
import '../models/emergency_alert.dart';
import '../services/api_service.dart';
import '../widgets/alert_card.dart';
import 'alert_detail_screen.dart';

class AlertsScreen extends StatefulWidget {
  final String ashaId;
  const AlertsScreen({super.key, required this.ashaId});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _apiService = ApiService();
  List<EmergencyAlert> _alerts = [];
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  bool _showResolvedToo = false;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    _pollTimer = Timer.periodic(AppConfig.alertsPollInterval, (_) => _loadAlerts(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _loadAlerts({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final alerts = await _apiService.fetchAlerts(ashaId: widget.ashaId);
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load alerts: ${e.message}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach the server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<EmergencyAlert> get _visibleAlerts {
    final list = _showResolvedToo ? _alerts : _alerts.where((a) => a.isOpen).toList();
    // Unacknowledged first, then by recency.
    list.sort((a, b) {
      if (a.status == AlertStatus.unacknowledged && b.status != AlertStatus.unacknowledged) return -1;
      if (b.status == AlertStatus.unacknowledged && a.status != AlertStatus.unacknowledged) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final unacknowledgedCount = _alerts.where((a) => a.status == AlertStatus.unacknowledged).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Emergency Alerts'),
            if (unacknowledgedCount > 0) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 11,
                backgroundColor: Colors.red,
                child: Text('$unacknowledgedCount', style: const TextStyle(fontSize: 12, color: Colors.white)),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showResolvedToo ? Icons.visibility_off : Icons.visibility),
            tooltip: _showResolvedToo ? 'Hide resolved' : 'Show resolved',
            onPressed: () => setState(() => _showResolvedToo = !_showResolvedToo),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAlerts,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _alerts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _alerts.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.wifi_off, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Center(child: Text(_error!, textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          Center(child: OutlinedButton(onPressed: _loadAlerts, child: const Text('Retry'))),
        ],
      );
    }
    final visible = _visibleAlerts;
    if (visible.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.check_circle_outline, size: 56, color: Colors.green[400]),
          const SizedBox(height: 12),
          const Center(child: Text('No active emergency alerts.', style: TextStyle(fontSize: 16))),
        ],
      );
    }
    return ListView.builder(
      itemCount: visible.length,
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemBuilder: (context, index) {
        final alert = visible[index];
        return AlertCard(
          alert: alert,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AlertDetailScreen(alert: alert, ashaId: widget.ashaId)),
            );
            _loadAlerts(silent: true);
          },
        );
      },
    );
  }
}
