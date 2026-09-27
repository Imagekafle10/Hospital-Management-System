import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../providers/appointment_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/appointment_tile.dart';
import '../../widgets/common.dart';
import '../shared/appointment_detail_screen.dart';

class DoctorAppointmentsScreen extends StatefulWidget {
  const DoctorAppointmentsScreen({super.key});

  @override
  State<DoctorAppointmentsScreen> createState() => _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen> {
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppointmentProvider>().fetchMine();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppointmentProvider>();
    final list = _statusFilter == null
        ? provider.appointments
        : provider.appointments.where((a) => a.status == _statusFilter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My schedule')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _Chip(label: 'All', selected: _statusFilter == null,
                      onTap: () => setState(() => _statusFilter = null)),
                  ...AppointmentStatus.all.map((s) => _Chip(
                        label: s,
                        selected: _statusFilter == s,
                        onTap: () => setState(() => _statusFilter = s),
                      )),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.fetchMine(),
              child: _buildBody(provider, list),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppointmentProvider provider, List list) {
    if (provider.loading && provider.appointments.isEmpty) {
      return const LoadingView();
    }
    if (provider.error != null && provider.appointments.isEmpty) {
      return ErrorView(message: provider.error!, onRetry: () => provider.fetchMine());
    }
    if (list.isEmpty) {
      return const EmptyView(
        message: 'No appointments in this filter.',
        icon: Icons.event_available_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final a = list[i];
        return AppointmentTile(
          appointment: a,
          title: a.patientName ?? 'Patient',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AppointmentDetailScreen(appointment: a)),
            );
          },
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

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
