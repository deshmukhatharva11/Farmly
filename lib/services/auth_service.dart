import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:farmly/core/api_config.dart';

/// Service handling OTP authentication and session management.
/// Uses SharedPreferences for web compatibility.
class AuthService {
  static const _tokenKey = 'farmly_jwt_token';
  static const _phoneKey = 'farmly_phone';

  /// Send OTP to the given phone number.
  Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final finalPhone = cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sendOtp}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'mobile_number': finalPhone}),
          )
          .timeout(Duration(seconds: ApiConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 422) {
        return {
          'success': false,
          'message': 'Invalid phone number format',
          'message_mr': 'फोन नंबर चुकीचा आहे',
          'message_hi': 'फोन नंबर गलत है',
        };
      } else {
        return {
          'success': false,
          'message': 'Server error. Please try again.',
          'message_mr': 'सर्व्हर त्रुटी. कृपया पुन्हा प्रयत्न करा.',
          'message_hi': 'सर्वर त्रुटि। कृपया पुनः प्रयास करें।',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Check your internet.',
        'message_mr': 'कनेक्शन त्रुटी. इंटरनेट तपासा.',
        'message_hi': 'कनेक्शन त्रुटि। इंटरनेट जांचें।',
      };
    }
  }

  /// Verify OTP and store the JWT token on success.
  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String otp) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final finalPhone = cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.verifyOtp}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'mobile_number': finalPhone, 'otp': otp}),
          )
          .timeout(Duration(seconds: ApiConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['token'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, data['token']);
          await prefs.setString(_phoneKey, phoneNumber);
        }
        return data;
      } else {
        return {
          'success': false,
          'message': 'Verification failed. Please try again.',
          'message_mr': 'पडताळणी अयशस्वी. पुन्हा प्रयत्न करा.',
          'message_hi': 'सत्यापन विफल। पुनः प्रयास करें।',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Check your internet.',
        'message_mr': 'कनेक्शन त्रुटी. इंटरनेट तपासा.',
        'message_hi': 'कनेक्शन त्रुटि। इंटरनेट जांचें।',
      };
    }
  }

  /// Mock Google Login using email.
  Future<Map<String, dynamic>> googleLogin(String email, {String name = ''}) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/google'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'name': name}),
          )
          .timeout(Duration(seconds: ApiConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['token'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, data['token']);
          await prefs.setString(_phoneKey, email); // store email as phone key for now
        }
        return data;
      } else {
        return {
          'success': false,
          'message': 'Google Login failed. Please try again.',
          'message_mr': 'Google लॉगिन अयशस्वी. पुन्हा प्रयत्न करा.',
          'message_hi': 'Google लॉगिन विफल। पुनः प्रयास करें।',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Check your internet.',
        'message_mr': 'कनेक्शन त्रुटी. इंटरनेट तपासा.',
        'message_hi': 'कनेक्शन त्रुटि। इंटरनेट जांचें।',
      };
    }
  }

  /// Check if user is logged in (has a stored token).
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get the stored JWT token.
  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      return null;
    }
  }

  /// Get the stored phone number.
  Future<String?> getPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_phoneKey);
    } catch (e) {
      return null;
    }
  }

  /// Logout: clear all stored auth data.
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_phoneKey);
    } catch (e) {
      // Ignore errors during logout
    }
  }
}
