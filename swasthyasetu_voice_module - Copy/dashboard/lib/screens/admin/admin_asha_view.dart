import 'package:flutter/material.dart';
import '../../models/unified_models.dart';
import '../../services/unified_api_service.dart';

class AdminAshaView extends StatefulWidget {
  final UnifiedApiService api;
  final UnifiedUserSession session;

  const AdminAshaView({super.key, required this.api, required this.session});

  @override
  State<AdminAshaView> createState() => _AdminAshaViewState();
}

class _AdminAshaViewState extends State<AdminAshaView> {
  bool _loading = true;
  String? _error;
  List<AdminAshaRecord> _workers = [];
  List<DoctorFacility> _facilities = [];
  String _searchQuery = '';
  String _statusFilter = 'ALL';

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
      final results = await Future.wait([
        widget.api.fetchAdminAshaWorkers(),
        widget.api.fetchFacilities().catchError((_) => <DoctorFacility>[]),
      ]);
      if (mounted) {
        setState(() {
          _workers = results[0] as List<AdminAshaRecord>;
          _facilities = results[1] as List<DoctorFacility>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load ASHA workers: $e';
          _loading = false;
        });
      }
    }
  }

  List<AdminAshaRecord> get _filteredWorkers {
    return _workers.where((w) {
      final matchesSearch = _searchQuery.isEmpty ||
          w.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          w.phone.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          w.village.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _statusFilter == 'ALL' || w.status.toLowerCase() == _statusFilter.toLowerCase();
      return matchesSearch && matchesStatus;
    }).toList();
  }

  void _showRegisterAshaDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final villageCtrl = TextEditingController();
    String? facilityId = _facilities.isNotEmpty ? _facilities.first.id : null;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text('Register New ASHA Field Worker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ASHA Worker Full Name *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Parvati Devi',
                      prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Mobile Contact Phone Number *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneCtrl,
                    decoration: InputDecoration(
                      hintText: '+919876543210',
                      prefixIcon: const Icon(Icons.phone_android_rounded, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Assigned Village / Rural Hamlet *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: villageCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Kalyan Durg West',
                      prefixIcon: const Icon(Icons.location_city_rounded, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Affiliated Health Centre (PHC / CHC)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: facilityId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _facilities.map((f) {
                      return DropdownMenuItem(
                        value: f.id,
                        child: Text('${f.name} (${f.level})', style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => facilityId = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter worker name and phone number.'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      setDialogState(() => isSubmitting = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final created = await widget.api.registerAshaWorker(
                          name: nameCtrl.text,
                          phone: phoneCtrl.text,
                          village: villageCtrl.text,
                          facilityId: facilityId,
                        );
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        _loadData();
                        messenger.showSnackBar(
                          SnackBar(content: Text('ASHA Worker "${created.name}" registered successfully!'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        messenger.showSnackBar(
                          SnackBar(content: Text('Failed to register ASHA: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Register ASHA Worker'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(AdminAshaRecord worker, String newStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.api.updateAshaStatus(worker.id, newStatus);
      _loadData();
      messenger.showSnackBar(
        SnackBar(
          content: Text('${worker.name} status updated to ${newStatus.toUpperCase()}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmDelete(AdminAshaRecord worker) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decommission ASHA Worker?'),
        content: Text('Are you sure you want to remove ${worker.name} (${worker.phone}) from the registry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove Worker'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await widget.api.deleteAshaWorker(worker.id);
        _loadData();
        messenger.showSnackBar(
          SnackBar(content: Text('${worker.name} removed successfully.'), backgroundColor: Colors.blueGrey),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to remove worker: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredWorkers;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              _buildSearchBar(),
              const SizedBox(height: 18),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, style: const TextStyle(color: Colors.red)),
                                const SizedBox(height: 8),
                                ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                              ],
                            ),
                          )
                        : list.isEmpty
                            ? _buildEmptyWidget()
                            : _buildWorkerList(list),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFCCFBF1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.badge_rounded, color: Color(0xFF0F766E), size: 28),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ASHA Community Health Worker Directory',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Manage field worker credentials, rural village assignments, and mobile health access',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _showRegisterAshaDialog,
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
          label: const Text('+ Register New ASHA Worker'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search by worker name, phone number, or village area...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _statusFilter,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Statuses', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'active', child: Text('Active Only', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'on_leave', child: Text('On Leave', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive', style: TextStyle(fontSize: 13))),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _statusFilter = v);
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh list',
          onPressed: _loadData,
        ),
      ],
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.badge_outlined, size: 54, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('No ASHA Workers Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Try adjusting your search query or register a new ASHA worker.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showRegisterAshaDialog,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Register ASHA Worker Now'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerList(List<AdminAshaRecord> list) {
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final w = list[index];
        Color statusColor = Colors.green;
        if (w.status.toLowerCase() == 'on_leave') statusColor = Colors.amber.shade800;
        if (w.status.toLowerCase() == 'inactive') statusColor = Colors.red.shade700;

        return Card(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFFCCFBF1),
                  child: Icon(Icons.badge_rounded, color: Color(0xFF0F766E), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, size: 12, color: Color(0xFF92400E)),
                                const SizedBox(width: 3),
                                Text(w.village, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              w.status.toUpperCase(),
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Phone / Login ID: ${w.phone}  •  Assigned PHC: ${w.facilityName}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Update Status or Actions',
                  onSelected: (val) {
                    if (val == 'delete') {
                      _confirmDelete(w);
                    } else {
                      _updateStatus(w, val);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'active', child: Text('Mark Active')),
                    const PopupMenuItem(value: 'on_leave', child: Text('Mark On Leave')),
                    const PopupMenuItem(value: 'inactive', child: Text('Mark Inactive')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete Worker', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(w.status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
