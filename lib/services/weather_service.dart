import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_config.dart';

/// Weather service with backend-first approach and caching.
class WeatherService {
  static const _cacheKey = 'weather_cache';
  static const _cacheTtlMinutes = 30;
  static const _forecastCacheKey = 'weather_forecast_cache';

  /// Fetch current weather from backend API (with caching).
  static Future<Map<String, dynamic>> fetchWeather({
    String city = 'Pune',
    double? lat,
    double? lon,
  }) async {
    // Check cache first
    final cached = await _getFromCache(_cacheKey);
    if (cached != null) return cached;

    try {
      final queryParams = <String, String>{'city': city};
      if (lat != null) queryParams['lat'] = lat.toString();
      if (lon != null) queryParams['lon'] = lon.toString();

      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.weather}')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Cache the result
        await _saveToCache(_cacheKey, data);
        return data;
      }
    } catch (_) {
      // Fall through to default
    }

    return _defaultWeather(city);
  }

  /// Fetch 7-day forecast details (parsed from the main weather response).
  static Future<List<Map<String, dynamic>>> fetchForecast({
    String city = 'Pune',
    double? lat,
    double? lon,
  }) async {
    final cached = await _getFromCache(_forecastCacheKey);
    if (cached != null && cached['forecast'] != null) {
      return (cached['forecast'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    final weather = await fetchWeather(city: city, lat: lat, lon: lon);
    final forecast = weather['forecast'];
    if (forecast != null && forecast is List) {
      await _saveToCache(_forecastCacheKey, {'forecast': forecast});
      return forecast.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return [];
  }

  // ─── Caching helpers ─────────────────────────────────

  static Future<Map<String, dynamic>?> _getFromCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(key);
      if (cacheJson == null) return null;

      final cacheData = jsonDecode(cacheJson) as Map<String, dynamic>;
      final timestamp = cacheData['_cache_timestamp'] as int? ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (now - timestamp > _cacheTtlMinutes * 60 * 1000) {
        // Cache expired
        await prefs.remove(key);
        return null;
      }

      final data = Map<String, dynamic>.from(cacheData);
      data.remove('_cache_timestamp');
      return data;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveToCache(String key, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = Map<String, dynamic>.from(data);
      cacheData['_cache_timestamp'] = DateTime.now().millisecondsSinceEpoch;
      await prefs.setString(key, jsonEncode(cacheData));
    } catch (_) {
      // Cache failure is non-critical
    }
  }

  static Map<String, dynamic> _defaultWeather(String city) {
    return {
      'success': true,
      'city': city,
      'temperature': 28,
      'humidity': 65,
      'wind_speed': 12,
      'precipitation': 0,
      'rain_chance': 20,
      'condition': 'Partly Cloudy',
      'condition_mr': 'अंशतः ढगाळ',
      'condition_hi': 'आंशिक रूप से बादल',
      'icon': '⛅',
      'advisory': '',
      'advisory_mr': '',
      'advisory_hi': '',
      'forecast': [],
    };
  }
}
