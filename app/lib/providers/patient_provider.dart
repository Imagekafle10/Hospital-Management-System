import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/patient.dart';

class PatientProvider extends ChangeNotifier {
  List<Patient> _patients = [];
  Patient? _myProfile;
  bool _loading = false;
  String? _error;

  List<Patient> get patients => _patients;
  Patient? get myProfile => _myProfile;
  bool get loading => _loading;
  String? get error => _error;

  /// Admin or Doctor: list every patient.
  Future<void> fetchAll() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final json = await ApiClient.instance.get(ApiConstants.patients) as List;
      _patients =
          json.cast<Map<String, dynamic>>().map(Patient.fromJson).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMyProfile() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final json = await ApiClient.instance.get(ApiConstants.patientMe);
      _myProfile = Patient.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> updateMyProfile({
    DateTime? dateOfBirth,
    String? gender,
    String? bloodGroup,
    String? address,
    String? emergencyContact,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await ApiClient.instance.put(ApiConstants.patientMe, body: {
        if (dateOfBirth != null)
          'dateOfBirth': dateOfBirth.toIso8601String(),
        if (gender != null) 'gender': gender,
        if (bloodGroup != null) 'bloodGroup': bloodGroup,
        if (address != null) 'address': address,
        if (emergencyContact != null) 'emergencyContact': emergencyContact,
      });
      await fetchMyProfile();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
