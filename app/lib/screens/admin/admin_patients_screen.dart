import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/patient_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class AdminPatientsScreen extends StatefulWidget {
  const AdminPatientsScreen({super.key});

  @override
  State<AdminPatientsScreen> createState() => _AdminPatientsScreenState();
}

class _AdminPatientsScreenState extends State<AdminPatientsScreen> {
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

    return Scaffold(
      appBar: AppBar(title: const Text('Patients')),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchAll(),
        child: _buildBody(provider),
      ),
    );
  }

  Widget _buildBody(PatientProvider provider) {
    if (provider.loading && provider.patients.isEmpty) return const LoadingView();
    if (provider.error != null && provider.patients.isEmpty) {
      return ErrorView(message: provider.error!, onRetry: () => provider.fetchAll());
    }
    if (provider.patients.isEmpty) {
      return const EmptyView(message: 'No patients registered yet.', icon: Icons.people_outline);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: provider.patients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final p = provider.patients[i];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                (p.fullName?.isNotEmpty == true ? p.fullName![0] : '?').toUpperCase(),
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800),
              ),
            ),
            title: Text(p.fullName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              [
                if (p.email != null) p.email!,
                if (p.bloodGroup != null) p.bloodGroup!,
              ].join(' · '),
            ),
          ),
        );
      },
    );
  }
}
