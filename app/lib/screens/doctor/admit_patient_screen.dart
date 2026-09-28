import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bed.dart';
import '../../models/patient.dart';
import '../../providers/admission_provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/ward_bed_provider.dart';
import '../../widgets/common.dart';

class AdmitPatientScreen extends StatefulWidget {
  const AdmitPatientScreen({super.key});

  @override
  State<AdmitPatientScreen> createState() => _AdmitPatientScreenState();
}

class _AdmitPatientScreenState extends State<AdmitPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  Patient? _patient;
  Bed? _bed;
  DateTime? _expectedDischarge;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PatientProvider>().fetchAll();
      context.read<WardBedProvider>().fetchAvailableBeds();
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expectedDischarge = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_patient == null || _bed == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pick a patient and a bed')));
      return;
    }
    final provider = context.read<AdmissionProvider>();
    final ok = await provider.admit(
      patientId: _patient!.id,
      bedId: _bed!.id,
      reasonForAdmission: _reasonCtrl.text.trim(),
      expectedDischargeDate: _expectedDischarge,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(provider.error ?? 'Admission failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final patients = context.watch<PatientProvider>().patients;
    final beds = context.watch<WardBedProvider>().availableBeds;
    final mutating = context.watch<AdmissionProvider>().mutating;

    return Scaffold(
      appBar: AppBar(title: const Text('Admit patient')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SectionTitle(title: 'Patient'),
            DropdownButtonFormField<Patient>(
              initialValue: _patient,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Select patient'),
              items: patients
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.fullName ?? 'Patient #${p.id}'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _patient = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 18),
            const SectionTitle(title: 'Bed'),
            DropdownButtonFormField<Bed>(
              initialValue: _bed,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Select available bed'),
              items: beds
                  .map((b) => DropdownMenuItem(
                        value: b,
                        child: Text('Bed ${b.bedNumber} · ${b.wardName ?? ''} (${b.wardType ?? ''})'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _bed = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            if (beds.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No beds are currently available.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
            const SizedBox(height: 18),
            const SectionTitle(title: 'Reason for admission'),
            TextFormField(
              controller: _reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'e.g. Acute appendicitis, observation'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 18),
            const SectionTitle(title: 'Expected discharge (optional)'),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(_expectedDischarge == null
                  ? 'Pick a date'
                  : '${_expectedDischarge!.year}-${_expectedDischarge!.month.toString().padLeft(2, '0')}-${_expectedDischarge!.day.toString().padLeft(2, '0')}'),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: mutating ? null : _submit,
              child: mutating
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Admit patient'),
            ),
          ],
        ),
      ),
    );
  }
}
