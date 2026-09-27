import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../widgets/common.dart';
import 'admin/admin_dashboard.dart';
import 'auth/login_screen.dart';
import 'doctor/doctor_dashboard.dart';
import 'patient/patient_dashboard.dart';

/// Watches [AuthProvider] and swaps between the login flow and the
/// correct role-specific dashboard, restoring a persisted session on
/// first launch.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: LoadingView());
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.authenticated:
        final role = auth.session?.role;
        switch (role) {
          case AppRoles.admin:
            return const AdminDashboard();
          case AppRoles.doctor:
            return const DoctorDashboard();
          case AppRoles.patient:
            return const PatientDashboard();
          default:
            return const LoginScreen();
        }
    }
  }
}
