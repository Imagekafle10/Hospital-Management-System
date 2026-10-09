import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/admission.dart';

class AdmissionProvider extends ChangeNotifier {
  List<Admission> _admissions = [];
  bool _loading = false;
  bool _mutating = false;
  String? _error;

  List<Admission> get admissions => _admissions;
  bool get loading => _loading;
  bool get mutating => _mutating;
  String? get error => _error;

  /// Doctor/Admin: every currently-admitted patient hospital-wide.
  Future<void> fetchActive() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final json =
          await ApiClient.instance.get(ApiConstants.admissionsActive) as List;
      _admissions =
          json.cast<Map<String, dynamic>>().map(Admission.fromJson).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Patient: their own admission history.
  Future<void> fetchMine() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final json =
          await ApiClient.instance.get(ApiConstants.admissionsMine) as List;
      _admissions = json
          .cast<Map<String, dynamic>>()
          .map(Admission.fromJson)
          .toList()
        ..sort((a, b) => b.admissionDate.compareTo(a.admissionDate));
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> admit({
    required int patientId,
    required int bedId,
    required String reasonForAdmission,
    DateTime? expectedDischargeDate,
  }) async {
    _mutating = true;
    _error = null;
    notifyListeners();
    try {
      await ApiClient.instance.post(ApiConstants.admissions, body: {
        'patientId': patientId,
        'bedId': bedId,
        'reasonForAdmission': reasonForAdmission,
        if (expectedDischargeDate != null)
          'expectedDischargeDate': expectedDischargeDate.toIso8601String(),
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

  Future<bool> discharge(int id, {String? dischargeSummary}) async {
    _mutating = true;
    _error = null;
    notifyListeners();
    try {
      await ApiClient.instance.put(ApiConstants.admissionDischarge(id), body: {
        if (dischargeSummary != null && dischargeSummary.isNotEmpty)
          'dischargeSummary': dischargeSummary,
      });
      _admissions.removeWhere((a) => a.id == id);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _mutating = false;
      notifyListeners();
    }
  }

  Future<bool> transferBed(int id, int newBedId) async {
    _mutating = true;
    _error = null;
    notifyListeners();
    try {
      await ApiClient.instance
          .put(ApiConstants.admissionTransferBed(id), body: {
        'newBedId': newBedId,
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
}
