import 'package:flutter/foundation.dart';

/// API configuration for Farmly backend.
class ApiConfig {
  ApiConfig._();

  /// Base URL for the backend API.
  ///
  /// Set at build time via --dart-define=BACKEND_URL=https://your-api.onrender.com
  /// Example build command:
  ///   flutter build apk --release --dart-define=BACKEND_URL=https://farmly-api.onrender.com
  ///
  /// Falls back to local emulator/web addresses in debug mode.
  static const String _productionUrl =
      String.fromEnvironment('BACKEND_URL', defaultValue: '');

  static String get baseUrl {
    if (kReleaseMode && _productionUrl.isNotEmpty) {
      return _productionUrl;
    }
    if (kIsWeb) return 'http://127.0.0.1:8000';
    return 'http://10.0.2.2:8000'; // Android emulator → host machine
  }

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

  // Detection V2 endpoints
  static const String detectLeafAndDisease = '/api/detect-leaf-and-disease';
  static const String detectLeafAndDiseaseFallback = '/api/detect-fallback';
  static const String generateAdvisory = '/api/generate-advisory';
  static const String translateAdvisory = '/api/translate-advisory';
}
