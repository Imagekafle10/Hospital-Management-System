import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/medical_record.dart';

class MedicalRecordProvider extends ChangeNotifier {
  List<MedicalRecord> _records = [];
  bool _loading = false;
  bool _mutating = false;
  String? _error;

  List<MedicalRecord> get records => _records;
  bool get loading => _loading;
  bool get mutating => _mutating;
  String? get error => _error;

  /// Patient: their own uploaded/received records.
  Future<void> fetchMine() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final json = await ApiClient.instance
          .get(ApiConstants.medicalRecordsMine) as List;
      _records = json
          .cast<Map<String, dynamic>>()
          .map(MedicalRecord.fromJson)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Doctor: records for a patient they have treated.
  Future<void> fetchForPatient(int patientId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final json = await ApiClient.instance
          .get(ApiConstants.medicalRecordsByPatient(patientId)) as List;
      _records = json
          .cast<Map<String, dynamic>>()
          .map(MedicalRecord.fromJson)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Uploads a record. Pass [patientId] when a doctor uploads on a patient's
  /// behalf; leave null when a patient uploads their own.
  Future<bool> upload({
    int? patientId,
    int? appointmentId,
    required String recordType,
    required String title,
    String? description,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    _mutating = true;
    _error = null;
    notifyListeners();
    try {
      await ApiClient.instance.postMultipart(
        ApiConstants.medicalRecords,
        fields: {
          if (patientId != null) 'PatientId': patientId.toString(),
          if (appointmentId != null)
            'AppointmentId': appointmentId.toString(),
          'RecordType': recordType,
          'Title': title,
          if (description != null && description.isNotEmpty)
            'Description': description,
        },
        fileBytes: fileBytes,
        fileName: fileName,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _mutating = false;
      notifyListeners();
    }
  }

  Future<bool> delete(int id) async {
    _mutating = true;
    _error = null;
    notifyListeners();
    try {
      await ApiClient.instance.delete(ApiConstants.medicalRecordById(id));
      _records.removeWhere((r) => r.id == id);
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
