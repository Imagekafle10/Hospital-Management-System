import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../core/token_storage.dart';
import '../models/auth_models.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AppSession? _session;
  AuthStatus _status = AuthStatus.unknown;
  bool _busy = false;
  String? _error;

  AppSession? get session => _session;
  AuthStatus get status => _status;
  bool get busy => _busy;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Call once at app startup to restore a persisted session.
  Future<void> restoreSession() async {
    final stored = await TokenStorage.instance.readAll();
    final token = stored['token'];
    final expiresAtRaw = stored['expiresAt'];
    if (token == null || expiresAtRaw == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    final expiresAt = DateTime.tryParse(expiresAtRaw);
    if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
      await TokenStorage.instance.clear();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    _session = AppSession(
      userId: int.parse(stored['userId']!),
      fullName: stored['fullName']!,
      role: stored['role']!,
      expiresAt: expiresAt,
    );
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _setBusy(true);
    try {
      final json = await ApiClient.instance.post(
        ApiConstants.login,
        auth: false,
        body: {'email': email, 'password': password},
      );
      await _applyAuthResponse(AuthResponse.fromJson(json));
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? phone,
    // doctor-only
    String? specialization,
    String? licenseNumber,
    double? consultationFee,
    List<int>? photoBytes,
    String? photoFileName,
    // patient-only
    DateTime? dateOfBirth,
    String? gender,
    String? bloodGroup,
    String? address,
  }) async {
    _setBusy(true);
    try {
      final body = <String, dynamic>{
        'fullName': fullName,
        'email': email,
        'password': password,
        'role': role,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      };
      if (role == AppRoles.doctor) {
        body['specialization'] = specialization;
        body['licenseNumber'] = licenseNumber;
        if (consultationFee != null) body['consultationFee'] = consultationFee;
      } else if (role == AppRoles.patient) {
        if (dateOfBirth != null) {
          body['dateOfBirth'] = dateOfBirth.toIso8601String();
        }
        if (gender != null && gender.isNotEmpty) body['gender'] = gender;
        if (bloodGroup != null && bloodGroup.isNotEmpty) {
          body['bloodGroup'] = bloodGroup;
        }
        if (address != null && address.isNotEmpty) body['address'] = address;
      }

      final json = await ApiClient.instance.post(
        ApiConstants.register,
        auth: false,
        body: body,
      );
      await _applyAuthResponse(AuthResponse.fromJson(json));

      // Doctor profile photo: uploaded with the new token before we leave the
      // register screen. A failed photo upload never blocks the registration.
      if (role == AppRoles.doctor && photoBytes != null && photoFileName != null) {
        try {
          await ApiClient.instance.postMultipart(
            ApiConstants.doctorMyPhoto,
            fields: {},
            fileBytes: photoBytes,
            fileName: photoFileName,
            fileFieldName: 'Photo',
          );
        } catch (_) {
          // doctor can re-upload from the Profile screen
        }
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _applyAuthResponse(AuthResponse res) async {
    await TokenStorage.instance.saveSession(
      token: res.token,
      userId: res.userId,
      fullName: res.fullName,
      role: res.role,
      expiresAt: res.expiresAt,
    );
    _session = AppSession(
      userId: res.userId,
      fullName: res.fullName,
      role: res.role,
      expiresAt: res.expiresAt,
    );
    _status = AuthStatus.authenticated;
    _error = null;
  }

  Future<void> logout() async {
    await TokenStorage.instance.clear();
    _session = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _error = null;
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}
