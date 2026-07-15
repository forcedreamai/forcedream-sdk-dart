import 'dart:convert';
import 'package:http/http.dart' as http;

/// Uses package:http (the standard, dart-lang-maintained HTTP client) rather than dart:io's
/// HttpClient, since dart:io is unavailable on Dart/Flutter web targets -- this SDK is meant
/// to work across mobile, desktop, and web Flutter apps, not just native/VM Dart.
class HttpResult {
  final int status;
  final Map<String, dynamic> json;
  HttpResult(this.status, this.json);
}

class Http {
  Http._();

  static Future<Map<String, dynamic>> get(String url, {String? bearer}) async {
    final headers = <String, String>{};
    if (bearer != null) headers['Authorization'] = 'Bearer $bearer';
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('GET $url -> HTTP ${response.statusCode}: ${response.body}');
    }
    return _safeDecode(response.body);
  }

  static Future<Map<String, dynamic>> post(String url, Map<String, dynamic> body, {String? bearer}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (bearer != null) headers['Authorization'] = 'Bearer $bearer';
    final response = await http.post(Uri.parse(url), headers: headers, body: jsonEncode(body));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('POST $url -> HTTP ${response.statusCode}: ${response.body}');
    }
    return _safeDecode(response.body);
  }

  /// Returns the real status alongside the body without throwing on a non-2xx status --
  /// used where the caller needs to inspect the real status itself (invoke's 401 handling,
  /// delete-agent's real 404/403/200), matching the {status, json} pattern already used in
  /// several other SDKs tonight.
  static Future<HttpResult> getResult(String url, {String? bearer}) async {
    final headers = <String, String>{};
    if (bearer != null) headers['Authorization'] = 'Bearer $bearer';
    final response = await http.get(Uri.parse(url), headers: headers);
    return HttpResult(response.statusCode, _safeDecode(response.body));
  }

  static Future<HttpResult> postResult(String url, Map<String, dynamic> body, {String? bearer}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (bearer != null) headers['Authorization'] = 'Bearer $bearer';
    final response = await http.post(Uri.parse(url), headers: headers, body: jsonEncode(body));
    return HttpResult(response.statusCode, _safeDecode(response.body));
  }

  static Map<String, dynamic> _safeDecode(String body) {
    if (body.isEmpty) return {};
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }
}
