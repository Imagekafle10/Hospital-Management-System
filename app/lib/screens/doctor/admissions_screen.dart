import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/admission.dart';
import '../../providers/admission_provider.dart';
import '../../providers/ward_bed_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'admit_patient_screen.dart';

class AdmissionsScreen extends StatefulWidget {
  const AdmissionsScreen({super.key});

  @override
  State<AdmissionsScreen> createState() => _AdmissionsScreenState();
}

class _AdmissionsScreenState extends State<AdmissionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() => context.read<AdmissionProvider>().fetchActive();

  Future<void> _admitNew() async {
    final admitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AdmitPatientScreen()),
    );
    if (admitted == true) _refresh();
  }

  Future<void> _discharge(Admission a) async {
    final summaryCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Discharge ${a.patientName ?? 'patient'}?'),
        content: TextField(
          controller: summaryCtrl,
          maxLines: 3,
          decoration:
              const InputDecoration(labelText: 'Discharge summary (optional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discharge')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<AdmissionProvider>();
    final ok = await provider.discharge(a.id, dischargeSummary: summaryCtrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Patient discharged' : (provider.error ?? 'Failed'))),
    );
  }

  Future<void> _transferBed(Admission a) async {
    final wardBedProvider = context.read<WardBedProvider>();
    await wardBedProvider.fetchAvailableBeds();
    if (!mounted) return;
    final beds = wardBedProvider.availableBeds;
    if (beds.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No available beds to transfer to')));
      return;
    }
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Transfer to bed', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            ...beds.map((b) => ListTile(
                  leading: const Icon(Icons.bed_outlined),
                  title: Text('Bed ${b.bedNumber}'),
                  subtitle: Text('${b.wardName ?? ''} · ${b.wardType ?? ''}'),
                  onTap: () => Navigator.pop(ctx, b.id),
                )),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final provider = context.read<AdmissionProvider>();
    final ok = await provider.transferBed(a.id, selected);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Bed transferred' : (provider.error ?? 'Failed'))),
    );
    if (ok) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdmissionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admissions'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _admitNew, tooltip: 'Admit patient'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: provider.loading
            ? const LoadingView()
            : provider.error != null
                ? ErrorView(message: provider.error!, onRetry: _refresh)
                : provider.admissions.isEmpty
                    ? const EmptyView(
                        message: 'No patients currently admitted.',
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
                                      Expanded(
                                        child: Text(a.patientName ?? 'Patient #${a.patientId}',
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                      ),
                                      const StatusChip(status: 'Confirmed'),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Bed ${a.bedNumber ?? '-'} · ${a.wardName ?? '-'}',
                                      style: const TextStyle(color: AppColors.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text('Admitted ${DateFormat.yMMMd().format(a.admissionDate)}',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                  if (a.reasonForAdmission.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(a.reasonForAdmission),
                                  ],
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: provider.mutating ? null : () => _transferBed(a),
                                        icon: const Icon(Icons.swap_horiz, size: 18),
                                        label: const Text('Transfer bed'),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: provider.mutating ? null : () => _discharge(a),
                                        icon: const Icon(Icons.logout, size: 18),
                                        label: const Text('Discharge'),
                                      ),
                                    ],
                                  ),
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
