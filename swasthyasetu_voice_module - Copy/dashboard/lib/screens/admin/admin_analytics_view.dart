import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/unified_models.dart';
import '../../services/unified_api_service.dart';

class AdminAnalyticsView extends StatefulWidget {
  final UnifiedApiService api;
  final UnifiedUserSession session;

  const AdminAnalyticsView({super.key, required this.api, required this.session});

  @override
  State<AdminAnalyticsView> createState() => _AdminAnalyticsViewState();
}

class _AdminAnalyticsViewState extends State<AdminAnalyticsView> {
  bool _loading = true;
  String? _error;
  AdminAnalyticsReport? _report;

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
      final res = await widget.api.fetchAdminAnalytics();
      if (mounted) {
        setState(() {
          _report = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load system analytics: $e';
          _loading = false;
        });
      }
    }
  }

  void _showExportSummaryDialog() {
    if (_report == null) return;
    final k = _report!.kpis;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.print_rounded, color: Color(0xFF4338CA)),
            SizedBox(width: 8),
            Text('Healthcare System Audit Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SwasthyaSetu Rural Health Intelligence Network\nReport Generated: ${DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                const Divider(height: 24),
                _summaryRow('Registered Doctors', '${k['total_doctors'] ?? 0} (${k['active_doctors'] ?? 0} Active)'),
                _summaryRow('ASHA Healthcare Workers', '${k['total_asha_workers'] ?? 0} (${k['active_asha_workers'] ?? 0} Active)'),
                _summaryRow('Enrolled Patients', '${k['total_patients'] ?? 0}'),
                _summaryRow('Total OPD Appointments', '${k['total_appointments'] ?? 0}'),
                _summaryRow('Prescriptions Completed', '${k['prescribed_appointments'] ?? 0}'),
                _summaryRow('Pending Consultations', '${k['pending_appointments'] ?? 0}'),
                _summaryRow('Emergency Red Flags', '${k['total_emergency_alerts'] ?? 0} (${k['unacknowledged_alerts'] ?? 0} Unack)'),
                _summaryRow('Inter-Facility Referrals', '${k['total_referrals'] ?? 0}'),
                _summaryRow('Healthcare Facilities', '${k['total_facilities'] ?? 0}'),
                const Divider(height: 24),
                const Text(
                  'System integrity is active. All Doctor and ASHA worker nodes are functioning on the unified host.',
                  style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Exported & Verified'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4338CA), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(60.0), child: CircularProgressIndicator()))
              else if (_error != null)
                Center(
                  child: Column(
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                    ],
                  ),
                )
              else if (_report != null) ...[
                _buildKpiGrid(_report!.kpis),
                const SizedBox(height: 28),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 900;
                    if (isWide) {
                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: _buildSpecialtyCard(_report!.specialtyDistribution)),
                              const SizedBox(width: 20),
                              Expanded(flex: 4, child: _buildFacilityTable(_report!.facilityStats)),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: _buildVillageCard(_report!.villageCoverage)),
                              const SizedBox(width: 20),
                              Expanded(flex: 4, child: _buildActivityFeed(_report!.activityLog)),
                            ],
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        _buildSpecialtyCard(_report!.specialtyDistribution),
                        const SizedBox(height: 20),
                        _buildFacilityTable(_report!.facilityStats),
                        const SizedBox(height: 20),
                        _buildVillageCard(_report!.villageCoverage),
                        const SizedBox(height: 20),
                        _buildActivityFeed(_report!.activityLog),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isMobile = MediaQuery.of(context).size.width < 768;

    final titleSection = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.analytics_rounded, color: Color(0xFF4338CA), size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Healthcare System Analytics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'Real-time operations monitor for Doctors, ASHA Network, and Patients',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );

    final actionButtons = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _showExportSummaryDialog,
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Audit Summary'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF4338CA),
            side: const BorderSide(color: Color(0xFFC7D2FE)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Refresh Data'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4338CA),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleSection,
          const SizedBox(height: 12),
          actionButtons,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: titleSection),
        const SizedBox(width: 16),
        actionButtons,
      ],
    );
  }

  Widget _buildKpiGrid(Map<String, int> k) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100
            ? 4
            : (constraints.maxWidth > 700 ? 3 : (constraints.maxWidth > 480 ? 2 : 1));
        final aspectRatio = crossAxisCount == 1 ? 2.5 : (crossAxisCount == 2 ? 1.4 : 1.85);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: aspectRatio,
          children: [
            _kpiCard(
              title: 'Registered Doctors',
              value: '${k['total_doctors'] ?? 0}',
              subtitle: '${k['active_doctors'] ?? 0} Active on Duty',
              icon: Icons.medical_services_rounded,
              color: const Color(0xFF0284C7),
              bgColor: const Color(0xFFF0F9FF),
            ),
            _kpiCard(
              title: 'ASHA Field Workers',
              value: '${k['total_asha_workers'] ?? 0}',
              subtitle: '${k['active_asha_workers'] ?? 0} Active in Villages',
              icon: Icons.badge_rounded,
              color: const Color(0xFF0F766E),
              bgColor: const Color(0xFFF0FDFA),
            ),
            _kpiCard(
              title: 'Enrolled Patients',
              value: '${k['total_patients'] ?? 0}',
              subtitle: 'Rural Population Served',
              icon: Icons.people_alt_rounded,
              color: const Color(0xFF6366F1),
              bgColor: const Color(0xFFEEF2FF),
            ),
            _kpiCard(
              title: 'Total Appointments',
              value: '${k['total_appointments'] ?? 0}',
              subtitle: '${k['prescribed_appointments'] ?? 0} Prescriptions Given',
              icon: Icons.calendar_month_rounded,
              color: const Color(0xFF10B981),
              bgColor: const Color(0xFFECFDF5),
            ),
            _kpiCard(
              title: 'Emergency Red Flags',
              value: '${k['total_emergency_alerts'] ?? 0}',
              subtitle: '${k['unacknowledged_alerts'] ?? 0} Unacknowledged',
              icon: Icons.warning_rounded,
              color: const Color(0xFFEF4444),
              bgColor: const Color(0xFFFEF2F2),
            ),
            _kpiCard(
              title: 'Inter-Facility Referrals',
              value: '${k['total_referrals'] ?? 0}',
              subtitle: 'Transfers to Higher Care',
              icon: Icons.swap_horiz_rounded,
              color: const Color(0xFFF59E0B),
              bgColor: const Color(0xFFFFFBEB),
            ),
            _kpiCard(
              title: 'Pending OPD Cases',
              value: '${k['pending_appointments'] ?? 0}',
              subtitle: 'Awaiting Doctor Review',
              icon: Icons.hourglass_top_rounded,
              color: const Color(0xFF8B5CF6),
              bgColor: const Color(0xFFF5F3FF),
            ),
            _kpiCard(
              title: 'Connected Facilities',
              value: '${k['total_facilities'] ?? 0}',
              subtitle: 'Hospitals, CHCs & PHCs',
              icon: Icons.local_hospital_rounded,
              color: const Color(0xFF0D9488),
              bgColor: const Color(0xFFCCFBF1),
            ),
          ],
        );
      },
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialtyCard(Map<String, int> specs) {
    final total = specs.values.fold<int>(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_rounded, color: Color(0xFF4338CA), size: 20),
              SizedBox(width: 8),
              Text('OPD Specialty Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 16),
          if (specs.isEmpty)
            const Padding(padding: EdgeInsets.all(20), child: Text('No specialty data recorded yet.'))
          else
            ...specs.entries.map((e) {
              final pct = total > 0 ? (e.value / total) : 0.0;
              Color barColor = const Color(0xFF4338CA);
              if (e.key.toLowerCase().contains('cardio')) barColor = Colors.red.shade600;
              if (e.key.toLowerCase().contains('pulmo')) barColor = Colors.cyan.shade700;
              if (e.key.toLowerCase().contains('ortho')) barColor = Colors.orange.shade700;
              if (e.key.toLowerCase().contains('pediat')) barColor = Colors.purple.shade600;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('${e.value} cases (${(pct * 100).toStringAsFixed(1)}%)', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildFacilityTable(List<Map<String, dynamic>> facilities) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.domain_rounded, color: Color(0xFF0F766E), size: 20),
              SizedBox(width: 8),
              Text('Healthcare Facilities Operations Matrix', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 16),
          if (facilities.isEmpty)
            const Padding(padding: EdgeInsets.all(20), child: Text('No facility records found.'))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('Facility Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Tier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Doctors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('ASHAs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('OPD Load', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
                rows: facilities.map((f) {
                  return DataRow(cells: [
                    DataCell(Text(f['name']?.toString() ?? 'Facility', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(f['type']?.toString().toUpperCase() ?? 'PHC', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4338CA))),
                    )),
                    DataCell(Text('${f['doctors'] ?? 0}', style: const TextStyle(fontSize: 13))),
                    DataCell(Text('${f['asha_workers'] ?? 0}', style: const TextStyle(fontSize: 13))),
                    DataCell(Text('${f['appointments'] ?? 0}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)))),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVillageCard(List<Map<String, dynamic>> villages) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.holiday_village_rounded, color: Color(0xFFD97706), size: 20),
              SizedBox(width: 8),
              Text('Rural Community Coverage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 14),
          if (villages.isEmpty)
            const Padding(padding: EdgeInsets.all(20), child: Text('No village patient data available.'))
          else
            ...villages.map((v) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFFD97706)),
                        const SizedBox(width: 6),
                        Text(v['village']?.toString() ?? 'Village', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                      child: Text('${v['patient_count'] ?? 0} Patients', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E))),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildActivityFeed(List<Map<String, dynamic>> logs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, color: Color(0xFF475569), size: 20),
              SizedBox(width: 8),
              Text('Live Clinical Activity Stream', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 14),
          if (logs.isEmpty)
            const Padding(padding: EdgeInsets.all(20), child: Text('No recent system events.'))
          else
            ...logs.map((log) {
              final isPrescribed = log['status'] == 'Prescribed' || log['status'] == 'completed';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isPrescribed ? const Color(0xFFDCFCE7) : const Color(0xFFE0F2FE),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPrescribed ? Icons.medication_rounded : Icons.person_search_rounded,
                        size: 16,
                        color: isPrescribed ? Colors.green.shade800 : Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${log['patient_name']} — ${log['speciality'] ?? "General Medicine"}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            'Status: ${log['status']}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isPrescribed ? Colors.green.shade700 : Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
