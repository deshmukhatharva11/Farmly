import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../core/api_config.dart';
import '../models/detection_result.dart';
import '../services/auth_service.dart';

/// Abstract detection service
abstract class DetectionService {
  Future<List<DetectionResult>> detect(String imagePath);
  Future<List<DetectionResult>> detectMulti(List<String> imagePaths);
}

/// Real AI detection service that calls YOLOv8 + Gemini backend.
class RealDetectionService implements DetectionService {
  final AuthService _authService;
  final String language;
  final String location;

  /// Holds last validation error for the UI to display
  ValidationResult? lastValidationResult;
  MultiScanInfo? lastMultiScanInfo;

  RealDetectionService({
    required AuthService authService,
    this.language = 'en',
    this.location = 'Maharashtra',
  }) : _authService = authService;

  Future<http.MultipartFile> _buildMultipartFile(String imagePath, {String fieldName = 'image'}) async {
    if (imagePath.startsWith('data:')) {
      final base64Data = imagePath.split(',').last;
      final bytes = base64Decode(base64Data);
      return http.MultipartFile.fromBytes(
        fieldName, bytes, filename: 'scan.jpg',
        contentType: MediaType('image', 'jpeg'),
      );
    } else {
      try {
        return await http.MultipartFile.fromPath(
          fieldName, imagePath,
          contentType: MediaType('image', 'jpeg'),
        );
      } catch (e) {
        final imageResponse = await http.get(Uri.parse(imagePath));
        if (imageResponse.statusCode == 200) {
          return http.MultipartFile.fromBytes(
            fieldName, imageResponse.bodyBytes, filename: 'scan.jpg',
            contentType: MediaType('image', 'jpeg'),
          );
        }
        throw Exception('Failed to read image file');
      }
    }
  }

  DetectionResult _parseApiResponse(Map<String, dynamic> data) {
    final detection = data['detection'];
    final advice = data['advice'] ?? {};
    final validation = data['validation'];

    if (validation != null) {
      lastValidationResult = ValidationResult.fromJson(validation);
    }

    if (data['multi_scan'] != null) {
      lastMultiScanInfo = MultiScanInfo.fromJson(data['multi_scan']);
    }

    final treatments = <Map<String, dynamic>>[];
    if (advice['treatments'] != null) {
      for (final t in advice['treatments']) {
        treatments.add({
          'title': t['title'] ?? '',
          'title_mr': t['title_mr'] ?? t['title'] ?? '',
          'title_hi': t['title_hi'] ?? t['title'] ?? '',
          'description': t['description'] ?? '',
          'description_mr': t['description_mr'] ?? t['description'] ?? '',
          'description_hi': t['description_hi'] ?? t['description'] ?? '',
          'icon': t['icon'] ?? '💊',
        });
      }
    }

    return DetectionResult.fromJson({
      'label': detection['label'] ?? 'Unknown',
      'label_mr': detection['label_mr'] ?? detection['label'] ?? '',
      'label_hi': detection['label_hi'] ?? detection['label'] ?? '',
      'confidence': detection['confidence'] ?? 0.0,
      'severity': detection['severity'] ?? 'Medium',
      'box': detection['box'] ?? [0.0, 0.0, 0.0, 0.0],
      'is_healthy': detection['is_healthy'] ?? false,
      'is_low_confidence': detection['is_low_confidence'] ?? false,
      'suggestion': detection['suggestion'],
      'treatments': treatments,
      'explanation': advice['explanation'] ?? '',
      'full_description': advice['full_description'] ?? '',
      'causes': advice['causes'] ?? [],
      'prevention': advice['prevention'] ?? [],
      'medicine_availability': advice['medicine_availability'] ?? '',
      'next_7_day_care': advice['next_7_day_care'] ?? '',
      'spray_timing': advice['spray_timing'] ?? '',
      'disease_spread_risk': advice['disease_spread_risk'] ?? '',
      'watering_advice': advice['watering_advice'] ?? '',
      'fertilizer_caution': advice['fertilizer_caution'] ?? '',
    });
  }

  @override
  Future<List<DetectionResult>> detect(String imagePath) async {
    lastValidationResult = null;
    lastMultiScanInfo = null;
    final token = await _authService.getToken();

    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.detectAnalyze}');
    final request = http.MultipartRequest('POST', uri);

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['language'] = language;
    request.fields['location'] = location;
    request.files.add(await _buildMultipartFile(imagePath));

