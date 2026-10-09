import 'dart:async';
import 'dart:convert';
import 'constants.dart';
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

  dynamic _handle(http.Response res, {bool auth = true}) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return _decode(res);
    }
    if (res.statusCode == 401) {
      // Login/register calls are sent without a token (auth: false). A 401
      // there means wrong credentials, NOT an expired session, so show the
      // server's message ("Invalid email or password.").
      if (!auth) {
        final msg = _extractError(res);
        throw ApiException(
            401,
            msg.startsWith('Request failed')
                ? 'Invalid email or password.'
                : msg);
      }
      throw ApiException(401, 'Session expired. Please log in again.');
    }
    throw ApiException(res.statusCode, _extractError(res));
  }

  /// Wraps every request so a dead/unreachable server gives a clear message
  /// (with the address the app is trying) instead of a raw socket exception.
  Future<T> _guard<T>(Future<T> Function() send) async {
    try {
      return await send().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ApiException(0,
          'Server not responding at ${ApiConstants.baseUrl}. Is the API running, and are phone and PC on the same Wi-Fi?');
    } on http.ClientException {
      throw ApiException(0,
          'Cannot reach the server at ${ApiConstants.baseUrl}. Check the API is running on 0.0.0.0:5000, the firewall allows port 5000, and the IP is correct.');
    } on ApiException {
      rethrow;
    } catch (e) {
      final text = e.toString();
      if (text.contains('SocketException') || text.contains('Connection') ) {
        throw ApiException(0,
            'Cannot reach the server at ${ApiConstants.baseUrl}. Check the API is running, firewall port 5000, and the IP.');
      }
      rethrow;
    }
  }

  Future<dynamic> get(String url, {bool auth = true}) => _guard(() async {
        final res = await http.get(Uri.parse(url), headers: await _headers(auth: auth));
        return _handle(res, auth: auth);
      });

  Future<dynamic> post(String url, {Object? body, bool auth = true}) => _guard(() async {
        final res = await http.post(
          Uri.parse(url),
          headers: await _headers(auth: auth),
          body: body == null ? null : jsonEncode(body),
        );
        return _handle(res, auth: auth);
      });

  Future<dynamic> put(String url, {Object? body, bool auth = true}) => _guard(() async {
        final res = await http.put(
          Uri.parse(url),
          headers: await _headers(auth: auth),
          body: body == null ? null : jsonEncode(body),
        );
        return _handle(res, auth: auth);
      });

  Future<dynamic> delete(String url, {bool auth = true}) => _guard(() async {
        final res = await http.delete(Uri.parse(url), headers: await _headers(auth: auth));
        return _handle(res, auth: auth);
      });

  /// Multipart upload (e.g. medical record files). [fields] are plain form
  /// fields; [fileBytes]/[fileName] are sent under the given [fileFieldName].
  Future<dynamic> postMultipart(
    String url, {
    required Map<String, String> fields,
    required List<int> fileBytes,
    required String fileName,
    String fileFieldName = 'File',
    bool auth = true,
  }) => _guard(() async {
    final request = http.MultipartRequest('POST', Uri.parse(url));
    final headers = await _headers(auth: auth);
    headers.remove('Content-Type'); // let http set the multipart boundary
    request.headers.addAll(headers);
    request.fields.addAll(fields);
    request.files.add(http.MultipartFile.fromBytes(
      fileFieldName,
      fileBytes,
      filename: fileName,
    ));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res, auth: auth);
  });
}
