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

  static const String _fallbackBaseUrl = 'http://localhost:5000';

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _fallbackBaseUrl,
  );

  static const String api = '$baseUrl/api';

  // Auth
  static const String register = '$api/auth/register';
  static const String login = '$api/auth/login';

  // Doctors
  static const String doctors = '$api/doctors';
  static String doctorById(int id) => '$api/doctors/$id';
  static const String doctorMe = '$api/doctors/me';

  // Patients
  static const String patients = '$api/patients';
  static String patientById(int id) => '$api/patients/$id';
  static const String patientMe = '$api/patients/me';

  // Appointments
  static const String appointments = '$api/appointments';
  static String appointmentById(int id) => '$api/appointments/$id';
  static const String appointmentsMine = '$api/appointments/mine';
  static String appointmentStatus(int id) => '$api/appointments/$id/status';
  static String appointmentPrescriptions(int id) =>
      '$api/appointments/$id/prescriptions';
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
