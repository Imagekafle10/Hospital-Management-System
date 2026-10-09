import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/constants.dart';

class MedicalRecordUploadData {
  final String recordType;
  final String title;
  final String? description;
  final List<int> fileBytes;
  final String fileName;

  MedicalRecordUploadData({
    required this.recordType,
    required this.title,
    this.description,
    required this.fileBytes,
    required this.fileName,
  });
}

/// Shows a bottom sheet that lets the user pick a file (pdf/jpg/png/doc) and
/// fill in its metadata. Returns null if cancelled.
Future<MedicalRecordUploadData?> showMedicalRecordUploadSheet(
    BuildContext context) {
  return showModalBottomSheet<MedicalRecordUploadData>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const _UploadSheetBody(),
  );
}

class _UploadSheetBody extends StatefulWidget {
  const _UploadSheetBody();

  @override
  State<_UploadSheetBody> createState() => _UploadSheetBodyState();
}

class _UploadSheetBodyState extends State<_UploadSheetBody> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _recordType = MedicalRecordType.other;
  PlatformFile? _file;
  bool _picking = false;

  Future<void> _pickFile() async {
    setState(() => _picking = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _file = result.files.first);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_file == null || _file!.bytes == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pick a file first')));
      return;
    }
    Navigator.pop(
      context,
      MedicalRecordUploadData(
        recordType: _recordType,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        fileBytes: _file!.bytes!,
        fileName: _file!.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Upload medical record',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _recordType,
              decoration: const InputDecoration(labelText: 'Record type'),
              items: MedicalRecordType.all
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _recordType = v ?? _recordType),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _picking ? null : _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(_file == null ? 'Choose file' : _file!.name,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }
}
