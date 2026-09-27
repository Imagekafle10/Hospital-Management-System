import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class AppointmentDetailScreen extends StatefulWidget {
  final Appointment appointment;
  const AppointmentDetailScreen({super.key, required this.appointment});

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  late Appointment _appointment;

  @override
  void initState() {
    super.initState();
    _appointment = widget.appointment;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppointmentProvider>().fetchPrescriptions(_appointment.id);
    });
  }

  Future<void> _updateStatus(String status) async {
    final provider = context.read<AppointmentProvider>();
    String? notes;
    if (status == AppointmentStatus.cancelled) {
      notes = await _promptNotes('Reason for cancelling (optional)');
    } else if (status == AppointmentStatus.completed) {
      notes = await _promptNotes('Visit notes (optional)');
    }
    final ok = await provider.updateStatus(_appointment.id, status, notes: notes);
    if (!mounted) return;
    if (ok) {
      setState(() {
        final updated = provider.appointments.firstWhere(
          (a) => a.id == _appointment.id,
          orElse: () => _appointment,
        );
        _appointment = updated;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Marked as $status')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Update failed')),
      );
    }
  }

  Future<String?> _promptNotes(String label) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Optional note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPrescription() async {
    final medicationCtrl = TextEditingController();
    final dosageCtrl = TextEditingController();
    final instructionsCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Add prescription',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextFormField(
                controller: medicationCtrl,
                decoration: const InputDecoration(labelText: 'Medication'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: dosageCtrl,
                decoration: const InputDecoration(labelText: 'Dosage (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: instructionsCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Instructions (optional)'),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text('Save prescription'),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != true || !mounted) return;
    final provider = context.read<AppointmentProvider>();
    final ok = await provider.addPrescription(
      _appointment.id,
      medication: medicationCtrl.text.trim(),
      dosage: dosageCtrl.text.trim(),
      instructions: instructionsCtrl.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Prescription added' : (provider.error ?? 'Failed'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().session?.role;
    final provider = context.watch<AppointmentProvider>();
    final prescriptions = provider.prescriptionsFor(_appointment.id);

    final canCancel = _appointment.status != AppointmentStatus.completed &&
        _appointment.status != AppointmentStatus.cancelled;
    final isDoctor = role == AppRoles.doctor;
    final isPatient = role == AppRoles.patient;
    final isAdmin = role == AppRoles.admin;

    return Scaffold(
      appBar: AppBar(title: const Text('Appointment')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Status',
                          style: TextStyle(color: AppColors.textSecondary)),
                      StatusChip(status: _appointment.status),
                    ],
                  ),
                  const Divider(height: 28),
                  _InfoRow(
                    icon: Icons.event_outlined,
                    label: 'Date & time',
                    value: DateFormat('EEEE, MMM d, y · h:mm a')
                        .format(_appointment.appointmentDate),
                  ),
                  if (_appointment.doctorName != null)
                    _InfoRow(
                      icon: Icons.medical_services_outlined,
                      label: 'Doctor',
                      value: 'Dr. ${_appointment.doctorName}'
                          '${_appointment.doctorSpecialization != null ? ' · ${_appointment.doctorSpecialization}' : ''}',
                    ),
                  if (_appointment.patientName != null)
                    _InfoRow(
                      icon: Icons.person_outline,
                      label: 'Patient',
                      value: _appointment.patientName!,
                    ),
                  if (_appointment.reason != null && _appointment.reason!.isNotEmpty)
                    _InfoRow(
                      icon: Icons.notes_outlined,
                      label: 'Reason',
                      value: _appointment.reason!,
                    ),
                  if (_appointment.notes != null && _appointment.notes!.isNotEmpty)
                    _InfoRow(
                      icon: Icons.sticky_note_2_outlined,
                      label: 'Notes',
                      value: _appointment.notes!,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (isDoctor || isAdmin) ...[
            const SectionTitle(title: 'Update status'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: AppointmentStatus.all
                  .where((s) => s != _appointment.status)
                  .map((s) => OutlinedButton(
                        onPressed: provider.mutating ? null : () => _updateStatus(s),
                        child: Text(s),
                      ))
                  .toList(),
            ),
          ] else if (isPatient && canCancel) ...[
            const SectionTitle(title: 'Actions'),
            OutlinedButton.icon(
              onPressed: provider.mutating
                  ? null
                  : () => _updateStatus(AppointmentStatus.cancelled),
              icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
              label: const Text('Cancel appointment',
                  style: TextStyle(color: AppColors.danger)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
            ),
          ],
          SectionTitle(
            title: 'Prescriptions',
            trailing: isDoctor
                ? TextButton.icon(
                    onPressed: _addPrescription,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  )
                : null,
          ),
          if (prescriptions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No prescriptions yet.',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ...prescriptions.map((p) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.medication,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        if (p.dosage != null && p.dosage!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Dosage: ${p.dosage}',
                              style: const TextStyle(color: AppColors.textSecondary)),
                        ],
                        if (p.instructions != null && p.instructions!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(p.instructions!,
                              style: const TextStyle(color: AppColors.textSecondary)),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          DateFormat.yMMMd().format(p.createdAt),
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
