import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/medical_record_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/medical_record_tile.dart';
import '../../widgets/open_record.dart';
import '../shared/medical_record_upload_sheet.dart';

class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() => context.read<MedicalRecordProvider>().fetchMine();

  Future<void> _upload() async {
    final data = await showMedicalRecordUploadSheet(context);
    if (data == null || !mounted) return;
    final provider = context.read<MedicalRecordProvider>();
    final ok = await provider.upload(
      recordType: data.recordType,
      title: data.title,
      description: data.description,
      fileBytes: data.fileBytes,
      fileName: data.fileName,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Record uploaded' : (provider.error ?? 'Upload failed'))),
    );
    if (ok) _refresh();
  }

  Future<void> _delete(int id) async {
    final provider = context.read<MedicalRecordProvider>();
    final ok = await provider.delete(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Record deleted' : (provider.error ?? 'Delete failed'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicalRecordProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Medical records')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _upload,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: provider.loading
            ? const LoadingView()
            : provider.error != null
                ? ErrorView(message: provider.error!, onRetry: _refresh)
                : provider.records.isEmpty
                    ? const EmptyView(
                        message: 'No medical records yet. Upload lab reports,\nprescriptions or imaging here.',
                        icon: Icons.folder_open_outlined)
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: provider.records
                            .map((r) => MedicalRecordTile(
                                  record: r,
                                  onTap: () => openMedicalRecord(context, r),
                                  onDelete: () => _delete(r.id),
                                ))
                            .toList(),
                      ),
      ),
    );
  }
}
