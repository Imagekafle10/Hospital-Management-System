import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'doctors_list_screen.dart';
import 'medical_records_screen.dart';
import 'my_appointments_screen.dart';
import 'patient_profile_screen.dart';
import 'payments_screen.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _index = 0;

  final _screens = const [
    DoctorsListScreen(),
    MyAppointmentsScreen(),
    MedicalRecordsScreen(),
    PaymentsScreen(),
    PatientProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.medical_services_outlined),
              selectedIcon: Icon(Icons.medical_services),
              label: 'Doctors'),
          NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note),
              label: 'Appointments'),
          NavigationDestination(
              icon: Icon(Icons.folder_shared_outlined),
              selectedIcon: Icon(Icons.folder_shared),
              label: 'Records'),
          NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments),
              label: 'Payments'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}

/// Simple sign-out button used in app bars across role dashboards.
class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Log out',
      icon: const Icon(Icons.logout),
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Log out?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          await context.read<AuthProvider>().logout();
        }
      },
    );
  }
}
