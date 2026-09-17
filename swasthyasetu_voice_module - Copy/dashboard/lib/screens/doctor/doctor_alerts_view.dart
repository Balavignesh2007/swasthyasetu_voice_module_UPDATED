import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../models/unified_models.dart';
import '../../services/unified_api_service.dart';

class DoctorAlertsView extends StatefulWidget {
  final UnifiedApiService api;

  const DoctorAlertsView({super.key, required this.api});

  @override
  State<DoctorAlertsView> createState() => _DoctorAlertsViewState();
}

class _DoctorAlertsViewState extends State<DoctorAlertsView> with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  List<DoctorEmergencyEvent> _alerts = [];
  String _filter = 'ALL';
  Timer? _refreshTimer;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  bool _isWsConnected = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadAlerts();
    _connectAlertsWebSocket();

    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _pollAlertsSilently();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _connectAlertsWebSocket() {
    try {
      final wsUri = widget.api.getAlertsWebSocketUri();
      _wsChannel = WebSocketChannel.connect(wsUri);
      _wsSubscription = _wsChannel!.stream.listen(
        (message) {
          if (!mounted) return;
          setState(() {
            _isWsConnected = true;
          });
          try {
            final data = jsonDecode(message.toString());
            if (data is Map && data['type'] == 'EMERGENCY_ALERT' && data['alert'] != null) {
              final alertMap = Map<String, dynamic>.from(data['alert'] as Map);
              final incomingAlert = DoctorEmergencyEvent.fromJson(alertMap);
              setState(() {
                final idx = _alerts.indexWhere((a) => a.id == incomingAlert.id);
                if (idx >= 0) {
                  _alerts[idx] = incomingAlert;
                } else {
                  _alerts.insert(0, incomingAlert);
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.warning_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '🚨 HIGH RISK ESCALATION: ${incomingAlert.patientName ?? 'Patient'} - ${incomingAlert.redFlagType}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFFDC2626),
                  duration: const Duration(seconds: 4),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (_) {}
        },
        onError: (_) {
          if (mounted) setState(() => _isWsConnected = false);
        },
        onDone: () {
          if (mounted) setState(() => _isWsConnected = false);
        },
      );
    } catch (_) {
      _isWsConnected = false;
    }
  }

  Future<void> _pollAlertsSilently() async {
    try {
      final list = await widget.api.fetchDoctorAlerts();
      if (mounted) {
        setState(() {
          _alerts = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.api.fetchDoctorAlerts();
      if (mounted) {
        setState(() {
          _alerts = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load alerts: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _acknowledge(String alertId) async {
    try {
      await widget.api.acknowledgeDoctorAlert(alertId);
      setState(() {
        final idx = _alerts.indexWhere((a) => a.id == alertId);
        if (idx >= 0) {
          final old = _alerts[idx];
          _alerts[idx] = DoctorEmergencyEvent(
            id: old.id,
            patientId: old.patientId,
            patientName: old.patientName,
            patientPhone: old.patientPhone,
            patientVillage: old.patientVillage,
            symptoms: old.symptoms,
            riskScore: old.riskScore,
            redFlagType: old.redFlagType,
            severity: old.severity,
            status: 'ACKNOWLEDGED',
            assignedAshaId: old.assignedAshaId,
            createdAt: old.createdAt,
          );
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alert acknowledged and marked as under review.'),
            backgroundColor: Color(0xFF0F766E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to acknowledge: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<DoctorEmergencyEvent> get _filteredAlerts {
    if (_filter == 'UNACKNOWLEDGED') {
      return _alerts.where((a) => a.status.toUpperCase() == 'UNACKNOWLEDGED').toList();
    }
    if (_filter == 'ACKNOWLEDGED') {
      return _alerts.where((a) => a.status.toUpperCase() != 'UNACKNOWLEDGED').toList();
    }
    return _alerts;
  }

  @override
  Widget build(BuildContext context) {
    final unackCount = _alerts.where((a) => a.status.toUpperCase() == 'UNACKNOWLEDGED').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: RefreshIndicator(
        onRefresh: _loadAlerts,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(unackCount),
              const SizedBox(height: 14),
              _buildLiveStatusBar(unackCount),
              const SizedBox(height: 14),
              _buildFilterChips(unackCount),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                        : _filteredAlerts.isEmpty
                            ? _buildEmptyState()
                            : _buildAlertsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int unackCount) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    isMobile ? 'High-Risk Alerts' : 'Emergency High-Risk Alerts',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  if (unackCount > 0) ...[
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '$unackCount ACTION NEEDED',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Live monitoring of high-risk escalated patients',
                style: TextStyle(fontSize: isMobile ? 11 : 13, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (isMobile)
          IconButton.filledTonal(
            onPressed: _loadAlerts,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, size: 20),
          )
        else
          ElevatedButton.icon(
            onPressed: _loadAlerts,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
      ],
    );
  }

  Widget _buildLiveStatusBar(int unackCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: unackCount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: unackCount > 0 ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            unackCount > 0 ? Icons.crisis_alert_rounded : Icons.verified_user_rounded,
            color: unackCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              unackCount > 0
                  ? '⚠️ $unackCount high-risk patient(s) currently require immediate clinical attention and triage review.'
                  : 'All critical triage alerts have been acknowledged and reviewed.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: unackCount > 0 ? const Color(0xFF991B1B) : const Color(0xFF065F46),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _isWsConnected ? Colors.green.shade100 : Colors.amber.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isWsConnected ? Colors.green.shade700 : Colors.amber.shade700,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _isWsConnected ? 'LIVE RADAR' : 'SYNCING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _isWsConnected ? Colors.green.shade900 : Colors.amber.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(int unackCount) {
    final filters = [
      {'key': 'ALL', 'label': 'All Alerts (${_alerts.length})'},
      {'key': 'UNACKNOWLEDGED', 'label': '🚨 Urgent Unreviewed ($unackCount)'},
      {'key': 'ACKNOWLEDGED', 'label': 'Reviewed (${_alerts.length - unackCount})'},
    ];

    return Row(
      children: filters.map((f) {
        final isSelected = _filter == f['key'];
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: ChoiceChip(
            label: Text(f['label']!),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) setState(() => _filter = f['key']!);
            },
            selectedColor: const Color(0xFFDC2626),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 54, color: Colors.green.shade400),
          const SizedBox(height: 12),
          const Text(
            'No Active Emergency Alerts',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'All red flag cases have been addressed and cleared.',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsList() {
    return ListView.separated(
      itemCount: _filteredAlerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final alert = _filteredAlerts[index];
        return _buildAlertCard(alert);
      },
    );
  }

  Widget _buildAlertCard(DoctorEmergencyEvent alert) {
    final isUnack = alert.status.toUpperCase() == 'UNACKNOWLEDGED';
    final patientDisplayName = (alert.patientName != null && alert.patientName!.isNotEmpty)
        ? alert.patientName!
        : 'High-Risk Patient (ID: ${alert.patientId ?? 'N/A'})';

    return Card(
      color: Colors.white,
      elevation: isUnack ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUnack ? const Color(0xFFEF4444) : Colors.grey.shade200,
          width: isUnack ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isUnack ? const Color(0xFFDC2626) : const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isUnack ? Icons.emergency_rounded : Icons.check_circle_rounded,
                  color: isUnack ? Colors.white : Colors.green.shade700,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isUnack ? '🚨 HIGH RISK ALERT ESCALATION' : 'ACKNOWLEDGED EMERGENCY CASE',
                  style: TextStyle(
                    color: isUnack ? Colors.white : const Color(0xFF334155),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isUnack ? Colors.white.withValues(alpha: 0.2) : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    alert.severity.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isUnack ? Colors.white : Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: isUnack ? const Color(0xFFFEE2E2) : const Color(0xFFE2E8F0),
                      child: Icon(
                        Icons.person_rounded,
                        size: 32,
                        color: isUnack ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                patientDisplayName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isUnack)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: const Text(
                                    '⚠️ CRITICAL',
                                    style: TextStyle(
                                      color: Color(0xFFB91C1C),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              if (alert.patientVillage != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 3),
                                    Text(alert.patientVillage!, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                  ],
                                ),
                              if (alert.patientPhone != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.phone_outlined, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 3),
                                    Text(alert.patientPhone!, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                  ],
                                ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 3),
                                  Text(
                                    DateFormat('dd MMM yyyy, hh:mm a').format(alert.createdAt.toLocal()),
                                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUnack ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isUnack ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_rounded,
                            size: 16,
                            color: isUnack ? const Color(0xFFBE123C) : const Color(0xFF475569),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Red Flag Condition: ${alert.redFlagType}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isUnack ? const Color(0xFF9F1239) : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      if (alert.symptoms != null && alert.symptoms!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '"${alert.symptoms!}"',
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: isUnack ? const Color(0xFF881337) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Status: ${alert.status}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isUnack ? const Color(0xFFDC2626) : Colors.green.shade700,
                      ),
                    ),
                    if (isUnack)
                      ElevatedButton.icon(
                        onPressed: () => _acknowledge(alert.id),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Acknowledge Alert'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.verified, color: Colors.green.shade700, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Reviewed by Medical Officer',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
