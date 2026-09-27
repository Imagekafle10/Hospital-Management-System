import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/appointment.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class AppointmentTile extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onTap;

  /// Whichever name should be shown as the "counterparty" — pass the
  /// doctor's name on a patient's list, or the patient's name on a
  /// doctor's list. Admin views can pass both via [subtitleOverride].
  final String title;
  final String? subtitleOverride;

  const AppointmentTile({
    super.key,
    required this.appointment,
    required this.onTap,
    required this.title,
    this.subtitleOverride,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE, MMM d · h:mm a').format(appointment.appointmentDate);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_note_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(
                      subtitleOverride ?? date,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    if (subtitleOverride != null) ...[
                      const SizedBox(height: 2),
                      Text(date,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(status: appointment.status),
            ],
          ),
        ),
      ),
    );
  }
}
