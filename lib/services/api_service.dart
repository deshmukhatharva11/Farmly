import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:farmly/core/api_config.dart';
import 'package:farmly/services/auth_service.dart';

/// Service for all authenticated API calls (profile, scans, etc).
class ApiService {
  final AuthService _authService;

  ApiService(this._authService);

  /// Get authorization headers with JWT token.
  Future<Map<String, String>> _authHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  /// Generic GET request with auth.
  Future<Map<String, dynamic>> _get(String endpoint) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}$endpoint'), headers: headers)
          .timeout(Duration(seconds: ApiConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        await _authService.logout();
        return {'error': 'unauthorized'};
      } else {
        return {'error': 'Request failed with status ${response.statusCode}'};
      }
    } catch (e) {
      return {'error': 'Connection error: $e'};
    }
  }

  /// Generic POST request with auth.
  Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: ApiConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        await _authService.logout();
        return {'error': 'unauthorized'};
      } else {
        return {'error': 'Request failed with status ${response.statusCode}'};
      }
    } catch (e) {
      return {'error': 'Connection error: $e'};
    }
  }

  /// Generic PUT request with auth.
  Future<Map<String, dynamic>> _put(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .put(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: ApiConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        await _authService.logout();
        return {'error': 'unauthorized'};
      } else {
        return {'error': 'Request failed with status ${response.statusCode}'};
      }
    } catch (e) {
      return {'error': 'Connection error: $e'};
    }
  }

  // ─── User Profile ────────────────────────────────────────
  Future<Map<String, dynamic>> fetchProfile() async {
    return _get(ApiConfig.userProfile);
  }

  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? location,
    String? preferredLanguage,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (location != null) body['location'] = location;
    if (preferredLanguage != null) body['preferred_language'] = preferredLanguage;
    return _put(ApiConfig.userProfile, body);
  }

  // ─── Scan History ────────────────────────────────────────
  Future<Map<String, dynamic>> saveScan({
    required String detectedDisease,
    String detectedDiseaseMr = '',
    String detectedDiseaseHi = '',
    required double confidence,
    String severity = 'Medium',
    String treatmentsJson = '[]',
    String explanation = '',
    String causesJson = '[]',
    String preventionJson = '[]',
    String modelName = 'mock_v1',
    String modelVersion = '1.0',
    String cropType = '',
    String imageUrl = '',
  }) async {
    return _post(ApiConfig.saveScan, {
      'detected_disease': detectedDisease,
      'detected_disease_mr': detectedDiseaseMr,
      'detected_disease_hi': detectedDiseaseHi,
      'confidence': confidence,
      'severity': severity,
      'treatments_json': treatmentsJson,
      'explanation': explanation,
      'causes_json': causesJson,
      'prevention_json': preventionJson,
      'model_name': modelName,
      'model_version': modelVersion,
      'crop_type': cropType,
      'image_url': imageUrl,
    });
  }

  Future<Map<String, dynamic>> getHistory({int skip = 0, int limit = 50}) async {
    return _get('${ApiConfig.scanHistory}?skip=$skip&limit=$limit');
  }

  // ─── ML Models ───────────────────────────────────────────
  Future<Map<String, dynamic>> getAvailableModels() async {
    return _get(ApiConfig.mlModels);
  }
}
