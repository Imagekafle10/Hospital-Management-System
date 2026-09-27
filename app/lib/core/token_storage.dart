import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps persistent storage for the JWT issued by /api/auth/login|register.
///
/// On mobile (Android/iOS), this uses the OS keychain via
/// `flutter_secure_storage`. On web, it falls back to plain
/// `shared_preferences` instead: the browser's Web Crypto-backed
/// implementation of `flutter_secure_storage` can throw a DOMException
/// ("OperationError") if its encryption key and stored ciphertext ever
/// fall out of sync (e.g. after clearing site data, private-browsing
/// quirks, etc.), and browser storage isn't meaningfully "more secure"
/// encrypted anyway, since the key lives in the same origin's storage.
class TokenStorage {
  TokenStorage._();
  static final TokenStorage instance = TokenStorage._();

  final _secure = const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'auth_user_id';
  static const _fullNameKey = 'auth_full_name';
  static const _roleKey = 'auth_role';
  static const _expiryKey = 'auth_expires_at';

  Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      await _secure.write(key: key, value: value);
    }
  }

  Future<String?> _read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
    try {
      return await _secure.read(key: key);
    } catch (_) {
      // Corrupted/undecryptable entry (e.g. stale key material) -- treat
      // as absent rather than crashing the caller.
      return null;
    }
  }

  Future<void> saveSession({
    required String token,
    required int userId,
    required String fullName,
    required String role,
    required DateTime expiresAt,
  }) async {
    await Future.wait([
      _write(_tokenKey, token),
      _write(_userIdKey, userId.toString()),
      _write(_fullNameKey, fullName),
      _write(_roleKey, role),
      _write(_expiryKey, expiresAt.toIso8601String()),
    ]);
  }

  Future<String?> getToken() => _read(_tokenKey);

  Future<Map<String, String?>> readAll() async {
    return {
      'token': await _read(_tokenKey),
      'userId': await _read(_userIdKey),
      'fullName': await _read(_fullNameKey),
      'role': await _read(_roleKey),
      'expiresAt': await _read(_expiryKey),
    };
  }

  Future<void> clear() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_tokenKey),
        prefs.remove(_userIdKey),
        prefs.remove(_fullNameKey),
        prefs.remove(_roleKey),
        prefs.remove(_expiryKey),
      ]);
    } else {
      await _secure.deleteAll();
    }
  }
}
