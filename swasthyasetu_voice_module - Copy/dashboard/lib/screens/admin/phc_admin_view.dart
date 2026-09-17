import 'package:flutter/material.dart';
import '../../models/unified_models.dart';
import '../../services/unified_api_service.dart';

class PHCAdminView extends StatefulWidget {
  final UnifiedApiService api;
  final UnifiedUserSession session;

  const PHCAdminView({super.key, required this.api, required this.session});

  @override
  State<PHCAdminView> createState() => _PHCAdminViewState();
}

class _PHCAdminViewState extends State<PHCAdminView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _facilityStatus;
  PHCQualityDashboard? _qualityDashboard;
  List<PharmacyMedicineItem> _inventory = [];
  final List<dynamic> _queue = [];
  final List<dynamic> _referrals = [];
  final List<dynamic> _followups = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fac = await widget.api.fetchPHCFacilityStatus();
      final qual = await widget.api.fetchPHCQualityDashboard();
      final inv = await widget.api.fetchPharmacyInventory();

      setState(() {
        _facilityStatus = fac;
        _qualityDashboard = qual;
        _inventory = inv;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleDuty(bool val) async {
    try {
      await widget.api.togglePHCAvailability(
        facilityId: 'fac-phc-001',
        isAvailable: val,
        bedsAvailable: _facilityStatus?['facility']?['beds_available'],
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Doctor Duty status updated to: ${val ? "AVAILABLE" : "BUSY / OFF-DUTY"}')),
      );
      _loadAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Column(
        children: [
          // PHC Header banner
          Builder(
            builder: (context) {
              final isMobile = MediaQuery.of(context).size.width < 768;
              if (isMobile) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4338CA).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.local_hospital_rounded, color: Color(0xFF4338CA), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _facilityStatus?['facility']?['name'] ?? 'Shivaji Nagar PHC',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF4338CA)),
                            tooltip: 'Refresh Metrics',
                            onPressed: _loadAllData,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0E7FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PHC ADMINISTRATION',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4338CA)),
                            ),
                          ),
                          Text(
                            'District: ${_facilityStatus?['facility']?['district'] ?? "Pune Rural"} • Beds: ${_facilityStatus?['facility']?['beds_available'] ?? 14} Avail',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              return Container(
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
                        color: const Color(0xFF4338CA).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_hospital_rounded, color: Color(0xFF4338CA), size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _facilityStatus?['facility']?['name'] ?? 'Shivaji Nagar PHC',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0E7FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'PHC ADMINISTRATION',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4338CA)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'District: ${_facilityStatus?['facility']?['district'] ?? "Pune Rural"} • Total Beds: ${_facilityStatus?['facility']?['beds_total'] ?? 20} • Beds Available: ${_facilityStatus?['facility']?['beds_available'] ?? 14}',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFF4338CA)),
                      tooltip: 'Refresh Metrics',
                      onPressed: _loadAllData,
                    ),
                  ],
                ),
              );
            },
          ),

          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: const Color(0xFF4338CA),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF4338CA),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.speed_rounded), text: 'QUALITY DASHBOARD'),
                Tab(icon: Icon(Icons.dashboard_customize_rounded), text: 'OPERATIONS & AVAILABILITY'),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF4338CA)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Failed to load PHC dashboard: $_error', style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadAllData, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildQualityDashboardTab(),
                          _buildOperationsTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // QUALITY DASHBOARD TAB
  // =============================================================
  Widget _buildQualityDashboardTab() {
    final q = _qualityDashboard;
    if (q == null) return const Center(child: Text('No Quality data'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PHC Quality Metrics (Calculated from Live Patient & Care Records)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 16),

          // Top 4 KPI Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildKpiCard(
                    title: 'AVG WAITING TIME',
                    value: '${q.avgWaitingTimeMinutes} min',
                    subtext: 'Check-in to doctor consultation',
                    icon: Icons.timer_outlined,
                    color: const Color(0xFF0284C7),
                    isAlert: q.avgWaitingTimeMinutes > 45,
                    width: isWide ? (constraints.maxWidth - 48) / 3 : constraints.maxWidth,
                  ),
                  _buildKpiCard(
                    title: 'REFERRALS',
                    value: '${q.completedReferrals} Completed',
                    subtext: '${q.pendingReferrals} Pending (${q.referralRatePercent.toStringAsFixed(0)}% Completed)',
                    icon: Icons.alt_route_rounded,
                    color: const Color(0xFF0D9488),
                    width: isWide ? (constraints.maxWidth - 48) / 3 : constraints.maxWidth,
                  ),
                  _buildKpiCard(
                    title: 'FOLLOW-UPS',
                    value: '${q.followupRatePercent.toStringAsFixed(0)}% Completed',
                    subtext: '${q.completedFollowups} of ${q.totalFollowups} due follow-ups done',
                    icon: Icons.event_available_rounded,
                    color: const Color(0xFF16A34A),
                    width: isWide ? (constraints.maxWidth - 48) / 3 : constraints.maxWidth,
                  ),
                  _buildKpiCard(
                    title: 'NO-SHOW RATE',
                    value: '${q.noShowRatePercent.toStringAsFixed(0)}%',
                    subtext: 'OPD appointments missed',
                    icon: Icons.person_off_rounded,
                    color: q.noShowRatePercent > 15 ? Colors.red : const Color(0xFFF59E0B),
                    width: isWide ? (constraints.maxWidth - 48) / 3 : constraints.maxWidth,
                  ),
                  _buildKpiCard(
                    title: 'MEDICINE STOCK',
                    value: '${q.stockoutCount} Stock-out',
                    subtext: '${q.lowStockCount} Low stock • ${q.availableMedCount} Available',
                    icon: Icons.medication_rounded,
                    color: q.stockoutCount > 0 ? Colors.red : const Color(0xFF10B981),
                    isAlert: q.stockoutCount > 0,
                    width: isWide ? (constraints.maxWidth - 48) / 3 : constraints.maxWidth,
                  ),
                  _buildKpiCard(
                    title: 'DIAGNOSTICS',
                    value: '${q.diagAvailable} Available',
                    subtext: '${q.diagUnavailable} Unavailable (Requires referral)',
                    icon: Icons.biotech_rounded,
                    color: const Color(0xFF6366F1),
                    width: isWide ? (constraints.maxWidth - 48) / 3 : constraints.maxWidth,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Stock-out details & Emergency escalations row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;

              final stockoutCard = Container(
                width: isWide ? null : double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Medicine Stock-Out Alert',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${q.stockoutCount} Items Zero Stock',
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (q.stockoutItems.isEmpty)
                      const Text('All essential medicines are currently in stock.', style: TextStyle(color: Colors.green))
                    else
                      ...q.stockoutItems.map(
                        (item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.cancel, color: Colors.red, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(item, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155)))),
                              const SizedBox(width: 8),
                              const Text('Critical PHC Item', style: TextStyle(fontSize: 12, color: Colors.red)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );

              final trendsCard = Container(
                width: isWide ? null : double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.trending_up_rounded, color: Color(0xFF4338CA), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Patient Service Volume & Trends',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTrendRow('Total Triage Cases', q.serviceTrends['cases']),
                    _buildTrendRow('OPD Appointments', q.serviceTrends['appointments']),
                    _buildTrendRow('Prescriptions Generated', q.serviceTrends['prescriptions']),
                    _buildTrendRow('Lab Orders Initiated', q.serviceTrends['lab_orders']),
                    _buildTrendRow('Referrals Escalated', q.serviceTrends['referrals']),
                  ],
                ),
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: stockoutCard),
                    const SizedBox(width: 16),
                    Expanded(child: trendsCard),
                  ],
                );
              }

              return Column(
                children: [
                  stockoutCard,
                  const SizedBox(height: 16),
                  trendsCard,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrendRow(String label, dynamic periodData) {
    int today = 0;
    int week = 0;
    int month = 0;
    if (periodData is Map) {
      today = (periodData['today'] as num?)?.toInt() ?? 0;
      week = (periodData['seven_days'] as num?)?.toInt() ?? 0;
      month = (periodData['thirty_days'] as num?)?.toInt() ?? 0;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
          ),
          Expanded(
            flex: 1,
            child: Text('Today: $today', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          ),
          Expanded(
            flex: 1,
            child: Text('7d: $week', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ),
          Expanded(
            flex: 1,
            child: Text('30d: $month', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    required double width,
    bool isAlert = false,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isAlert ? Colors.red.withValues(alpha: 0.5) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF64748B)),
              ),
              const Spacer(),
              Icon(icon, color: color, size: 22),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: isAlert ? Colors.red : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          Text(
            subtext,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // OPERATIONS & AVAILABILITY TAB
  // =============================================================
  Widget _buildOperationsTab() {
    final bool isDoctorAvailable = _facilityStatus?['doctor_available'] ?? true;
    final int bedsAvail = _facilityStatus?['facility']?['beds_available'] ?? 14;
    final int bedsTotal = _facilityStatus?['facility']?['beds_total'] ?? 20;
    final roster = (_facilityStatus?['duty_roster'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Availability Control Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PHC Duty & Facility Controls',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Active Doctor: Dr. Rajesh Sharma (General Medicine) • Beds: $bedsAvail / $bedsTotal Available',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                // Toggle Button
                Row(
                  children: [
                    Text(
                      isDoctorAvailable ? 'DOCTOR ON DUTY' : 'OFF DUTY',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDoctorAvailable ? const Color(0xFF16A34A) : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: isDoctorAvailable,
                      activeThumbColor: const Color(0xFF16A34A),
                      onChanged: _toggleDuty,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Medicine Availability Table
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.inventory_2_rounded, color: Color(0xFF4338CA)),
                    SizedBox(width: 8),
                    Text(
                      'Medicine Inventory & Availability Status',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Medicine Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Stock Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Min Threshold', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _inventory.map((m) {
                      Color statusColor;
                      String statusText;
                      if (m.status == 'out_of_stock') {
                        statusColor = Colors.red;
                        statusText = 'OUT OF STOCK';
                      } else if (m.status == 'low_stock') {
                        statusColor = Colors.orange;
                        statusText = 'LOW STOCK';
                      } else {
                        statusColor = Colors.green;
                        statusText = 'AVAILABLE';
                      }

                      return DataRow(cells: [
                        DataCell(Text(m.medicineName, style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text('${m.stockQuantity}')),
                        DataCell(Text(m.unit)),
                        DataCell(Text('${m.minThreshold}')),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
