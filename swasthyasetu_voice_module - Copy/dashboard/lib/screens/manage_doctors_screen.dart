import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/admin_models.dart';
import '../services/api_service.dart';

/// Admin-only "Manage Doctors" screen: lists every doctor_users row and
/// lets an admin create a new doctor/admin login or toggle an account's
/// active status. Only reachable when the signed-in account's role is
/// "admin" — see DashboardShell, which hides this destination otherwise.
/// The backend re-enforces this independently (403 for non-admins), so
/// this is purely a UI convenience, not the security boundary.
class ManageDoctorsScreen extends StatefulWidget {
  final DoctorProfile currentDoctor;

  const ManageDoctorsScreen({super.key, required this.currentDoctor});

  @override
  State<ManageDoctorsScreen> createState() => _ManageDoctorsScreenState();
}

class _ManageDoctorsScreenState extends State<ManageDoctorsScreen> {
  final _apiService = ApiService();
  List<DoctorAccount> _doctors = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final doctors = await _apiService.fetchDoctors();
      if (!mounted) return;
      setState(() {
        _doctors = doctors;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load doctor accounts: ${e.message}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach the server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(DoctorAccount doctor) async {
    final makingActive = !doctor.isActive;
    try {
      await _apiService.setDoctorActive(doctor.id, makingActive);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not reach the server.')));
    }
  }

  Future<void> _openCreateDoctorDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => _CreateDoctorDialog(apiService: _apiService),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              const Text('Manage Doctors', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _openCreateDoctorDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('Add doctor'),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Admin-only: create logins for doctors and program staff, or deactivate an account.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ),
        ),
        Expanded(
          child: _loading && _doctors.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _doctors.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _buildDoctorsTable(),
        ),
      ],
    );
  }

  Widget _buildDoctorsTable() {
    if (_doctors.isEmpty) return const Center(child: Text('No doctor accounts yet.'));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Username')),
              DataColumn(label: Text('Role')),
              DataColumn(label: Text('Speciality')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Last login')),
              DataColumn(label: Text('')),
            ],
            rows: _doctors.map((d) {
              final isSelf = d.id == widget.currentDoctor.id;
              return DataRow(cells: [
                DataCell(Text(d.name)),
                DataCell(Text(d.username)),
                DataCell(Chip(
                  label: Text(d.role, style: const TextStyle(fontSize: 11)),
                  backgroundColor: d.role == 'admin' ? Colors.indigo[50] : null,
                )),
                DataCell(Text(d.speciality ?? '—')),
                DataCell(Chip(
                  label: Text(d.isActive ? 'Active' : 'Deactivated', style: const TextStyle(fontSize: 11)),
                  backgroundColor: d.isActive ? Colors.green[50] : Colors.red[50],
                )),
                DataCell(Text(d.lastLoginAt != null ? DateFormat('MMM d, h:mm a').format(d.lastLoginAt!.toLocal()) : 'Never')),
                DataCell(
                  isSelf
                      ? const Tooltip(message: "You can't deactivate your own account", child: Text('—'))
                      : TextButton(
                          onPressed: () => _toggleActive(d),
                          child: Text(d.isActive ? 'Deactivate' : 'Reactivate'),
                        ),
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _CreateDoctorDialog extends StatefulWidget {
  final ApiService apiService;

  const _CreateDoctorDialog({required this.apiService});

  @override
  State<_CreateDoctorDialog> createState() => _CreateDoctorDialogState();
}

class _CreateDoctorDialogState extends State<_CreateDoctorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _specialityController = TextEditingController();
  final _phoneController = TextEditingController();
  String _role = 'doctor';
  bool _obscurePassword = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _specialityController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.apiService.createDoctor(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        role: _role,
        phone: _phoneController.text.trim(),
        speciality: _specialityController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _error = e.statusCode == 409
            ? 'That username is already taken.'
            : e.statusCode == 403
                ? 'Your account no longer has admin privileges.'
                : e.message;
      });
    } catch (_) {
      setState(() => _error = 'Could not reach the server. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a doctor account'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username', hintText: 'dr.example'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Temporary password',
                    helperText: 'At least 8 characters. Share this with them securely.',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 8) ? 'Minimum 8 characters' : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? 'doctor'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _specialityController,
                  decoration: const InputDecoration(labelText: 'Speciality (optional)', hintText: 'General Medicine'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone (optional)', hintText: '+91XXXXXXXXXX'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }
}
