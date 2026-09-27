import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/doctor.dart';

class DoctorProvider extends ChangeNotifier {
  List<Doctor> _doctors = [];
  Doctor? _myProfile;
  bool _loading = false;
  String? _error;
  String? _specializationFilter;

  List<Doctor> get doctors => _doctors;
  Doctor? get myProfile => _myProfile;
  bool get loading => _loading;
  String? get error => _error;
  String? get specializationFilter => _specializationFilter;

  Future<void> fetchDoctors({String? specialization}) async {
    _loading = true;
    _error = null;
    _specializationFilter = specialization;
    notifyListeners();
    try {
      final url = specialization == null || specialization.isEmpty
          ? ApiConstants.doctors
          : '${ApiConstants.doctors}?specialization=${Uri.encodeQueryComponent(specialization)}';
      final json = await ApiClient.instance.get(url) as List;
      _doctors = json
          .cast<Map<String, dynamic>>()
          .map(Doctor.fromJson)
          .toList();
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
      final json = await ApiClient.instance.get(ApiConstants.doctorMe);
      _myProfile = Doctor.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> updateMyProfile({
    String? specialization,
    double? consultationFee,
    int? yearsOfExperience,
    String? availableFrom, // "HH:mm:ss"
    String? availableTo,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await ApiClient.instance.put(ApiConstants.doctorMe, body: {
        if (specialization != null) 'specialization': specialization,
        if (consultationFee != null) 'consultationFee': consultationFee,
        if (yearsOfExperience != null) 'yearsOfExperience': yearsOfExperience,
        if (availableFrom != null) 'availableFrom': availableFrom,
        if (availableTo != null) 'availableTo': availableTo,
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
