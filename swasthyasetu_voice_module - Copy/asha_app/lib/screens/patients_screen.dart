import 'package:flutter/material.dart';

import '../models/patient.dart';
import '../services/api_service.dart';
import '../services/offline_sync_service.dart';

class PatientsScreen extends StatefulWidget {
  final String ashaId;
  const PatientsScreen({super.key, required this.ashaId});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _apiService = ApiService();
  List<AshaPatient> _patients = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() => _loading = true);
    try {
      final patients = await _apiService.fetchAssignedPatients(widget.ashaId);
      if (!mounted) return;
      setState(() {
        _patients = patients;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load patients: ${e.message}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach the server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AshaPatient> get _filteredPatients {
    if (_searchQuery.trim().isEmpty) return _patients;
    final q = _searchQuery.toLowerCase().trim();
    return _patients.where((p) {
      final name = (p.name ?? '').toLowerCase();
      final hid = (p.healthId ?? '').toLowerCase();
      final village = (p.village ?? '').toLowerCase();
      return name.contains(q) || hid.contains(q) || village.contains(q);
    }).toList();
  }

  Future<void> _openRegisterPatientDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final villageController = TextEditingController();
    final ageController = TextEditingController();
    final healthIdController = TextEditingController();

    String selectedLang = 'hi';
    String selectedGender = 'Female';
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person_add_alt_1, color: Colors.blue, size: 24),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Register New Patient',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Enrolls the patient into SwasthyaSetu and assigns them to your ASHA coverage.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const Divider(height: 24),

                      // Patient Full Name
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name *',
                          hintText: 'e.g. Meera Bai',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter patient full name';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Phone Number
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Mobile Number *',
                          hintText: '10-digit mobile number',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          prefixText: '+91 ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter mobile number';
                          final digits = val.replaceAll(RegExp(r'\D'), '');
                          if (digits.length != 10) return 'Enter a valid 10-digit mobile number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Village & Age Row
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: villageController,
                              decoration: InputDecoration(
                                labelText: 'Village / Locality',
                                hintText: 'e.g. Rampur Village',
                                prefixIcon: const Icon(Icons.location_on_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: ageController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Age (Yrs)',
                                hintText: 'e.g. 45',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Gender & Language Row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedGender,
                              decoration: InputDecoration(
                                labelText: 'Gender',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Female', child: Text('Female')),
                                DropdownMenuItem(value: 'Male', child: Text('Male')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                              ],
                              onChanged: (val) {
                                if (val != null) setSheetState(() => selectedGender = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedLang,
                              decoration: InputDecoration(
                                labelText: 'Language',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'hi', child: Text('Hindi (हिन्दी)')),
                                DropdownMenuItem(value: 'te', child: Text('Telugu (తెలుగు)')),
                                DropdownMenuItem(value: 'ta', child: Text('Tamil (தமிழ்)')),
                                DropdownMenuItem(value: 'en', child: Text('English')),
                              ],
                              onChanged: (val) {
                                if (val != null) setSheetState(() => selectedLang = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Optional Custom Health ID
                      TextFormField(
                        controller: healthIdController,
                        decoration: InputDecoration(
                          labelText: 'Health ID (Optional)',
                          hintText: 'Leave blank to auto-generate',
                          prefixIcon: const Icon(Icons.credit_card_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          helperText: 'A unique HID (e.g. HID54321) will be created automatically',
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            isSubmitting ? 'Registering Patient...' : 'Register & Link Patient',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setSheetState(() => isSubmitting = true);

                                  final name = nameController.text.trim();
                                  final phone = phoneController.text.trim();
                                  final village = villageController.text.trim();
                                  final healthId = healthIdController.text.trim();
                                  final age = int.tryParse(ageController.text.trim());

                                  try {
                                    final registered = await _apiService.registerPatient(
                                      ashaId: widget.ashaId,
                                      name: name,
                                      phone: phone,
                                      village: village.isNotEmpty ? village : null,
                                      preferredLanguage: selectedLang,
                                      healthId: healthId.isNotEmpty ? healthId : null,
                                      age: age,
                                      gender: selectedGender,
                                    );

                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Registered ${registered.name ?? name} (ID: ${registered.healthId ?? "Generated"})',
                                          ),
                                          backgroundColor: Colors.green.shade700,
                                        ),
                                      );
                                    }
                                    _loadPatients();
                                  } catch (e) {
                                    // Queue offline if server unreachable
                                    await OfflineSyncService.instance.queuePatientRegistration({
                                      'asha_id': widget.ashaId,
                                      'name': name,
                                      'phone': phone,
                                      'village': village,
                                      'preferred_language': selectedLang,
                                      'health_id': healthId.isNotEmpty ? healthId : null,
                                      'age': age,
                                      'gender': selectedGender,
                                    });

                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Network unavailable: $name saved offline. Will sync when online.',
                                          ),
                                          backgroundColor: Colors.orange.shade800,
                                        ),
                                      );
                                    }
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPatients;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Patients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh list',
            onPressed: _loadPatients,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRegisterPatientDialog,
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Register Patient', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPatients,
        child: Column(
          children: [
            // Search Bar & Stats Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: Colors.blue.shade50.withValues(alpha: 0.5),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search patients by name, village, or ID...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${filtered.length} of ${_patients.length} patients',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ASHA Field Registry',
                          style: TextStyle(fontSize: 11, color: Color(0xFF1565C0), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(child: _buildBody(filtered)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<AshaPatient> filtered) {
    if (_loading && _patients.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _patients.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(child: Text(_error!, textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          Center(child: OutlinedButton(onPressed: _loadPatients, child: const Text('Retry'))),
        ],
      );
    }
    if (_patients.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.people_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'No patients assigned yet.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Tap "+ Register Patient" below to add a community member.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              onPressed: _openRegisterPatientDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Register First Patient'),
            ),
          ),
        ],
      );
    }
    if (filtered.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 60),
          const Center(child: Text('No matching patients found.')),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Text('Clear search filter'),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final patient = filtered[index];
        final lang = patient.preferredLanguage?.toUpperCase() ?? 'HI';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            foregroundColor: const Color(0xFF1976D2),
            child: Text(
              patient.displayName.isNotEmpty ? patient.displayName[0].toUpperCase() : 'P',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            patient.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Row(
            children: [
              if (patient.healthId != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    patient.healthId!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade800, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  patient.village ?? 'Village not specified',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Text(
              lang,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
            ),
          ),
        );
      },
    );
  }
}
