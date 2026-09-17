import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/unified_models.dart';
import '../../services/unified_api_service.dart';

class AdminDoctorsView extends StatefulWidget {
  final UnifiedApiService api;
  final UnifiedUserSession session;

  const AdminDoctorsView({super.key, required this.api, required this.session});

  @override
  State<AdminDoctorsView> createState() => _AdminDoctorsViewState();
}

class _AdminDoctorsViewState extends State<AdminDoctorsView> {
  bool _loading = true;
  String? _error;
  List<AdminDoctorRecord> _doctors = [];
  List<DoctorFacility> _facilities = [];
  String _searchQuery = '';
  String _selectedSpecialty = 'ALL';

  final List<String> _specialties = [
    'ALL',
    'General Medicine',
    'Cardiology',
    'Pulmonology',
    'Pediatrics',
    'Orthopedics',
    'Obstetrics & Gynecology',
    'Dermatology',
    'Emergency Medicine',
    'Administration',
  ];

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
        widget.api.fetchAdminDoctors(),
        widget.api.fetchFacilities().catchError((_) => <DoctorFacility>[]),
      ]);
      if (mounted) {
        setState(() {
          _doctors = results[0] as List<AdminDoctorRecord>;
          _facilities = results[1] as List<DoctorFacility>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load doctors: $e';
          _loading = false;
        });
      }
    }
  }

  List<AdminDoctorRecord> get _filteredDoctors {
    return _doctors.where((d) {
      final matchesSearch = _searchQuery.isEmpty ||
          d.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          d.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (d.speciality ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesSpecialty = _selectedSpecialty == 'ALL' || d.speciality == _selectedSpecialty;
      return matchesSearch && matchesSpecialty;
    }).toList();
  }

  void _showRegisterDoctorDialog() {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String specialty = 'General Medicine';
    String? facilityId = _facilities.isNotEmpty ? _facilities.first.id : null;
    bool obscurePass = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add_rounded, color: Color(0xFF0284C7)),
              SizedBox(width: 8),
              Text('Register New Doctor Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Doctor Full Name *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Dr. Ramesh Varma',
                      prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Login Username *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: userCtrl,
                              decoration: InputDecoration(
                                hintText: 'e.g. dr.ramesh',
                                prefixIcon: const Icon(Icons.alternate_email, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Password (min 8 chars) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: passCtrl,
                              obscureText: obscurePass,
                              decoration: InputDecoration(
                                hintText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline, size: 18),
                                suffixIcon: IconButton(
                                  icon: Icon(obscurePass ? Icons.visibility_off : Icons.visibility, size: 18),
                                  onPressed: () => setDialogState(() => obscurePass = !obscurePass),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Medical Specialty *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: specialty,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: _specialties.where((s) => s != 'ALL').map((s) {
                                return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => specialty = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: phoneCtrl,
                              decoration: InputDecoration(
                                hintText: '+919876543210',
                                prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Assigned Healthcare Facility', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty || userCtrl.text.trim().isEmpty || passCtrl.text.trim().length < 8) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill all required fields (password minimum 8 chars).'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      setDialogState(() => isSubmitting = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final created = await widget.api.registerDoctor(
                          name: nameCtrl.text,
                          username: userCtrl.text,
                          password: passCtrl.text,
                          speciality: specialty,
                          phone: phoneCtrl.text,
                          facilityId: facilityId,
                        );
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        _loadData();
                        messenger.showSnackBar(
                          SnackBar(content: Text('Doctor "${created.name}" registered successfully!'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        messenger.showSnackBar(
                          SnackBar(content: Text('Failed to register doctor: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Register Doctor'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleDoctorStatus(AdminDoctorRecord doctor) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.api.toggleDoctorStatus(doctor.id, !doctor.isActive);
      _loadData();
      messenger.showSnackBar(
        SnackBar(
          content: Text('${doctor.name} account is now ${!doctor.isActive ? "ACTIVE" : "INACTIVE"}'),
          backgroundColor: !doctor.isActive ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredDoctors;
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
                            : _buildDoctorList(list),
              ),
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
          decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.medical_services_rounded, color: Color(0xFF0284C7), size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Doctor & Specialist Registry',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Text(
                'Manage staff accounts, medical specialties, and hospital assignments',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );

    final registerBtn = SizedBox(
      width: isMobile ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: _showRegisterDoctorDialog,
        icon: const Icon(Icons.person_add_rounded, size: 18),
        label: const Text('+ Register New Doctor'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0284C7),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleSection,
          const SizedBox(height: 12),
          registerBtn,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: titleSection),
        const SizedBox(width: 16),
        registerBtn,
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
              hintText: 'Search by doctor name, username, or specialty...',
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
              value: _selectedSpecialty,
              items: _specialties.map((s) => DropdownMenuItem(value: s, child: Text(s == 'ALL' ? 'All Specialties' : s, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedSpecialty = v);
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
          Icon(Icons.person_search_rounded, size: 54, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('No Doctors Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Try adjusting your search criteria or register a new doctor.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showRegisterDoctorDialog,
            icon: const Icon(Icons.person_add, size: 16),
            label: const Text('Register Doctor Now'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorList(List<AdminDoctorRecord> list) {
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final d = list[index];
        return Card(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: d.isActive ? const Color(0xFFE2E8F0) : Colors.red.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: d.isActive ? const Color(0xFFE0F2FE) : Colors.grey.shade200,
                  child: Icon(
                    Icons.person_rounded,
                    color: d.isActive ? const Color(0xFF0284C7) : Colors.grey.shade600,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(d.speciality ?? 'General Medicine', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4338CA))),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: d.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              d.isActive ? 'ACTIVE' : 'INACTIVE',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: d.isActive ? Colors.green.shade800 : Colors.red.shade800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Username: @${d.username}  •  Facility: ${d.facilityName}  •  ${d.phone ?? "No phone registered"}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total OPD Consultations Handled: ${d.appointmentCount}  •  Registered on ${DateFormat('dd MMM yyyy').format(d.createdAt.toLocal())}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      d.isActive ? 'Active Duty' : 'Deactivated',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: d.isActive ? Colors.green : Colors.grey),
                    ),
                    Switch(
                      value: d.isActive,
                      activeThumbColor: const Color(0xFF0284C7),
                      onChanged: (_) => _toggleDoctorStatus(d),
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
}
