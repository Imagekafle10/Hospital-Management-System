import 'package:flutter/foundation.dart';

/// Central place to point the app at your backend.
///
/// The ASP.NET Core API runs on HTTPS by default (see Program.cs ->
/// app.UseHttpsRedirection()). Update this to match how you're running it:
///
///   - Android emulator hitting a host machine running `dotnet run`:
///       10.0.2.2 is the emulator's alias for the host's localhost.
///   - iOS simulator:
///       localhost / 127.0.0.1 works directly.
///   - Physical device:
///       use your machine's LAN IP (e.g. 192.168.1.23) and make sure the
///       API is bound to that interface (Kestrel binds to all interfaces
///       by default for `dotnet run` unless you've restricted it).
///   - Deployed API:
///       use the real https:// host.
///
/// The easiest way to override this without editing code is to run with:
///   flutter run --dart-define=API_BASE_URL=https://192.168.1.23:5001
class ApiConstants {
  ApiConstants._();

  /// Picks the API address automatically:
  ///  1. --dart-define=API_BASE_URL=... always wins (use this for a real phone app).
  ///  2. Flutter WEB: uses the same host the page was opened from, port 5000.
  ///     So if you open http://192.168.1.23:8080 on your phone, the API becomes
  ///     http://192.168.1.23:5000 (no more "localhost" pointing at the phone).
  ///  3. Android emulator: 10.0.2.2 (the emulator's alias for your PC).
  ///  4. Everything else: localhost.
  static const String _override = String.fromEnvironment('API_BASE_URL');
  static const int _apiPort = 5000;

  static final String baseUrl = _resolveBaseUrl();

  static String _resolveBaseUrl() {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://${Uri.base.host}:$_apiPort';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$_apiPort';
    }
    return 'http://localhost:$_apiPort';
  }

  static final String api = '$baseUrl/api';

  // Auth
  static final String register = '$api/auth/register';
  static final String login = '$api/auth/login';

  // Doctors
  static final String doctors = '$api/doctors';
  static String doctorById(int id) => '$api/doctors/$id';
  static final String doctorMe = '$api/doctors/me';

  // Patients
  static final String patients = '$api/patients';
  static String patientById(int id) => '$api/patients/$id';
  static final String patientMe = '$api/patients/me';

  // Appointments
  static final String appointments = '$api/appointments';
  static String appointmentById(int id) => '$api/appointments/$id';
  static final String appointmentsMine = '$api/appointments/mine';
  static String appointmentStatus(int id) => '$api/appointments/$id/status';
  static String appointmentPrescriptions(int id) =>
      '$api/appointments/$id/prescriptions';

  // Admissions
  static final String admissions = '$api/admissions';
  static String admissionById(int id) => '$api/admissions/$id';
  static final String admissionsActive = '$api/admissions/active';
  static final String admissionsMine = '$api/admissions/mine';
  static String admissionsByPatient(int patientId) =>
      '$api/admissions/patient/$patientId';
  static String admissionDischarge(int id) => '$api/admissions/$id/discharge';
  static String admissionTransferBed(int id) =>
      '$api/admissions/$id/transfer-bed';

  // Wards & beds
  static final String wards = '$api/wards';
  static String bedsByWard(int wardId) => '$api/wards/$wardId/beds';
  static final String beds = '$api/beds';
  static String bedsWithStatus(String status) =>
      '$api/beds?status=${Uri.encodeQueryComponent(status)}';

  // Medical records
  static final String medicalRecords = '$api/medicalrecords';
  static String medicalRecordById(int id) => '$api/medicalrecords/$id';
  static String medicalRecordDownload(int id) =>
      '$api/medicalrecords/$id/download';
  static final String medicalRecordsMine = '$api/medicalrecords/mine';
  static String medicalRecordsByPatient(int patientId) =>
      '$api/medicalrecords/patient/$patientId';

  // Payments
  static final String paymentInitiate = '$api/payments/initiate';
  static String paymentById(int id) => '$api/payments/$id';
  static String paymentByAppointment(int appointmentId) =>
      '$api/payments/appointment/$appointmentId';
  static String paymentCollectCod(int id) => '$api/payments/$id/collect';
  static final String paymentsMine = '$api/payments/mine';
  static final String khaltiVerify = '$api/payments/khalti/verify';
}

class AdmissionStatus {
  static const String admitted = 'Admitted';
  static const String discharged = 'Discharged';
}

class MedicalRecordType {
  static const String labReport = 'LabReport';
  static const String prescription = 'Prescription';
  static const String diagnosis = 'Diagnosis';
  static const String imaging = 'Imaging';
  static const String other = 'Other';

  static const List<String> all = [
    labReport,
    prescription,
    diagnosis,
    imaging,
    other,
  ];
}

class PaymentMethod {
  static const String esewa = 'Esewa';
  static const String khalti = 'Khalti';
  static const String cod = 'COD';

  static const List<String> all = [esewa, khalti, cod];
}

class AppRoles {
  static const String admin = 'Admin';
  static const String doctor = 'Doctor';
  static const String patient = 'Patient';
}

class AppointmentStatus {
  static const String pending = 'Pending';
  static const String confirmed = 'Confirmed';
  static const String completed = 'Completed';
  static const String cancelled = 'Cancelled';

  static const List<String> all = [pending, confirmed, completed, cancelled];
}

const List<String> kSpecializations = [
  'Cardiology',
  'Dermatology',
  'Endocrinology',
  'ENT',
  'Gastroenterology',
  'General Medicine',
  'General Surgery',
  'Gynecology',
  'Neurology',
  'Oncology',
  'Ophthalmology',
  'Orthopedics',
  'Pediatrics',
  'Psychiatry',
  'Pulmonology',
  'Radiology',
  'Urology',
];