    try {
      final streamedResponse = await request
          .send()
          .timeout(Duration(seconds: ApiConfig.timeoutSeconds));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          return [_parseApiResponse(data)];
        }

        // Validation error
        if (data['validation_error'] == true) {
          final val = data['validation'] ?? {};
          lastValidationResult = ValidationResult.fromJson(val);
          throw ValidationException(
            val['message'] ?? 'Image validation failed',
            lastValidationResult!,
          );
        }
      }

      throw Exception('Detection API returned status ${response.statusCode}');
    } on TimeoutException {
      throw Exception('Detection timed out. The server may be busy.');
    }
  }

  @override
  Future<List<DetectionResult>> detectMulti(List<String> imagePaths) async {
    lastValidationResult = null;
    lastMultiScanInfo = null;
    final token = await _authService.getToken();

    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.detectAnalyzeMulti}');
    final request = http.MultipartRequest('POST', uri);

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['language'] = language;
    request.fields['location'] = location;

    for (final path in imagePaths) {
      request.files.add(await _buildMultipartFile(path, fieldName: 'images'));
    }

    try {
      final streamedResponse = await request
          .send()
          .timeout(Duration(seconds: ApiConfig.timeoutSeconds));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          return [_parseApiResponse(data)];
        }

        if (data['validation_error'] == true) {
          final val = data['validation'] ?? {};
          lastValidationResult = ValidationResult(
            valid: false,
            canProceed: false,
            message: val['message'] ?? 'All images rejected',
            issues: ['all_images_rejected'],
          );
          throw ValidationException(
            val['message'] ?? 'All images rejected',
            lastValidationResult!,
          );
        }
      }

      throw Exception('Multi-detection API returned status ${response.statusCode}');
    } on TimeoutException {
      throw Exception('Detection timed out. The server may be busy.');
    }
  }
}

/// Exception for image validation failures
class ValidationException implements Exception {
  final String message;
  final ValidationResult validation;

  ValidationException(this.message, this.validation);

  @override
  String toString() => message;
}

/// Mock detection service (fallback when API is unavailable)
class MockDetectionService implements DetectionService {
  final _random = Random();

  static const _mockDiseases = [
    {
      'label': 'Leaf Spot',
      'label_mr': 'पानावरील डाग',
      'label_hi': 'पत्ती धब्बा',
      'severity': 'Medium',
      'is_healthy': false,
      'is_low_confidence': false,
      'treatments': [
        {
          'title': 'Apply Mancozeb Fungicide',
          'title_mr': 'मॅन्कोझेब बुरशीनाशक वापरा',
          'title_hi': 'मैनकोज़ेब कवकनाशी लगाएं',
          'description': 'Spray Mancozeb 75% WP at 2.5g/litre of water',
          'description_mr': 'मॅन्कोझेब ७५% WP प्रति लिटर पाण्यात २.५ ग्रॅम फवारणी करा',
          'description_hi': 'मैनकोज़ेब 75% WP 2.5 ग्राम/लीटर पानी में छिड़काव करें',
          'icon': '🧪',
        },
        {
          'title': 'Remove Affected Leaves',
          'title_mr': 'प्रभावित पाने काढा',
          'title_hi': 'प्रभावित पत्तियां हटाएं',
          'description': 'Remove and destroy infected leaves to prevent spread',
          'description_mr': 'प्रसार रोखण्यासाठी संक्रमित पाने काढून नष्ट करा',
          'description_hi': 'फैलाव रोकने के लिए संक्रमित पत्तियां हटाकर नष्ट करें',
          'icon': '🍃',
        },
      ],
    },
    {
      'label': 'Bacterial Blight',
      'label_mr': 'जिवाणू करपा',
      'label_hi': 'जीवाणु झुलसा',
      'severity': 'Critical',
      'is_healthy': false,
      'is_low_confidence': false,
      'treatments': [
        {
          'title': 'Copper Oxychloride Spray',
          'title_mr': 'तांबे ऑक्सीक्लोराईड फवारणी',
          'title_hi': 'कॉपर ऑक्सीक्लोराइड छिड़काव',
          'description': 'Apply Copper oxychloride 50% WP at 3g/litre',
          'description_mr': 'कॉपर ऑक्सीक्लोराईड ५०% WP प्रति लिटर ३ ग्रॅम फवारणी करा',
          'description_hi': 'कॉपर ऑक्सीक्लोराइड 50% WP 3 ग्राम/लीटर छिड़काव करें',
          'icon': '🧪',
        },
      ],
    },
  ];

