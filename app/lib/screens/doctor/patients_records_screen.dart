import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/patient_provider.dart';
import '../../widgets/common.dart';
import 'patient_medical_records_screen.dart';

/// Doctor's entry point into medical records: pick a patient, then view/
/// upload records for them.
class PatientsRecordsScreen extends StatefulWidget {
  const PatientsRecordsScreen({super.key});

  @override
  State<PatientsRecordsScreen> createState() => _PatientsRecordsScreenState();
}

class _PatientsRecordsScreenState extends State<PatientsRecordsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PatientProvider>().fetchAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PatientProvider>();
    final patients = provider.patients
        .where((p) => (p.fullName ?? '').toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Patient records')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search patients',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: provider.loading
                ? const LoadingView()
                : provider.error != null
                    ? ErrorView(
                        message: provider.error!,
                        onRetry: () => context.read<PatientProvider>().fetchAll())
                    : patients.isEmpty
                        ? const EmptyView(message: 'No patients found.', icon: Icons.people_outline)
                        : ListView.builder(
                            itemCount: patients.length,
                            itemBuilder: (ctx, i) {
                              final p = patients[i];
                              return ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                                title: Text(p.fullName ?? 'Patient #${p.id}'),
                                subtitle: Text(p.email ?? ''),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PatientMedicalRecordsScreen(patient: p),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
