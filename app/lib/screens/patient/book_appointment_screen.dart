import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/doctor.dart';
import '../../providers/appointment_provider.dart';
import '../../theme/app_theme.dart';

class BookAppointmentScreen extends StatefulWidget {
  final Doctor doctor;
  const BookAppointmentScreen({super.key, required this.doctor});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  DateTime? _date;
  TimeOfDay? _time;
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  DateTime? get _combined {
    if (_date == null || _time == null) return null;
    return DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
  }

  Future<void> _confirm() async {
    final combined = _combined;
    if (combined == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a date and time first')),
      );
      return;
    }
    if (combined.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment must be in the future')),
      );
      return;
    }

    final provider = context.read<AppointmentProvider>();
    final ok = await provider.book(
      doctorId: widget.doctor.id,
      appointmentDate: combined,
      reason: _reasonCtrl.text.trim(),
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Appointment requested!')));
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Booking failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doctor;
    final provider = context.watch<AppointmentProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Book appointment')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      (d.fullName?.isNotEmpty == true ? d.fullName![0] : '?').toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dr. ${d.fullName ?? 'Unknown'}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 3),
                        Text(d.specialization,
                            style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 3),
                        Text('Consultation fee: \$${d.consultationFee.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Date & time', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(_date == null ? 'Select date' : DateFormat.yMMMd().format(_date!)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time_outlined),
                  label: Text(_time == null ? 'Select time' : _time!.format(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text('Reason for visit (optional)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Briefly describe your symptoms or reason'),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: provider.mutating ? null : _confirm,
            child: provider.mutating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text('Confirm booking'),
          ),
        ],
      ),
    );
  }
}
