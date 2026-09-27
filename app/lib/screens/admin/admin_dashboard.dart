import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/doctor_provider.dart';
import '../../providers/patient_provider.dart';
import '../../widgets/common.dart';
import '../patient/patient_dashboard.dart'; // LogoutButton
import 'admin_appointments_screen.dart';
import 'admin_doctors_screen.dart';
import 'admin_patients_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _index = 0;

  final _screens = const [
    _AdminOverviewScreen(),
    AdminAppointmentsScreen(),
    AdminDoctorsScreen(),
    AdminPatientsScreen(),
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
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Overview'),
          NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note),
              label: 'Appointments'),
          NavigationDestination(
              icon: Icon(Icons.medical_services_outlined),
              selectedIcon: Icon(Icons.medical_services),
              label: 'Doctors'),
          NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Patients'),
        ],
      ),
    );
  }
}

class _AdminOverviewScreen extends StatefulWidget {
  const _AdminOverviewScreen();

  @override
  State<_AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<_AdminOverviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppointmentProvider>().fetchAll();
      context.read<DoctorProvider>().fetchDoctors();
      context.read<PatientProvider>().fetchAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthProvider>().session;
    final appointments = context.watch<AppointmentProvider>().appointments;
    final doctors = context.watch<DoctorProvider>().doctors;
    final patients = context.watch<PatientProvider>().patients;

    final pending = appointments.where((a) => a.status == AppointmentStatus.pending).length;
    final confirmed = appointments.where((a) => a.status == AppointmentStatus.confirmed).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin overview'), actions: const [LogoutButton()]),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Welcome, ${session?.fullName ?? 'Admin'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              StatTile(
                  label: 'Total appointments',
                  value: '${appointments.length}',
                  icon: Icons.event_note_outlined),
              StatTile(
                  label: 'Pending',
                  value: '$pending',
                  icon: Icons.hourglass_empty,
                  color: Colors.orange),
              StatTile(
                  label: 'Confirmed',
                  value: '$confirmed',
                  icon: Icons.check_circle_outline,
                  color: Colors.blue),
              StatTile(
                  label: 'Doctors',
                  value: '${doctors.length}',
                  icon: Icons.medical_services_outlined),
              StatTile(
                  label: 'Patients',
                  value: '${patients.length}',
                  icon: Icons.people_outline),
            ],
          ),
        ],
      ),
    );
  }
}
