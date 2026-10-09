import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/patient_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'medical_records_screen.dart';
import 'my_admissions_screen.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  bool _editing = false;
  DateTime? _dob;
  String? _gender;
  String? _bloodGroup;
  final _addressCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();

  static const _genders = ['Male', 'Female', 'Other'];
  static const _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<PatientProvider>().fetchMyProfile();
      _resetFromProfile();
    });
  }

  void _resetFromProfile() {
    final p = context.read<PatientProvider>().myProfile;
    if (p == null) return;
    setState(() {
      _dob = p.dateOfBirth;
      _gender = p.gender;
      _bloodGroup = p.bloodGroup;
      _addressCtrl.text = p.address ?? '';
      _emergencyCtrl.text = p.emergencyContact ?? '';
    });
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    final provider = context.read<PatientProvider>();
    final ok = await provider.updateMyProfile(
      dateOfBirth: _dob,
      gender: _gender,
      bloodGroup: _bloodGroup,
      address: _addressCtrl.text.trim(),
      emergencyContact: _emergencyCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _editing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'Update failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PatientProvider>();
    final p = provider.myProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My profile'),
        actions: [
          if (p != null)
            IconButton(
              icon: Icon(_editing ? Icons.close : Icons.edit_outlined),
              onPressed: () {
                setState(() => _editing = !_editing);
                if (!_editing) _resetFromProfile();
              },
            ),
        ],
      ),
      body: provider.loading && p == null
          ? const LoadingView()
          : p == null
              ? ErrorView(
                  message: provider.error ?? 'Could not load profile',
                  onRetry: () =>
                      context.read<PatientProvider>().fetchMyProfile(),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.12),
                        child: Text(
                          (p.fullName?.isNotEmpty == true
                                  ? p.fullName![0]
                                  : '?')
                              .toUpperCase(),
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(p.fullName ?? '',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    Center(
                      child: Text(p.email ?? '',
                          style:
                              const TextStyle(color: AppColors.textSecondary)),
                    ),
                    const SizedBox(height: 24),
                    if (!_editing) ...[
                      _ReadRow(label: 'Phone', value: p.phone ?? '—'),
                      _ReadRow(
                        label: 'Date of birth',
                        value: p.dateOfBirth != null
                            ? DateFormat.yMMMd().format(p.dateOfBirth!)
                            : '—',
                      ),
                      _ReadRow(label: 'Gender', value: p.gender ?? '—'),
                      _ReadRow(
                          label: 'Blood group', value: p.bloodGroup ?? '—'),
                      _ReadRow(label: 'Address', value: p.address ?? '—'),
                      _ReadRow(
                          label: 'Emergency contact',
                          value: p.emergencyContact ?? '—'),
                      const SizedBox(height: 20),
                      const Divider(height: 1, color: Color(0xFFDCE6E5)),
                      const SizedBox(height: 20),
                      const Text('More',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      _MoreTile(
                        icon: Icons.folder_shared_outlined,
                        label: 'My records',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MedicalRecordsScreen()),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _MoreTile(
                        icon: Icons.local_hospital_outlined,
                        label: 'My hospital stays',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MyAdmissionsScreen()),
                        ),
                      ),
                    ] else ...[
                      InkWell(
                        onTap: _pickDob,
                        child: InputDecorator(
                          decoration:
                              const InputDecoration(labelText: 'Date of birth'),
                          child: Text(_dob == null
                              ? 'Select date'
                              : DateFormat.yMMMd().format(_dob!)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: const InputDecoration(labelText: 'Gender'),
                        items: _genders
                            .map((g) =>
                                DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _bloodGroup,
                        decoration:
                            const InputDecoration(labelText: 'Blood group'),
                        items: _bloodGroups
                            .map((b) =>
                                DropdownMenuItem(value: b, child: Text(b)))
                            .toList(),
                        onChanged: (v) => setState(() => _bloodGroup = v),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _addressCtrl,
                        decoration: const InputDecoration(labelText: 'Address'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _emergencyCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Emergency contact'),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: provider.loading ? null : _save,
                        child: const Text('Save changes'),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _ReadRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReadRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MoreTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
