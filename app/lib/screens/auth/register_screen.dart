import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Doctor fields
  String? _specialization;
  final _licenseCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();

  // Patient fields
  DateTime? _dob;
  String? _gender;
  String? _bloodGroup;
  final _addressCtrl = TextEditingController();

  String _role = AppRoles.patient;
  bool _obscure = true;

  static const _genders = ['Male', 'Female', 'Other'];
  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _licenseCtrl.dispose();
    _feeCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == AppRoles.doctor &&
        (_specialization == null || _licenseCtrl.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Specialization and license number are required for doctors.'),
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      fullName: _fullNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      role: _role,
      phone: _phoneCtrl.text.trim(),
      specialization: _role == AppRoles.doctor ? _specialization : null,
      licenseNumber: _role == AppRoles.doctor ? _licenseCtrl.text.trim() : null,
      consultationFee: _role == AppRoles.doctor && _feeCtrl.text.trim().isNotEmpty
          ? double.tryParse(_feeCtrl.text.trim())
          : null,
      dateOfBirth: _role == AppRoles.patient ? _dob : null,
      gender: _role == AppRoles.patient ? _gender : null,
      bloodGroup: _role == AppRoles.patient ? _bloodGroup : null,
      address: _role == AppRoles.patient ? _addressCtrl.text.trim() : null,
    );

    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Registration failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('I am registering as',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: AppRoles.patient,
                          label: Text('Patient'),
                          icon: Icon(Icons.personal_injury_outlined),
                        ),
                        ButtonSegment(
                          value: AppRoles.doctor,
                          label: Text('Doctor'),
                          icon: Icon(Icons.medical_services_outlined),
                        ),
                      ],
                      selected: {_role},
                      onSelectionChanged: (s) => setState(() => _role = s.first),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _fullNameCtrl,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 6) return 'At least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone (optional)'),
                    ),
                    if (_role == AppRoles.doctor) ...[
                      const SizedBox(height: 22),
                      const Text('Doctor details',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _specialization,
                        decoration: const InputDecoration(labelText: 'Specialization'),
                        items: kSpecializations
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _specialization = v),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _licenseCtrl,
                        decoration: const InputDecoration(labelText: 'License number'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _feeCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Consultation fee (optional)',
                          prefixText: '\$ ',
                        ),
                      ),
                    ],
                    if (_role == AppRoles.patient) ...[
                      const SizedBox(height: 22),
                      const Text('Patient details (optional)',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _pickDob,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Date of birth'),
                          child: Text(
                            _dob == null
                                ? 'Select date'
                                : DateFormat.yMMMd().format(_dob!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: const InputDecoration(labelText: 'Gender'),
                        items: _genders
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _bloodGroup,
                        decoration: const InputDecoration(labelText: 'Blood group'),
                        items: _bloodGroups
                            .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                            .toList(),
                        onChanged: (v) => setState(() => _bloodGroup = v),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _addressCtrl,
                        decoration: const InputDecoration(labelText: 'Address'),
                      ),
                    ],
                    const SizedBox(height: 26),
                    ElevatedButton(
                      onPressed: auth.busy ? null : _submit,
                      child: auth.busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Create account'),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Already have an account? Log in'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
