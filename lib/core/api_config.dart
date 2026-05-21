import 'package:flutter/foundation.dart';

/// API configuration for Farmly backend.
class ApiConfig {
  ApiConfig._();

  /// Base URL for the backend API.
  static const String baseUrl = kReleaseMode
      ? ''
      : (kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000');

  /// Request timeout in seconds.
  static const int timeoutSeconds = 90; // Increased for multi-image + AI

  // Auth endpoints
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';

  // User endpoints
  static const String userProfile = '/user/profile';

  // Scan endpoints
  static const String saveScan = '/scan/save';
  static const String scanHistory = '/scan/history';

  // ML Models endpoint
  static const String mlModels = '/models/';

  // Weather endpoints
  static const String weather = '/weather/';

  // Community endpoints
  static const String communityPosts = '/community/posts';

  // Detection (AI) endpoints
  static const String detectAnalyze = '/detect/analyze';
  static const String detectAnalyzeMulti = '/detect/analyze-multi';
}
