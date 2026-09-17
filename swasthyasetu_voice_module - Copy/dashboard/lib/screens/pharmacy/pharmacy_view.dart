import 'package:flutter/material.dart';
import '../../models/unified_models.dart';
import '../../services/unified_api_service.dart';

class PharmacyView extends StatefulWidget {
  final UnifiedApiService api;
  final UnifiedUserSession session;

  const PharmacyView({super.key, required this.api, required this.session});

  @override
  State<PharmacyView> createState() => _PharmacyViewState();
}

class _PharmacyViewState extends State<PharmacyView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _error;
  List<PharmacyPrescriptionOrder> _orders = [];
  List<PharmacyMedicineItem> _inventory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await widget.api.fetchPharmacyOrders();
      final inv = await widget.api.fetchPharmacyInventory();
      setState(() {
        _orders = orders;
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

  Future<void> _dispense(PharmacyPrescriptionOrder order) async {
    try {
      await widget.api.dispensePharmacyOrder(order.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prescription for ${order.patientName} successfully dispensed! Inventory updated.'),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dispense failed: $e')));
    }
  }

  Future<void> _updateStockDialog(PharmacyMedicineItem item) async {
    final controller = TextEditingController(text: '${item.stockQuantity}');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update Stock: ${item.medicineName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Quantity: ${item.stockQuantity} ${item.unit}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New Stock Quantity',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
            onPressed: () async {
              final newQty = int.tryParse(controller.text.trim()) ?? item.stockQuantity;
              Navigator.pop(ctx);
              await widget.api.updatePharmacyStock(
                facilityId: item.facilityId,
                medicineName: item.medicineName,
                quantity: newQty,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Updated ${item.medicineName} stock to $newQty ${item.unit}')),
              );
              _loadData();
            },
            child: const Text('Save Stock'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_pharmacy_rounded, color: Color(0xFF0F766E), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'PHC Pharmacy Dispensing Portal',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCCFBF1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'FACILITY-SCOPED ACCESS',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Shivaji Nagar PHC • Restricted Order Scope (No unrestricted patient medical history)',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F766E)),
                  onPressed: _loadData,
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0F766E),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF0F766E),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: [
                Tab(
                  icon: const Icon(Icons.receipt_long_rounded),
                  text: 'PRESCRIPTION QUEUE (${_orders.where((o) => o.status == "pending").length} PENDING)',
                ),
                Tab(
                  icon: const Icon(Icons.inventory_rounded),
                  text: 'MEDICINE INVENTORY (${_inventory.length} ITEMS)',
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)))
                : _error != null
                    ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPrescriptionsTab(),
                          _buildInventoryTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionsTab() {
    if (_orders.isEmpty) {
      return const Center(child: Text('No prescription orders assigned to this facility.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final o = _orders[index];
        final isDispensed = o.status == 'dispensed';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDispensed ? const Color(0xFFE2E8F0) : const Color(0xFF0F766E).withValues(alpha: 0.3)),
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
                      color: isDispensed ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isDispensed ? 'DISPENSED' : 'PENDING DISPENSING',
                      style: TextStyle(
                        color: isDispensed ? Colors.green : Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Patient: ${o.patientName} (${o.healthId})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                  ),
                  const Spacer(),
                  Text(
                    'Prescribed by: ${o.doctorName}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const Divider(height: 24),
              const Text('Prescribed Medications:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
              const SizedBox(height: 8),
              ...o.medicines.map((m) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 8, color: Color(0xFF0F766E)),
                      const SizedBox(width: 8),
                      Text(
                        '${m["medicine"] ?? "Medicine"}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Dosage: ${m["dosage"] ?? "As directed"} • Duration: ${m["duration"] ?? "3 days"}',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                );
              }),
              if (o.instructions != null && o.instructions!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Instructions: ${o.instructions}', style: const TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF64748B), fontSize: 13)),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isDispensed)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Dispense Medicines', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _dispense(o),
                    )
                  else
                    const Text('Dispensed & recorded in PHC log', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInventoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
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
                Icon(Icons.inventory_rounded, color: Color(0xFF0F766E)),
                SizedBox(width: 8),
                Text(
                  'Pharmacy Medicine Stock & Inventory Levels',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Medicine', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Min Threshold', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Stock Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _inventory.map((item) {
                  Color c = item.status == 'out_of_stock'
                      ? Colors.red
                      : (item.status == 'low_stock' ? Colors.orange : Colors.green);

                  return DataRow(cells: [
                    DataCell(Text(item.medicineName, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text('${item.stockQuantity}')),
                    DataCell(Text(item.unit)),
                    DataCell(Text('${item.minThreshold}')),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.status.toUpperCase().replaceAll('_', ' '),
                          style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ),
                    DataCell(
                      TextButton.icon(
                        icon: const Icon(Icons.edit, size: 14, color: Color(0xFF0F766E)),
                        label: const Text('Update', style: TextStyle(color: Color(0xFF0F766E))),
                        onPressed: () => _updateStockDialog(item),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
