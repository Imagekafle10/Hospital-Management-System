import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/medical_record.dart';
import '../providers/medical_record_provider.dart';

/// Opens a medical record's file (image / PDF / etc.) when a tile is tapped.
Future<void> openMedicalRecord(BuildContext context, MedicalRecord record) async {
  final messenger = ScaffoldMessenger.of(context);
  final provider = context.read<MedicalRecordProvider>();

  final url = await provider.getViewUrl(record.id);
  if (url == null) {
    messenger.showSnackBar(
      SnackBar(content: Text(provider.openError ?? 'Could not open file')),
    );
    return;
  }

  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok) {
    messenger.showSnackBar(const SnackBar(content: Text('Could not open file')));
  }
}
