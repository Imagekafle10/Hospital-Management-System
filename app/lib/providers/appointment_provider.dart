import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/appointment.dart';
import '../models/medical_record.dart';
import '../models/medicine.dart';
import '../models/prescription.dart';

class AppointmentProvider extends ChangeNotifier {
  List<Appointment> _appointments = [];
  final Map<int, List<Prescription>> _prescriptionsByAppointment = {};
  final Map<int, List<MedicalRecord>> _recordsByAppointment = {};
  bool _loading = false;
  bool _mutating = false;
  String? _error;

  List<Appointment> get appointments => _appointments;
  bool get loading => _loading;
  bool get mutating => _mutating;
  String? get error => _error;

  List<MedicalRecord> attachedRecordsFor(int appointmentId) =>
      _recordsByAppointment[appointmentId] ?? const [];

  Future<void> fetchAttachedRecords(int appointmentId) async {
    try {
      final json = await ApiClient.instance
          .get(ApiConstants.appointmentRecords(appointmentId)) as List;
      _recordsByAppointment[appointmentId] =
          json.cast<Map<String, dynamic>>().map(MedicalRecord.fromJson).toList();
      notifyListeners();
    } catch (_) {
      // non-critical: the section just stays empty
    }
  }

  List<Prescription> prescriptionsFor(int appointmentId) =>
      _prescriptionsByAppointment[appointmentId] ?? const [];

  /// Role-aware: Patient -> own bookings, Doctor -> own bookings,
  /// Admin -> everything. Backed by GET /api/appointments/mine.
  Future<void> fetchMine() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final json =
          await ApiClient.instance.get(ApiConstants.appointmentsMine) as List;
      _appointments = json
          .cast<Map<String, dynamic>>()
          .map(Appointment.fromJson)
          .toList()
        ..sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Admin only: GET /api/appointments (every appointment).
  Future<void> fetchAll() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final json =
          await ApiClient.instance.get(ApiConstants.appointments) as List;
      _appointments = json
          .cast<Map<String, dynamic>>()
          .map(Appointment.fromJson)
          .toList()
        ..sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> book({
    required int doctorId,
    required DateTime appointmentDate,
    String? reason,
    List<int> recordIds = const [],
  }) async {
    _mutating = true;
    _error = null;
    notifyListeners();
    try {
      await ApiClient.instance.post(ApiConstants.appointments, body: {
        'doctorId': doctorId,
        'appointmentDate': appointmentDate.toIso8601String(),
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (recordIds.isNotEmpty) 'recordIds': recordIds,
      });
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _mutating = false;
      notifyListeners();
    }
  }

  Future<bool> updateStatus(int id, String status, {String? notes}) async {
    _mutating = true;
    _error = null;
    notifyListeners();
    try {
      await ApiClient.instance.put(ApiConstants.appointmentStatus(id), body: {
        'status': status,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      // reflect locally without a full refetch
      final idx = _appointments.indexWhere((a) => a.id == id);
      if (idx != -1) {
        final old = _appointments[idx];
        _appointments[idx] = Appointment(
          id: old.id,
          patientId: old.patientId,
          doctorId: old.doctorId,
          appointmentDate: old.appointmentDate,
          reason: old.reason,
          status: status,
          notes: notes ?? old.notes,
          createdAt: old.createdAt,
          updatedAt: DateTime.now(),
          patientName: old.patientName,
          doctorName: old.doctorName,
          doctorSpecialization: old.doctorSpecialization,
          followUpRequired: old.followUpRequired,
          followUpDate: old.followUpDate,
          followUpNotes: old.followUpNotes,
        );
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _mutating = false;
      notifyListeners();
    }
  }

  /// Doctor: set or clear the follow-up after the checkup is Completed.
  /// Returns the updated appointment, or null on failure.
  Future<Appointment?> setFollowUp(
    int id, {
    required bool required,
    DateTime? date,
    String? notes,
  }) async {
    _mutating = true;
    _error = null;
    notifyListeners();
    try {
      final json = await ApiClient.instance.put(
        ApiConstants.appointmentFollowUp(id),
        body: {
          'required': required,
          if (required && date != null) 'date': date.toIso8601String(),
          if (required && notes != null && notes.isNotEmpty) 'notes': notes,
        },
      ) as Map<String, dynamic>;
      final updated = Appointment.fromJson(json);
      final idx = _appointments.indexWhere((a) => a.id == id);
      if (idx != -1) _appointments[idx] = updated;
      return updated;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _mutating = false;
      notifyListeners();
    }
  }

  /// Doctor: search the pharmacy catalog to suggest a medicine.
  Future<List<Medicine>> searchMedicines(String query) async {
    try {
      final uri = Uri.parse(ApiConstants.pharmacyMedicines)
          .replace(queryParameters: {if (query.trim().isNotEmpty) 'search': query.trim()});
      final json = await ApiClient.instance.get(uri.toString()) as List;
      return json
          .cast<Map<String, dynamic>>()
          .map(Medicine.fromJson)
          .where((m) => m.name.isNotEmpty)
          .take(15)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> addPrescription(
    int appointmentId, {
    required String medication,
    String? dosage,
    String? instructions,
  }) async {
    _mutating = true;
    _error = null;
    notifyListeners();
    try {
      await ApiClient.instance
          .post(ApiConstants.appointmentPrescriptions(appointmentId), body: {
        'medication': medication,
        if (dosage != null && dosage.isNotEmpty) 'dosage': dosage,
        if (instructions != null && instructions.isNotEmpty)
          'instructions': instructions,
      });
      await fetchPrescriptions(appointmentId);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _mutating = false;
      notifyListeners();
    }
  }

  Future<void> fetchPrescriptions(int appointmentId) async {
    try {
      final json = await ApiClient.instance
          .get(ApiConstants.appointmentPrescriptions(appointmentId)) as List;
      _prescriptionsByAppointment[appointmentId] = json
          .cast<Map<String, dynamic>>()
          .map(Prescription.fromJson)
          .toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
