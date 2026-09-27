import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_storage.dart';

/// Thrown for any non-2xx response. Carries the status code and a
/// best-effort human-readable message extracted from the API's body
/// (the backend returns plain strings like `BadRequest("...")` or
/// ASP.NET's default ProblemDetails/ModelState JSON shape).
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await TokenStorage.instance.getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _decode(http.Response res) {
    if (res.body.isEmpty) return null;
    try {
      return jsonDecode(res.body);
    } catch (_) {
      return res.body;
    }
  }

  String _extractError(http.Response res) {
    final body = _decode(res);
    if (body == null) return 'Request failed (${res.statusCode}).';
    if (body is String) return body;
    if (body is Map) {
      // ASP.NET ModelState validation errors: { errors: { Field: [msgs] } }
      if (body['errors'] is Map) {
        final errors = (body['errors'] as Map).values
            .expand((v) => v is List ? v : [v])
            .join('\n');
        if (errors.isNotEmpty) return errors;
      }
      if (body['title'] != null) return body['title'].toString();
      if (body['message'] != null) return body['message'].toString();
    }
    return 'Request failed (${res.statusCode}).';
  }

  dynamic _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return _decode(res);
    }
    if (res.statusCode == 401) {
      throw ApiException(401, 'Session expired. Please log in again.');
    }
    throw ApiException(res.statusCode, _extractError(res));
  }

  Future<dynamic> get(String url, {bool auth = true}) async {
    final res = await http.get(Uri.parse(url), headers: await _headers(auth: auth));
    return _handle(res);
  }

  Future<dynamic> post(String url, {Object? body, bool auth = true}) async {
    final res = await http.post(
      Uri.parse(url),
      headers: await _headers(auth: auth),
      body: body == null ? null : jsonEncode(body),
    );
    return _handle(res);
  }

  Future<dynamic> put(String url, {Object? body, bool auth = true}) async {
    final res = await http.put(
      Uri.parse(url),
      headers: await _headers(auth: auth),
      body: body == null ? null : jsonEncode(body),
    );
    return _handle(res);
  }
}
