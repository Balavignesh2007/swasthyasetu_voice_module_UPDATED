import 'package:flutter/material.dart';
import '../services/unified_api_service.dart';
import '../services/patient_location_service.dart';

// ============================================================================
// 1. NEARBY MEDICINE AVAILABILITY DIALOG
// ============================================================================

class NearbyMedicineAvailabilityDialog extends StatefulWidget {
  final UnifiedApiService api;
  final String? patientLocationName;
  final double? lat;
  final double? lng;

  const NearbyMedicineAvailabilityDialog({
    super.key,
    required this.api,
    this.patientLocationName,
    this.lat,
    this.lng,
  });

  static Future<void> show(
    BuildContext context, {
    required UnifiedApiService api,
    String? locationName,
    double? lat,
    double? lng,
  }) {
    final loc = PatientLocationService.instance;
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => NearbyMedicineAvailabilityDialog(
        api: api,
        patientLocationName: locationName ?? loc.locationName,
        lat: lat ?? loc.latitude,
        lng: lng ?? loc.longitude,
      ),
    );
  }

  @override
  State<NearbyMedicineAvailabilityDialog> createState() => _NearbyMedicineAvailabilityDialogState();
}

class _NearbyMedicineAvailabilityDialogState extends State<NearbyMedicineAvailabilityDialog> {
  final TextEditingController _searchController = TextEditingController();
  double _radiusKm = 10.0;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _pharmacies = [];
  String _selectedMedicineChip = 'All';

  final List<String> _quickMedicines = [
    'All',
    'Paracetamol',
    'Metformin',
    'Amoxicillin',
    'Insulin',
    'Cetirizine',
    'ORS',
  ];

  @override
  void initState() {
    super.initState();
    _loadPharmacies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPharmacies([String? medicineQuery]) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final loc = PatientLocationService.instance;
      final query = medicineQuery ?? (_selectedMedicineChip != 'All' ? _selectedMedicineChip : _searchController.text);
      final res = await widget.api.fetchNearbyPharmacies(
        lat: widget.lat ?? loc.latitude,
        lng: widget.lng ?? loc.longitude,
        radiusKm: _radiusKm,
        medicine: query.isNotEmpty ? query : null,
      );

      if (mounted) {
        setState(() {
          _pharmacies = List<Map<String, dynamic>>.from(res['pharmacies'] ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load pharmacy data: $e';
          _loading = false;
        });
      }
    }
  }

