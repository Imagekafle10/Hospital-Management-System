import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/appointment_provider.dart';
import '../../widgets/appointment_tile.dart';
import '../../widgets/common.dart';
import '../shared/appointment_detail_screen.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
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

    return Scaffold(
      appBar: AppBar(title: const Text('My appointments')),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchMine(),
        child: _buildBody(provider),
      ),
    );
  }

  Widget _buildBody(AppointmentProvider provider) {
    if (provider.loading && provider.appointments.isEmpty) {
      return const LoadingView();
    }
    if (provider.error != null && provider.appointments.isEmpty) {
      return ErrorView(message: provider.error!, onRetry: () => provider.fetchMine());
    }
    if (provider.appointments.isEmpty) {
      return const EmptyView(
        message: "You haven't booked any appointments yet.",
        icon: Icons.event_busy_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: provider.appointments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final a = provider.appointments[i];
        return AppointmentTile(
          appointment: a,
          title: 'Dr. ${a.doctorName ?? 'Doctor'}',
          subtitleOverride: a.doctorSpecialization,
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
