import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medical_record.dart';
import '../theme/app_theme.dart';

IconData recordTypeIcon(String type) {
  switch (type) {
    case 'LabReport':
      return Icons.biotech_outlined;
    case 'Prescription':
      return Icons.medication_outlined;
    case 'Diagnosis':
      return Icons.assignment_outlined;
    case 'Imaging':
      return Icons.image_outlined;
    default:
      return Icons.description_outlined;
  }
}

class MedicalRecordTile extends StatelessWidget {
  final MedicalRecord record;
  final VoidCallback? onDelete;

  const MedicalRecordTile({super.key, required this.record, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Icon(recordTypeIcon(record.recordType), color: AppColors.primary),
        ),
        title: Text(record.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${record.recordType} · ${record.fileName} · ${record.fileSizeLabel}\n'
          '${DateFormat.yMMMd().add_jm().format(record.createdAt)}',
        ),
        isThreeLine: true,
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}
