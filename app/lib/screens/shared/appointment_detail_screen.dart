import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'esewa_payment_screen.dart';
import '../../core/constants.dart';
import '../../models/appointment.dart';
import '../../models/medicine.dart';
import '../../models/prescription.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/medical_record_tile.dart';
import '../../widgets/open_record.dart';
import '../../models/medical_record.dart';

class AppointmentDetailScreen extends StatefulWidget {
  final Appointment appointment;
  const AppointmentDetailScreen({super.key, required this.appointment});

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  late Appointment _appointment;

  @override
  void initState() {
    super.initState();
    _appointment = widget.appointment;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppointmentProvider>().fetchPrescriptions(_appointment.id);
      context.read<AppointmentProvider>().fetchAttachedRecords(_appointment.id);
      context.read<PaymentProvider>().fetchForAppointment(_appointment.id);
    });
  }

  Future<void> _pay(String method) async {
    final provider = context.read<PaymentProvider>();
    final result =
        await provider.initiate(appointmentId: _appointment.id, method: method);
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'Payment failed')));
      return;
    }
    if (method == PaymentMethod.esewa &&
        result.redirectUrl != null &&
        result.formFields != null) {
      // eSewa needs a POST with form fields, so open it in a WebView.
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EsewaPaymentScreen(
            gatewayUrl: result.redirectUrl!,
            formFields: result.formFields!,
          ),
        ),
      );
      if (!mounted) return;
      await context
          .read<PaymentProvider>()
          .fetchForAppointment(_appointment.id);
    } else if (result.redirectUrl != null) {
      final uri = Uri.parse(result.redirectUrl!);
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open payment page')));
      }
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  Future<void> _collectCod(int paymentId) async {
    final provider = context.read<PaymentProvider>();
    final ok =
        await provider.collectCod(paymentId, appointmentId: _appointment.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ok
              ? 'Payment marked as collected'
              : (provider.error ?? 'Failed'))),
    );
  }

  Future<void> _updateStatus(String status) async {
    final provider = context.read<AppointmentProvider>();
    String? notes;
    if (status == AppointmentStatus.cancelled) {
      notes = await _promptNotes('Reason for cancelling (optional)');
    } else if (status == AppointmentStatus.completed) {
      notes = await _promptNotes('Visit notes (optional)');
    }
    final ok =
        await provider.updateStatus(_appointment.id, status, notes: notes);
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
      if (status == AppointmentStatus.completed) {
        await _editFollowUp(); // checkup done -> ask about follow-up
      }
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
              const Text('Suggest medicine',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Autocomplete<Medicine>(
                displayStringForOption: (m) => m.name,
                optionsBuilder: (value) => context
                    .read<AppointmentProvider>()
                    .searchMedicines(value.text),
                onSelected: (m) {
                  medicationCtrl.text = m.name;
                  if (dosageCtrl.text.isEmpty) dosageCtrl.text = m.unit;
                },
                optionsViewBuilder: (ctx, onSelected, options) => Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxHeight: 220, maxWidth: 340),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: options
                            .map((m) => ListTile(
                                  dense: true,
                                  title: Text(m.label),
                                  subtitle: Text(m.inStock
                                      ? 'In stock: ${m.stockQuantity} ${m.unit}'
                                      : 'Out of stock'),
                                  onTap: () => onSelected(m),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ),
                fieldViewBuilder: (ctx, ctrl, focus, onSubmit) =>
                    TextFormField(
                  controller: ctrl,
                  focusNode: focus,
                  onChanged: (v) => medicationCtrl.text = v,
                  decoration: const InputDecoration(
                    labelText: 'Suggest medicine',
                    hintText: 'Search pharmacy or type a name',
                    prefixIcon: Icon(Icons.search),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: dosageCtrl,
                decoration:
                    const InputDecoration(labelText: 'Dosage (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: instructionsCtrl,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Instructions (optional)'),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text('Save medicine'),
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
      SnackBar(
          content:
              Text(ok ? 'Prescription added' : (provider.error ?? 'Failed'))),
    );
  }

  Future<void> _editFollowUp() async {
    bool required = _appointment.followUpRequired;
    DateTime? date = _appointment.followUpDate;
    final notesCtrl = TextEditingController(text: _appointment.followUpNotes);

    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Follow-up',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Follow-up required'),
                value: required,
                onChanged: (v) => setSheet(() => required = v),
              ),
              if (required) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(date == null
                      ? 'Pick follow-up date'
                      : DateFormat('EEE, MMM d, y').format(date!)),
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date ?? now.add(const Duration(days: 7)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (picked != null) setSheet(() => date = picked);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Follow-up notes (optional)',
                    hintText: 'e.g. Repeat blood test, review BP',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: (required && date == null)
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );

    if (save != true || !mounted) return;
    final provider = context.read<AppointmentProvider>();
    final updated = await provider.setFollowUp(
      _appointment.id,
      required: required,
      date: date,
      notes: notesCtrl.text.trim(),
    );
    if (!mounted) return;
    if (updated != null) setState(() => _appointment = updated);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(updated != null
            ? (required ? 'Follow-up saved' : 'No follow-up needed')
            : (provider.error ?? 'Failed'))));
  }

  Widget? _buildFollowUp(bool isDoctor) {
    final a = _appointment;
    if (a.status != AppointmentStatus.completed) return null;
    if (!isDoctor && !a.followUpRequired) return null;

    final Widget body = a.followUpRequired
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (a.followUpDate != null)
                _InfoRow(
                  icon: Icons.event_repeat_outlined,
                  label: 'Come back on',
                  value: DateFormat('EEE, MMM d, y').format(a.followUpDate!),
                ),
              if (a.followUpNotes != null && a.followUpNotes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.notes_outlined,
                  label: 'Follow-up notes',
                  value: a.followUpNotes!,
                ),
              ],
            ],
          )
        : const Text('No follow-up set. Tap Edit if the patient needs a revisit.',
            style: TextStyle(color: AppColors.textSecondary));

    return _SectionCard(
      title: 'Follow-up if required',
      trailing: isDoctor
          ? TextButton.icon(
              onPressed: _editFollowUp,
              icon: Icon(a.followUpRequired ? Icons.edit : Icons.add, size: 18),
              label: Text(a.followUpRequired ? 'Edit' : 'Set'),
            )
          : null,
      child: body,
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  Widget _buildHero() {
    final a = _appointment;
    final doctorName =
        a.doctorName != null ? 'Dr. ${a.doctorName}' : 'Appointment';
    final initial = (a.doctorName?.isNotEmpty == true ? a.doctorName![0] : 'D')
        .toUpperCase();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                    if (a.doctorSpecialization != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        a.doctorSpecialization!,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusControl(),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeroMeta(
                    icon: Icons.calendar_month_outlined,
                    text: DateFormat('EEE, MMM d, y').format(a.appointmentDate),
                  ),
                ),
                Container(
                    width: 1,
                    height: 22,
                    color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(width: 14),
                _HeroMeta(
                  icon: Icons.schedule_outlined,
                  text: DateFormat('h:mm a').format(a.appointmentDate),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    final a = _appointment;
    final rows = <Widget>[];

    void add(IconData icon, String label, String value) {
      if (rows.isNotEmpty)
        rows.add(const Divider(height: 22, color: Color(0xFFEDF2F1)));
      rows.add(_InfoRow(icon: icon, label: label, value: value));
    }

    if (a.patientName != null)
      add(Icons.person_outline, 'Patient', a.patientName!);
    if (a.reason != null && a.reason!.isNotEmpty) {
      add(Icons.notes_outlined, 'Reason for visit', a.reason!);
    }
    if (a.notes != null && a.notes!.isNotEmpty) {
      add(Icons.sticky_note_2_outlined, 'Doctor notes', a.notes!);
    }
    add(Icons.confirmation_number_outlined, 'Booking ID', '#${a.id}');

    return _SectionCard(title: 'Details', child: Column(children: rows));
  }

  /// Status pill in the hero. Doctors/admins can tap it to change the status.
  Widget _buildStatusControl() {
    final pill = _StatusPill(status: _appointment.status);
    final role = context.read<AuthProvider>().session?.role;
    final canEdit = role == AppRoles.doctor || role == AppRoles.admin;
    if (!canEdit) return pill;

    final mutating = context.watch<AppointmentProvider>().mutating;
    final options =
        AppointmentStatus.all.where((s) => s != _appointment.status).toList();

    return PopupMenuButton<String>(
      enabled: !mutating,
      tooltip: 'Change status',
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: _updateStatus,
      itemBuilder: (_) => options.map((s) {
        final color = AppColors.statusColor(s);
        return PopupMenuItem<String>(
          value: s,
          child: Row(
            children: [
              Icon(_statusIcon(s), size: 18, color: color),
              const SizedBox(width: 10),
              Text(s,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }).toList(),
      child: _StatusPill(status: _appointment.status, showArrow: true),
    );
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case AppointmentStatus.confirmed:
        return Icons.check_circle_outline;
      case AppointmentStatus.completed:
        return Icons.task_alt_outlined;
      case AppointmentStatus.cancelled:
        return Icons.cancel_outlined;
      default:
        return Icons.hourglass_empty_outlined;
    }
  }

  Widget _buildPaymentSection(
    BuildContext context, {
    required bool isDoctor,
    required bool isPatient,
    required bool isAdmin,
  }) {
    final payment =
        context.watch<PaymentProvider>().paymentForAppointment(_appointment.id);
    final mutating = context.watch<PaymentProvider>().mutating;

    Widget content;

    if (payment != null && payment.isPaid) {
      // Paid: green confirmation.
      content = Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment completed',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    'Paid via ${payment.method} · Rs. ${payment.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (isPatient) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (payment != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 18, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Last attempt: ${payment.method} · ${payment.status}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          const Text('Choose a payment method',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          ...PaymentMethod.all.map((m) => _PaymentMethodTile(
                method: m,
                disabled: mutating,
                onTap: () => _pay(m),
              )),
        ],
      );
    } else if ((isDoctor || isAdmin) &&
        payment != null &&
        payment.method == PaymentMethod.cod) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Cash on delivery · ${payment.status}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: mutating ? null : () => _collectCod(payment.id),
            icon: const Icon(Icons.done_all),
            label: const Text('Mark as collected'),
          ),
        ],
      );
    } else if (payment != null) {
      content = Row(
        children: [
          const Icon(Icons.receipt_long_outlined,
              color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text('${payment.method} · ${payment.status}',
              style: const TextStyle(color: AppColors.textSecondary)),
        ],
      );
    } else {
      content = const Row(
        children: [
          Icon(Icons.receipt_long_outlined, color: AppColors.textSecondary),
          SizedBox(width: 10),
          Text('No payment recorded yet.',
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      );
    }

    return _SectionCard(title: 'Payment', child: content);
  }

  Widget _buildAttachedReports(List<MedicalRecord> records) {
    return _SectionCard(
      title: 'Attached reports',
      child: records.isEmpty
          ? const Text('No reports attached to this appointment.',
              style: TextStyle(color: AppColors.textSecondary))
          : Column(
              children: records
                  .map((r) => MedicalRecordTile(
                        record: r,
                        onTap: () => openMedicalRecord(context, r),
                      ))
                  .toList(),
            ),
    );
  }

  Widget _buildPrescriptions(List<Prescription> prescriptions, bool isDoctor) {
    return _SectionCard(
      title: 'Prescriptions',
      trailing: isDoctor
          ? TextButton.icon(
              onPressed: _addPrescription,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            )
          : null,
      child: prescriptions.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.medication_outlined,
                        size: 34, color: Color(0xFFB5C4C2)),
                    SizedBox(height: 8),
                    Text('No prescriptions yet',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          : Column(
              children: prescriptions.map<Widget>((Prescription p) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F8F8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.12),
                        child: const Icon(Icons.medication_outlined,
                            size: 20, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.medication,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                            if (p.dosage != null && p.dosage!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(p.dosage!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.accent)),
                              ),
                            ],
                            if (p.instructions != null &&
                                p.instructions!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(p.instructions!,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              DateFormat.yMMMd().format(p.createdAt),
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildHero(),
          const SizedBox(height: 16),
          _buildDetails(),
          const SizedBox(height: 16),
          _buildPaymentSection(context,
              isDoctor: isDoctor, isPatient: isPatient, isAdmin: isAdmin),
          const SizedBox(height: 16),
          _buildAttachedReports(provider.attachedRecordsFor(_appointment.id)),
          const SizedBox(height: 16),
          _buildPrescriptions(prescriptions, isDoctor),
          if (_buildFollowUp(isDoctor) != null) ...[
            const SizedBox(height: 16),
            _buildFollowUp(isDoctor)!,
          ],
          if (isPatient && canCancel) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: provider.mutating
                  ? null
                  : () => _updateStatus(AppointmentStatus.cancelled),
              icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
              label: const Text('Cancel appointment',
                  style: TextStyle(color: AppColors.danger)),
              style: OutlinedButton.styleFrom(
                side:
                    BorderSide(color: AppColors.danger.withValues(alpha: 0.6)),
                backgroundColor: AppColors.danger.withValues(alpha: 0.05),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Small building blocks
// -----------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;
  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final bool showArrow;
  const _StatusPill({required this.status, this.showArrow = false});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(status,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 12)),
          if (showArrow) ...[
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 18, color: color),
          ],
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeroMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.white),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final String method;
  final bool disabled;
  final VoidCallback onTap;
  const _PaymentMethodTile({
    required this.method,
    required this.disabled,
    required this.onTap,
  });

  Color get _color {
    switch (method) {
      case PaymentMethod.esewa:
        return const Color(0xFF41A124);
      case PaymentMethod.khalti:
        return const Color(0xFF5C2D91);
      default:
        return AppColors.accent;
    }
  }

  IconData get _icon {
    switch (method) {
      case PaymentMethod.esewa:
        return Icons.account_balance_wallet_outlined;
      case PaymentMethod.khalti:
        return Icons.credit_card_outlined;
      default:
        return Icons.payments_outlined;
    }
  }

  String get _label {
    switch (method) {
      case PaymentMethod.esewa:
        return 'eSewa';
      case PaymentMethod.khalti:
        return 'Khalti';
      default:
        return 'Cash on delivery';
    }
  }

  String get _subtitle {
    switch (method) {
      case PaymentMethod.cod:
        return 'Pay cash at the hospital counter';
      default:
        return 'Pay online instantly';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: disabled ? null : onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE1EAE9)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_icon, color: _color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(_subtitle,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}
