import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../models/unified_models.dart';
import '../../services/unified_api_service.dart';

class AshaAlertsView extends StatefulWidget {
  final UnifiedApiService api;
  final UnifiedUserSession session;

  const AshaAlertsView({super.key, required this.api, required this.session});

  @override
  State<AshaAlertsView> createState() => _AshaAlertsViewState();
}

class _AshaAlertsViewState extends State<AshaAlertsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _error;
  List<AshaEmergencyAlert> _alerts = [];
  List<AshaFollowUp> _followUps = [];
  Timer? _refreshTimer;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  bool _isWsConnected = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _connectAlertsWebSocket();
    // Fallback periodic poll
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _pollData();
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _refreshTimer?.cancel();
    _tabController.dispose();
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
              final incomingAlert = AshaEmergencyAlert.fromJson(alertMap);
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
                      const Icon(Icons.emergency_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '🚨 LIVE EMERGENCY CALL ALERT',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '${incomingAlert.redFlagType} - ${incomingAlert.patientId ?? "Caller"}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.red.shade800,
                  duration: const Duration(seconds: 8),
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'VIEW',
                    textColor: Colors.amberAccent,
                    onPressed: () {
                      _tabController.animateTo(0);
                    },
                  ),
                ),
              );
            }
          } catch (_) {}
        },
        onError: (err) {
          if (!mounted) return;
          setState(() {
            _isWsConnected = false;
          });
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) _connectAlertsWebSocket();
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _isWsConnected = false;
          });
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) _connectAlertsWebSocket();
          });
        },
      );
    } catch (_) {}
  }

  Future<void> _pollData() async {
    try {
      final results = await Future.wait([
        widget.api.fetchAshaAlerts(ashaId: widget.session.id),
        widget.api.fetchAshaFollowUps(widget.session.id).catchError((_) => <AshaFollowUp>[]),
      ]);
      if (mounted) {
        setState(() {
          _alerts = results[0] as List<AshaEmergencyAlert>;
          _followUps = results[1] as List<AshaFollowUp>;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.fetchAshaAlerts(ashaId: widget.session.id),
        widget.api.fetchAshaFollowUps(widget.session.id).catchError((_) => <AshaFollowUp>[]),
      ]);
      if (mounted) {
        setState(() {
          _alerts = results[0] as List<AshaEmergencyAlert>;
          _followUps = results[1] as List<AshaFollowUp>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load data: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _ackAlert(String alertId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.api.ackAshaAlert(alertId, notes: 'Acknowledged via ASHA Web Portal');
      messenger.showSnackBar(
        const SnackBar(content: Text('Alert acknowledged!'), backgroundColor: Colors.green),
      );
      _loadData();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to ack alert: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Builder(
            builder: (context) {
              final isMobile = MediaQuery.of(context).size.width < 768;
              final titleCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Emergency Alerts & Home Visits',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Village red flags and pending maternal/child health follow-ups',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              );

              final statusRow = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _isWsConnected ? Colors.green.shade50 : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isWsConnected ? Colors.green.shade400 : Colors.amber.shade400,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isWsConnected ? Colors.green.shade600 : Colors.amber.shade700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isWsConnected ? 'LIVE CALL STREAM' : 'CONNECTING...',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isWsConnected ? Colors.green.shade800 : Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
                ],
              );

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleCol,
                    const SizedBox(height: 10),
                    statusRow,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: titleCol),
                  statusRow,
                ],
              );
            },
          ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0F766E),
              indicatorColor: const Color(0xFF0F766E),
              tabs: [
                Tab(text: 'Village Alerts (${_alerts.length})'),
                Tab(text: 'Follow-ups (${_followUps.length})'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildAlertsList(),
                            _buildFollowUpsList(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsList() {
    if (_alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 54, color: Colors.green.shade400),
            const SizedBox(height: 12),
            const Text('No Active Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _alerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final a = _alerts[index];
        final isUnack = a.status.toUpperCase() == 'UNACKNOWLEDGED';
        final pName = a.patientName ?? 'Emergency Caller';
        final pPhone = a.patientPhone ?? '+919121458655';
        final pVillage = a.patientVillage ?? 'Central Village';
        final pSymptoms = a.symptoms ?? a.redFlagType;
        final riskScore = a.riskScore ?? 90;

        return Card(
          color: Colors.white,
          elevation: isUnack ? 3 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isUnack ? Colors.red.shade400 : Colors.grey.shade300,
              width: isUnack ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Badges & Timestamp Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isUnack ? Colors.red.shade700 : Colors.green.shade700,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isUnack ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isUnack ? '🚨 CRITICAL ALERT' : 'ACKNOWLEDGED',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Text(
                            'RISK SCORE: $riskScore / 100',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(a.createdAt.toLocal()),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Red Flag Header
                Text(
                  a.redFlagType,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isUnack ? Colors.red.shade900 : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),

                // 3. Patient Information Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_pin, color: Color(0xFF0F766E), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        pName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 14),
                      const Icon(Icons.location_on_outlined, color: Colors.grey, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        pVillage,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const SizedBox(width: 14),
                      const Icon(Icons.phone_outlined, color: Colors.blueGrey, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        pPhone,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 4. Symptoms Container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isUnack ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isUnack ? Colors.red.shade100 : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.medical_services_outlined, size: 16, color: isUnack ? Colors.red.shade700 : Colors.blueGrey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                            children: [
                              const TextSpan(text: 'Reported Symptoms: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: '"$pSymptoms"'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Action Buttons (ASHA CONTACTS PATIENT & ACKNOWLEDGE)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: pPhone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('📞 Patient contact copied: $pPhone. Directing call...'),
                            backgroundColor: const Color(0xFF0F766E),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      },
                      icon: const Icon(Icons.phone, size: 16, color: Color(0xFF0F766E)),
                      label: Text(
                        'CONTACT PATIENT ($pPhone)',
                        style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF0F766E)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (isUnack)
                      ElevatedButton.icon(
                        onPressed: () => _ackAlert(a.id),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('ACKNOWLEDGE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFollowUpsList() {
    if (_followUps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No Pending Follow-ups', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _followUps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final f = _followUps[index];
        return Card(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: const Icon(Icons.home_outlined, color: Color(0xFF0F766E), size: 28),
            title: Text(f.followUpType, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Due Date: ${DateFormat('dd MMM yyyy').format(f.dueDate.toLocal())} • Status: ${f.status}'),
            trailing: Chip(
              label: Text(f.status.toUpperCase(), style: const TextStyle(fontSize: 11)),
              backgroundColor: const Color(0xFFF1F5F9),
            ),
          ),
        );
      },
    );
  }
}
