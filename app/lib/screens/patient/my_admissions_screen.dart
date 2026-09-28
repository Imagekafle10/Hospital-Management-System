import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/admission_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class MyAdmissionsScreen extends StatefulWidget {
  const MyAdmissionsScreen({super.key});

  @override
  State<MyAdmissionsScreen> createState() => _MyAdmissionsScreenState();
}

class _MyAdmissionsScreenState extends State<MyAdmissionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() => context.read<AdmissionProvider>().fetchMine();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdmissionProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('My hospital stays')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: provider.loading
            ? const LoadingView()
            : provider.error != null
                ? ErrorView(message: provider.error!, onRetry: _refresh)
                : provider.admissions.isEmpty
                    ? const EmptyView(
                        message: 'You have no admission history.',
                        icon: Icons.local_hospital_outlined)
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.admissions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final a = provider.admissions[i];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Bed ${a.bedNumber ?? '-'} · ${a.wardName ?? '-'}',
                                          style: const TextStyle(fontWeight: FontWeight.w700)),
                                      StatusChip(status: a.isActive ? 'Confirmed' : 'Completed'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Admitted: ${DateFormat.yMMMd().format(a.admissionDate)}',
                                      style: const TextStyle(color: AppColors.textSecondary)),
                                  if (a.dischargeDate != null)
                                    Text('Discharged: ${DateFormat.yMMMd().format(a.dischargeDate!)}',
                                        style: const TextStyle(color: AppColors.textSecondary)),
                                  if (a.doctorName != null)
                                    Text('Attending: Dr. ${a.doctorName}',
                                        style: const TextStyle(color: AppColors.textSecondary)),
                                  if (a.reasonForAdmission.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(a.reasonForAdmission),
                                  ],
                                  if (a.dischargeSummary != null && a.dischargeSummary!.isNotEmpty) ...[
                                    const Divider(height: 20),
                                    const Text('Discharge summary',
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text(a.dischargeSummary!),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
