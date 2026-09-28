import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/admission_provider.dart';
import 'providers/appointment_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/doctor_provider.dart';
import 'providers/medical_record_provider.dart';
import 'providers/patient_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/ward_bed_provider.dart';
import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const HospitalMgmtApp());
}

class HospitalMgmtApp extends StatelessWidget {
  const HospitalMgmtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DoctorProvider()),
        ChangeNotifierProvider(create: (_) => PatientProvider()),
        ChangeNotifierProvider(create: (_) => AppointmentProvider()),
        ChangeNotifierProvider(create: (_) => AdmissionProvider()),
        ChangeNotifierProvider(create: (_) => WardBedProvider()),
        ChangeNotifierProvider(create: (_) => MedicalRecordProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
      ],
      child: MaterialApp(
        title: 'MediCare HMS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AuthGate(),
      ),
    );
  }
}
