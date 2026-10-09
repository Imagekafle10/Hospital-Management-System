import 'package:flutter/material.dart';
import '../../widgets/doctor_avatar.dart';
import 'package:provider/provider.dart';
import '../../providers/doctor_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class AdminDoctorsScreen extends StatefulWidget {
  const AdminDoctorsScreen({super.key});

  @override
  State<AdminDoctorsScreen> createState() => _AdminDoctorsScreenState();
}

class _AdminDoctorsScreenState extends State<AdminDoctorsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DoctorProvider>().fetchDoctors();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DoctorProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Doctors')),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchDoctors(),
        child: _buildBody(provider),
      ),
    );
  }

  Widget _buildBody(DoctorProvider provider) {
    if (provider.loading && provider.doctors.isEmpty) return const LoadingView();
    if (provider.error != null && provider.doctors.isEmpty) {
      return ErrorView(message: provider.error!, onRetry: () => provider.fetchDoctors());
    }
    if (provider.doctors.isEmpty) {
      return const EmptyView(message: 'No doctors registered yet.', icon: Icons.medical_services_outlined);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: provider.doctors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final d = provider.doctors[i];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: DoctorAvatar(doctor: d, radius: 22),
            title: Text('Dr. ${d.fullName ?? 'Unknown'}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${d.specialization} · ${d.yearsOfExperience} yrs · \$${d.consultationFee.toStringAsFixed(0)}'),
          ),
        );
      },
    );
  }
}
