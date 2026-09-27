import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/doctor.dart';
import '../../providers/doctor_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'book_appointment_screen.dart';
import 'patient_dashboard.dart';

class DoctorsListScreen extends StatefulWidget {
  const DoctorsListScreen({super.key});

  @override
  State<DoctorsListScreen> createState() => _DoctorsListScreenState();
}

class _DoctorsListScreenState extends State<DoctorsListScreen> {
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
      appBar: AppBar(title: const Text('Find a doctor'), actions: const [LogoutButton()]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: provider.specializationFilter == null ||
                        provider.specializationFilter!.isEmpty,
                    onTap: () => provider.fetchDoctors(),
                  ),
                  ...kSpecializations.map((s) => _FilterChip(
                        label: s,
                        selected: provider.specializationFilter == s,
                        onTap: () => provider.fetchDoctors(specialization: s),
                      )),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.fetchDoctors(
                specialization: provider.specializationFilter,
              ),
              child: _buildBody(provider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(DoctorProvider provider) {
    if (provider.loading && provider.doctors.isEmpty) {
      return const LoadingView();
    }
    if (provider.error != null && provider.doctors.isEmpty) {
      return ErrorView(
        message: provider.error!,
        onRetry: () => provider.fetchDoctors(),
      );
    }
    if (provider.doctors.isEmpty) {
      return const EmptyView(
        message: 'No doctors found for this specialization.',
        icon: Icons.medical_services_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: provider.doctors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _DoctorCard(doctor: provider.doctors[i]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFDCE6E5)),
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final Doctor doctor;
  const _DoctorCard({required this.doctor});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BookAppointmentScreen(doctor: doctor)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  (doctor.fullName?.isNotEmpty == true ? doctor.fullName![0] : '?')
                      .toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dr. ${doctor.fullName ?? 'Unknown'}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(doctor.specialization,
                        style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.workspace_premium_outlined,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('${doctor.yearsOfExperience} yrs exp',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(width: 12),
                        const Icon(Icons.payments_outlined,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('\$${doctor.consultationFee.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
