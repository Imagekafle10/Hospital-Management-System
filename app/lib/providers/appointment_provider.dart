import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/appointment.dart';
import '../models/prescription.dart';

class AppointmentProvider extends ChangeNotifier {
  List<Appointment> _appointments = [];
  final Map<int, List<Prescription>> _prescriptionsByAppointment = {};
  bool _loading = false;
  bool _mutating = false;
  String? _error;

  List<Appointment> get appointments => _appointments;
  bool get loading => _loading;
  bool get mutating => _mutating;
  String? get error => _error;

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
  }) async {
    _mutating = true;
    _error = null;
    notifyListeners();
    try {
      await ApiClient.instance.post(ApiConstants.appointments, body: {
        'doctorId': doctorId,
        'appointmentDate': appointmentDate.toIso8601String(),
        if (reason != null && reason.isNotEmpty) 'reason': reason,
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
