import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../providers/doctor_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../patient/patient_dashboard.dart'; // LogoutButton

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  bool _editing = false;
  String? _specialization;
  final _feeCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  TimeOfDay? _from;
  TimeOfDay? _to;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<DoctorProvider>().fetchMyProfile();
      _resetFromProfile();
    });
  }

  void _resetFromProfile() {
    final d = context.read<DoctorProvider>().myProfile;
    if (d == null) return;
    setState(() {
      _specialization = _normalizeSpecialization(d.specialization);
      _feeCtrl.text = d.consultationFee.toStringAsFixed(2);
      _experienceCtrl.text = d.yearsOfExperience.toString();
      _from = _parseTime(d.availableFrom);
      _to = _parseTime(d.availableTo);
    });
  }

  String? _normalizeSpecialization(String? raw) {
    if (raw == null) return null;
    if (kSpecializations.contains(raw)) return raw;

    // Map old/variant values from the backend to the dropdown values.
    const legacy = {
      'Cardiologist': 'Cardiology',
      'Dermatologist': 'Dermatology',
      'Endocrinologist': 'Endocrinology',
      'Gastroenterologist': 'Gastroenterology',
      'Gynecologist': 'Gynecology',
      'Neurologist': 'Neurology',
      'Oncologist': 'Oncology',
      'Ophthalmologist': 'Ophthalmology',
      'Orthopedic': 'Orthopedics',
      'Orthopedist': 'Orthopedics',
      'Pediatrician': 'Pediatrics',
      'Psychiatrist': 'Psychiatry',
      'Pulmonologist': 'Pulmonology',
      'Radiologist': 'Radiology',
      'Urologist': 'Urology',
    };
    return legacy[raw]; // null if unknown, so the dropdown starts empty
  }

  TimeOfDay? _parseTime(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
  }

  String? _formatTime(TimeOfDay? t) {
    if (t == null) return null;
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  Future<void> _save() async {
    final provider = context.read<DoctorProvider>();
    final ok = await provider.updateMyProfile(
      specialization: _specialization,
      consultationFee: double.tryParse(_feeCtrl.text.trim()),
      yearsOfExperience: int.tryParse(_experienceCtrl.text.trim()),
      availableFrom: _formatTime(_from),
      availableTo: _formatTime(_to),
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
    final provider = context.watch<DoctorProvider>();
    final d = provider.myProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My profile'),
        actions: [
          if (d != null)
            IconButton(
              icon: Icon(_editing ? Icons.close : Icons.edit_outlined),
              onPressed: () {
                setState(() => _editing = !_editing);
                if (!_editing) _resetFromProfile();
              },
            ),
          const LogoutButton(),
        ],
      ),
      body: provider.loading && d == null
          ? const LoadingView()
          : d == null
              ? ErrorView(
                  message: provider.error ?? 'Could not load profile',
                  onRetry: () =>
                      context.read<DoctorProvider>().fetchMyProfile(),
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
                          (d.fullName?.isNotEmpty == true
                                  ? d.fullName![0]
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
                      child: Text('Dr. ${d.fullName ?? ''}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    Center(
                      child: Text(d.email ?? '',
                          style:
                              const TextStyle(color: AppColors.textSecondary)),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text('License #${d.licenseNumber}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ),
                    const SizedBox(height: 24),
                    if (!_editing) ...[
                      _ReadRow(
                          label: 'Specialization', value: d.specialization),
                      _ReadRow(
                          label: 'Fee',
                          value: '\$${d.consultationFee.toStringAsFixed(2)}'),
                      _ReadRow(
                          label: 'Experience',
                          value: '${d.yearsOfExperience} years'),
                      _ReadRow(
                        label: 'Available',
                        value:
                            (d.availableFrom != null && d.availableTo != null)
                                ? '${d.availableFrom} – ${d.availableTo}'
                                : 'Not set',
                      ),
                    ] else ...[
                      DropdownButtonFormField<String>(
                        value: kSpecializations.contains(_specialization)
                            ? _specialization
                            : null,
                        decoration:
                            const InputDecoration(labelText: 'Specialization'),
                        items: kSpecializations
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _specialization = v),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _feeCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Consultation fee', prefixText: '\$ '),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _experienceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Years of experience'),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: _from ??
                                      const TimeOfDay(hour: 9, minute: 0),
                                );
                                if (picked != null)
                                  setState(() => _from = picked);
                              },
                              icon: const Icon(Icons.schedule_outlined),
                              label: Text(_from == null
                                  ? 'Available from'
                                  : _from!.format(context)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: _to ??
                                      const TimeOfDay(hour: 17, minute: 0),
                                );
                                if (picked != null)
                                  setState(() => _to = picked);
                              },
                              icon: const Icon(Icons.schedule_outlined),
                              label: Text(_to == null
                                  ? 'Available to'
                                  : _to!.format(context)),
                            ),
                          ),
                        ],
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
