import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/detection_result.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/detection_service.dart';
import '../services/weather_service.dart';

// ─── Auth ──────────────────────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final apiServiceProvider = Provider<ApiService>((ref) {
  final authService = ref.read(authServiceProvider);
  return ApiService(authService);
});

// ─── Detection ─────────────────────────────────────────
final detectionServiceProvider = Provider<DetectionService>((ref) {
  final authService = ref.read(authServiceProvider);
  final locale = ref.watch(localeProvider);
  final location = ref.watch(userLocationProvider);
  return RealDetectionService(
    authService: authService,
    language: locale.languageCode,
    location: location.isNotEmpty ? location : 'Maharashtra',
  );
});

final detectionResultProvider = StateProvider<List<DetectionResult>?>((ref) => null);
final selectedImagePathProvider = StateProvider<String?>((ref) => null);
final isDetectingProvider = StateProvider<bool>((ref) => false);

// ─── Multi-Image Scan ──────────────────────────────────
final multiImagePathsProvider = StateProvider<List<String>>((ref) => []);
final scanModeProvider = StateProvider<ScanMode>((ref) => ScanMode.quick);
final validationResultProvider = StateProvider<ValidationResult?>((ref) => null);

enum ScanMode { quick, advanced }

// ─── Detection V2 (New Workflow) ───────────────────────
final newDetectionServiceProvider = Provider<NewDetectionService>((ref) {
  final authService = ref.read(authServiceProvider);
  return NewDetectionService(authService: authService);
});

final leafDetectionResultProvider = StateProvider<Map<String, dynamic>?>((ref) => null);
final advisoryResultProvider = StateProvider<Map<String, dynamic>?>((ref) => null);
final isAdvisoryLoadingProvider = StateProvider<bool>((ref) => false);
final selectedLanguageProvider = StateProvider<String>((ref) => 'English');
final detectionStepProvider = StateProvider<int>((ref) => 0);


// ─── Locale / Language ─────────────────────────────────
final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));

/// Loads persisted language preference from SharedPreferences.
Future<Locale> loadPersistedLocale() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('app_language') ?? 'en';
    return Locale(langCode);
  } catch (_) {
    return const Locale('en');
  }
}

/// Saves language preference and updates provider.
Future<void> setLocale(WidgetRef ref, Locale locale) async {
  ref.read(localeProvider.notifier).state = locale;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', locale.languageCode);
  } catch (_) {}
}

// ─── Location ──────────────────────────────────────────
final userLocationProvider = StateProvider<String>((ref) => '');
final locationEnabledProvider = StateProvider<bool>((ref) => false);
final userLatProvider = StateProvider<double?>((ref) => null);
final userLonProvider = StateProvider<double?>((ref) => null);

// ─── Weather ───────────────────────────────────────────
final weatherProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final location = ref.watch(userLocationProvider);
  final lat = ref.watch(userLatProvider);
  final lon = ref.watch(userLonProvider);
  return WeatherService.fetchWeather(
    city: location.isNotEmpty ? location.split(',').first.trim() : 'Pune',
    lat: lat,
    lon: lon,
  );
});

final weatherForecastProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final location = ref.watch(userLocationProvider);
  final lat = ref.watch(userLatProvider);
  final lon = ref.watch(userLonProvider);
  return WeatherService.fetchForecast(
    city: location.isNotEmpty ? location.split(',').first.trim() : 'Pune',
    lat: lat,
    lon: lon,
  );
});

// ─── User Profile ──────────────────────────────────────
final userProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.fetchProfile();
});

// ─── Scan History ──────────────────────────────────────
final scanHistoryApiProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final result = await apiService.getHistory();
  // The API returns a Map with 'scans' list inside
  if (result.containsKey('error')) return [result];
  final scans = result['scans'];
  if (scans is List) return scans.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  return [];
});