  @override
  Future<List<DetectionResult>> detect(String imagePath) async {
    await Future.delayed(const Duration(seconds: 2));
    final diseaseIndex = _random.nextInt(_mockDiseases.length);
    final disease = _mockDiseases[diseaseIndex];
    final confidence = 0.75 + _random.nextDouble() * 0.2;
    return [
      DetectionResult.fromJson({
        ...disease,
        'confidence': confidence,
        'box': [80.0 + _random.nextDouble() * 40, 120.0 + _random.nextDouble() * 80,
                250.0 + _random.nextDouble() * 50, 350.0 + _random.nextDouble() * 50],
      }),
    ];
  }

  @override
  Future<List<DetectionResult>> detectMulti(List<String> imagePaths) async {
    // Just run single detect on first image for mock
    return detect(imagePaths.first);
  }
}

/// New V2 detection service for the improved single-image workflow.
/// Calls /api/detect-leaf-and-disease, /api/generate-advisory, /api/translate-advisory
class NewDetectionService {
  final AuthService _authService;

  NewDetectionService({required AuthService authService})
      : _authService = authService;

  Future<http.MultipartFile> _buildMultipartFile(String imagePath) async {
    if (imagePath.startsWith('data:')) {
      final base64Data = imagePath.split(',').last;
      final bytes = base64Decode(base64Data);
      return http.MultipartFile.fromBytes(
        'image', bytes,
        filename: 'scan.jpg',
        contentType: MediaType('image', 'jpeg'),
      );
    } else {
      try {
        return await http.MultipartFile.fromPath(
          'image', imagePath,
          contentType: MediaType('image', 'jpeg'),
        );
      } catch (e) {
        final imageResponse = await http.get(Uri.parse(imagePath));
        if (imageResponse.statusCode == 200) {
          return http.MultipartFile.fromBytes(
            'image', imageResponse.bodyBytes,
            filename: 'scan.jpg',
            contentType: MediaType('image', 'jpeg'),
          );
        }
        throw Exception('Failed to read image file');
      }
    }
  }

  /// Run full detection pipeline: validate → YOLO leaf → crop → disease classify
  Future<Map<String, dynamic>> detectLeafAndDisease(String imagePath) async {
    final token = await _authService.getToken();
    
    // Attempt Primary API
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.detectLeafAndDisease}');
      final request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(await _buildMultipartFile(imagePath));

      final streamedResponse = await request
          .send()
          .timeout(Duration(seconds: ApiConfig.timeoutSeconds));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print('[Farmly] Primary detection API failed with status ${response.statusCode}. Trying fallback...');
      }
    } catch (e) {
      print('[Farmly] Primary detection API encountered an error: $e. Trying fallback...');
    }
    
    // Attempt Fallback API
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.detectLeafAndDiseaseFallback}');
      final request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(await _buildMultipartFile(imagePath));

      final streamedResponse = await request
          .send()
          .timeout(Duration(seconds: ApiConfig.timeoutSeconds));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      throw Exception('Fallback Detection API returned status ${response.statusCode}');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Detection timed out. The server may be busy.');
      }
      rethrow;
    }
  }

  /// Generate Gemini advisory (call only after status=success)
  Future<Map<String, dynamic>> generateAdvisory({
    required String crop,
    required String disease,
    required double confidence,
    required String language,
  }) async {
    final token = await _authService.getToken();
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.generateAdvisory}');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'crop': crop,
              'disease': disease,
              'confidence': confidence,
              'language': language,
            }),
          )
          .timeout(Duration(seconds: ApiConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      return {'_error': 'Advisory API returned status ${response.statusCode}'};
    } catch (e) {
      return {'_error': 'Advisory generation failed: $e'};
    }
  }

  /// Translate an existing advisory to another language (no re-detection)
  Future<Map<String, dynamic>> translateAdvisory({
    required Map<String, dynamic> advisory,
    required String language,
  }) async {
    final token = await _authService.getToken();
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.translateAdvisory}');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'advisory': advisory,
              'language': language,
            }),
          )
          .timeout(Duration(seconds: ApiConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      return advisory; // Return original on failure
    } catch (e) {
      return advisory; // Return original on failure
    }
  }
}