  void _onChipSelected(String med) {
    setState(() {
      _selectedMedicineChip = med;
      if (med == 'All') {
        _searchController.clear();
        _loadPharmacies('');
      } else {
        _searchController.text = med;
        _loadPharmacies(med);
      }
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return const Color(0xFF16A34A);
      case 'low_stock':
        return const Color(0xFFD97706);
      case 'out_of_stock':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 20,
        vertical: isMobile ? 12 : 24,
      ),
      child: Container(
        width: isMobile ? double.infinity : 820,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
        child: Column(
          children: [
            // Header
            _buildHeader(context),

            // Controls (Location info, Radius, Search, Filter chips)
            _buildControls(),

            const Divider(height: 1),

            // Pharmacy List
            Expanded(
              child: _loading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF059669)),
                          SizedBox(height: 12),
                          Text('Scanning nearby pharmacies & real-time drug inventory...'),
                        ],
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 40),
                              const SizedBox(height: 8),
                              Text(_error!, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => _loadPharmacies(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _pharmacies.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.medication_outlined, size: 48, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No pharmacies found matching your criteria.',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text('Try increasing search radius or searching for a different medicine.'),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(20),
                              itemCount: _pharmacies.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 16),
                              itemBuilder: (ctx, idx) => _buildPharmacyCard(_pharmacies[idx]),
                            ),
            ),

            // Footer
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nearby Medicine Availability',
                  style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text(
                  'Live stock at PHC Pharmacies, Jan Aushadhi Stores & Govt Hospitals',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location and radius row
          if (isMobile) ...[
            Row(
              children: [
                const Icon(Icons.my_location_rounded, color: Color(0xFF059669), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Location: ${widget.patientLocationName}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Radius: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ...[5.0, 10.0, 20.0].map((r) {
                  final isSel = _radiusKm == r;
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: ChoiceChip(
                      label: Text('${r.toInt()} km', style: TextStyle(fontSize: 11, color: isSel ? Colors.white : const Color(0xFF334155))),
                      selected: isSel,
                      selectedColor: const Color(0xFF059669),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      onSelected: (val) {
                        if (val) {
                          setState(() => _radiusKm = r);
                          _loadPharmacies();
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ] else
            Row(
              children: [
                const Icon(Icons.my_location_rounded, color: Color(0xFF059669), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Patient Location: ${widget.patientLocationName}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                // Radius selector buttons
                const Text('Radius: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ...[5.0, 10.0, 20.0].map((r) {
                  final isSel = _radiusKm == r;
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: ChoiceChip(
                      label: Text('${r.toInt()} km', style: TextStyle(fontSize: 11, color: isSel ? Colors.white : const Color(0xFF334155))),
                      selected: isSel,
                      selectedColor: const Color(0xFF059669),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      onSelected: (val) {
                        if (val) {
                          setState(() => _radiusKm = r);
                          _loadPharmacies();
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          const SizedBox(height: 12),

          // Medicine Search Input
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search medicine name (e.g., Paracetamol, Metformin, Insulin, ORS)...',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF059669)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _selectedMedicineChip = 'All');
                        _loadPharmacies('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF059669), width: 1.8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onSubmitted: (val) => _loadPharmacies(val),
          ),
          const SizedBox(height: 10),

          // Quick Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Popular: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                ..._quickMedicines.map((med) {
                  final isSel = _selectedMedicineChip == med;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(med, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                      selected: isSel,
                      selectedColor: const Color(0xFFD1FAE5),
                      checkmarkColor: const Color(0xFF059669),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(color: isSel ? const Color(0xFF065F46) : const Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => _onChipSelected(med),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPharmacyCard(Map<String, dynamic> pharm) {
    final name = pharm['name'] ?? 'Pharmacy';
    final type = pharm['type'] ?? 'Pharmacy';
    final address = pharm['address'] ?? '';
    final distance = (pharm['distance_km'] ?? 0.0).toString();
    final timings = pharm['timings'] ?? '';
    final phone = pharm['phone'] ?? '';
    final isOpen = pharm['is_open'] == true;
    final medicines = List<Map<String, dynamic>>.from(pharm['medicines'] ?? []);

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Name, Badge, Distance
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: type.contains('PHC')
                                ? const Color(0xFFEFF6FF)
                                : type.contains('Jan Aushadhi')
                                    ? const Color(0xFFFEF3C7)
                                    : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: type.contains('PHC')
                                  ? const Color(0xFF93C5FD)
                                  : type.contains('Jan Aushadhi')
                                      ? const Color(0xFFFCD34D)
                                      : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: type.contains('PHC')
                                  ? const Color(0xFF1D4ED8)
                                  : type.contains('Jan Aushadhi')
                                      ? const Color(0xFFB45309)
                                      : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Distance Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_walk_rounded, color: Color(0xFF059669), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$distance km',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          // Info row: Timings, Phone, Open status
          Wrap(
            spacing: 16,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOpen ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOpen ? 'Open Now' : 'Closed',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isOpen ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('•  $timings', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              if (phone.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF059669)),
                    const SizedBox(width: 4),
                    Text(phone, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF059669))),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Medicines in stock
          const Text(
            'Stock Availability:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: medicines.map((m) {
              final mName = m['name'] ?? '';
              final stock = m['stock'] ?? 0;
              final unit = m['unit'] ?? 'units';
              final status = m['status'] ?? 'unknown';
              final price = m['price'] ?? 'Free';
              final statusCol = _getStatusColor(status);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusCol.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusCol.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      status == 'available'
                          ? Icons.check_circle_rounded
                          : status == 'low_stock'
                              ? Icons.warning_amber_rounded
                              : Icons.cancel_rounded,
                      size: 14,
                      color: statusCol,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      mName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '($stock $unit)',
                      style: TextStyle(fontSize: 11, color: statusCol, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        price,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // Action Buttons
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.phone_in_talk, size: 14),
                label: const Text('Call Pharmacy'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF059669),
                  side: const BorderSide(color: Color(0xFF059669)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Calling $name ($phone)...')),
                  );
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.bookmark_add_outlined, size: 14),
                label: const Text('Reserve Medicine'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Reservation request sent to $name! You will receive an SMS confirmation.')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, size: 16, color: Color(0xFF059669)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Stock counts synchronized with e-Aushadhi & SwasthyaSetu PHC Inventory.',
              style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. NEARBY DIAGNOSTIC CENTRES DIALOG
// ============================================================================

class NearbyDiagnosticCentresDialog extends StatefulWidget {
  final UnifiedApiService api;
  final String? patientLocationName;
  final double? lat;
  final double? lng;

  const NearbyDiagnosticCentresDialog({
    super.key,
    required this.api,
    this.patientLocationName,
    this.lat,
    this.lng,
  });

  static Future<void> show(
    BuildContext context, {
    required UnifiedApiService api,
    String? locationName,
    double? lat,
    double? lng,
  }) {
    final loc = PatientLocationService.instance;
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => NearbyDiagnosticCentresDialog(
        api: api,
        patientLocationName: locationName ?? loc.locationName,
        lat: lat ?? loc.latitude,
        lng: lng ?? loc.longitude,
      ),
    );
  }

  @override
  State<NearbyDiagnosticCentresDialog> createState() => _NearbyDiagnosticCentresDialogState();
}

class _NearbyDiagnosticCentresDialogState extends State<NearbyDiagnosticCentresDialog> {
  final TextEditingController _searchController = TextEditingController();
  double _radiusKm = 15.0;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _centres = [];
  String _selectedTestChip = 'All';

  final List<String> _quickTests = [
    'All',
    'CBC',
    'Blood Glucose',
    'Malaria',
    'Thyroid',
    'Lipid Profile',
    'X-Ray',
    'CT Scan',
  ];

  @override
  void initState() {
    super.initState();
    _loadCentres();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCentres([String? testQuery]) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final loc = PatientLocationService.instance;
      final query = testQuery ?? (_selectedTestChip != 'All' ? _selectedTestChip : _searchController.text);
      final res = await widget.api.fetchNearbyDiagnostics(
        lat: widget.lat ?? loc.latitude,
        lng: widget.lng ?? loc.longitude,
        radiusKm: _radiusKm,
        testType: query.isNotEmpty ? query : null,
      );

      if (mounted) {
        setState(() {
          _centres = List<Map<String, dynamic>>.from(res['diagnostic_centres'] ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load diagnostic centre data: $e';
          _loading = false;
        });
      }
    }
  }

  void _onChipSelected(String test) {
    setState(() {
      _selectedTestChip = test;
      if (test == 'All') {
        _searchController.clear();
        _loadCentres('');
      } else {
        _searchController.text = test;
        _loadCentres(test);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 20,
        vertical: isMobile ? 12 : 24,
      ),
      child: Container(
        width: isMobile ? double.infinity : 820,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
        child: Column(
          children: [
            // Header
            _buildHeader(context),

            // Controls (Location info, Radius, Search, Quick test chips)
            _buildControls(),

            const Divider(height: 1),

            // Diagnostic Centres List
            Expanded(
              child: _loading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF6366F1)),
                          SizedBox(height: 12),
                          Text('Scanning nearby laboratories, diagnostic centres & test slots...'),
                        ],
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 40),
                              const SizedBox(height: 8),
                              Text(_error!, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => _loadCentres(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _centres.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.biotech_outlined, size: 48, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No diagnostic centres found matching your search.',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text('Try increasing search radius or searching for a different test name.'),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(20),
                              itemCount: _centres.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 16),
                              itemBuilder: (ctx, idx) => _buildCentreCard(_centres[idx]),
                            ),
            ),

            // Footer
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.biotech_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nearby Diagnostic Centres & Labs',
                  style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text(
                  'Pathology, Radiology & Clinical Tests with Pricing & Turnaround Times',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location and radius row
          if (isMobile) ...[
            Row(
              children: [
                const Icon(Icons.my_location_rounded, color: Color(0xFF4F46E5), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Location: ${widget.patientLocationName}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Radius: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ...[5.0, 10.0, 15.0, 25.0].map((r) {
                  final isSel = _radiusKm == r;
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: ChoiceChip(
                      label: Text('${r.toInt()} km', style: TextStyle(fontSize: 11, color: isSel ? Colors.white : const Color(0xFF334155))),
                      selected: isSel,
                      selectedColor: const Color(0xFF4F46E5),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      onSelected: (val) {
                        if (val) {
                          setState(() => _radiusKm = r);
                          _loadCentres();
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ] else
            Row(
              children: [
                const Icon(Icons.my_location_rounded, color: Color(0xFF4F46E5), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Patient Location: ${widget.patientLocationName}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                // Radius selector buttons
                const Text('Radius: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ...[5.0, 10.0, 15.0, 25.0].map((r) {
                  final isSel = _radiusKm == r;
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: ChoiceChip(
                      label: Text('${r.toInt()} km', style: TextStyle(fontSize: 11, color: isSel ? Colors.white : const Color(0xFF334155))),
                      selected: isSel,
                      selectedColor: const Color(0xFF4F46E5),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      onSelected: (val) {
                        if (val) {
                          setState(() => _radiusKm = r);
                          _loadCentres();
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          const SizedBox(height: 12),

          // Diagnostic Test Search Input
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search test name (e.g., CBC, Blood Glucose, Thyroid, X-Ray, ECG, CT Scan)...',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF4F46E5)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _selectedTestChip = 'All');
                        _loadCentres('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onSubmitted: (val) => _loadCentres(val),
          ),
          const SizedBox(height: 10),

          // Quick Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Common Tests: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                ..._quickTests.map((test) {
                  final isSel = _selectedTestChip == test;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(test, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                      selected: isSel,
                      selectedColor: const Color(0xFFE0E7FF),
                      checkmarkColor: const Color(0xFF4F46E5),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(color: isSel ? const Color(0xFF3730A3) : const Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => _onChipSelected(test),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCentreCard(Map<String, dynamic> centre) {
    final name = centre['name'] ?? 'Diagnostic Centre';
    final type = centre['type'] ?? 'Diagnostic Centre';
    final address = centre['address'] ?? '';
    final distance = (centre['distance_km'] ?? 0.0).toString();
    final timings = centre['timings'] ?? '';
    final phone = centre['phone'] ?? '';
    final isOpen = centre['is_open'] == true;
    final isNabl = centre['nabl_accredited'] == true;
    final tests = List<Map<String, dynamic>>.from(centre['tests'] ?? []);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Name, NABL badge, Distance
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        if (isNabl)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF93C5FD)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, size: 12, color: Color(0xFF2563EB)),
                                SizedBox(width: 3),
                                Text(
                                  'NABL Accredited',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$type • $address',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Distance Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_walk_rounded, color: Color(0xFF4F46E5), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$distance km',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          // Info row: Timings, Phone, Open status
          Wrap(
            spacing: 16,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOpen ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOpen ? 'Open Now' : 'Closed',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isOpen ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('•  $timings', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              if (phone.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 4),
                    Text(phone, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF4F46E5))),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Available tests table
          const Text(
            'Available Diagnostic Tests & Pricing:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tests.map((t) {
              final tName = t['name'] ?? '';
              final price = t['price'] ?? 'Free';
              final turnaround = t['turnaround'] ?? '24 hrs';
              final avail = t['available'] == true;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: avail ? const Color(0xFFF5F3FF) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: avail ? const Color(0xFFDDD6FE) : const Color(0xFFFECACA)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      avail ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 14,
                      color: avail ? const Color(0xFF4F46E5) : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: avail ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                        decoration: avail ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: price.contains('Free') ? const Color(0xFFDCFCE7) : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        price,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: price.contains('Free') ? const Color(0xFF15803D) : const Color(0xFF4338CA),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '⏱ $turnaround',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // Action Buttons
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.phone_in_talk, size: 14),
                label: const Text('Contact Lab'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  side: const BorderSide(color: Color(0xFF4F46E5)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Contacting $name ($phone)...')),
                  );
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.event_available_rounded, size: 14),
                label: const Text('Book Test Slot'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Test slot booking requested at $name! You will receive confirmation via SMS.')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, size: 16, color: Color(0xFF4F46E5)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Authorized diagnostic laboratories and sample collection centres under ABDM network.',
              style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
