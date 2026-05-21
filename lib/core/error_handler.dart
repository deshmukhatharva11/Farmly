/// Centralized error handling with trilingual messages.
class AppError {
  final String type;
  final String messageEn;
  final String messageMr;
  final String messageHi;

  const AppError({
    required this.type,
    required this.messageEn,
    required this.messageMr,
    required this.messageHi,
  });

  String getMessage(String langCode) {
    switch (langCode) {
      case 'mr': return messageMr;
      case 'hi': return messageHi;
      default: return messageEn;
    }
  }
}

class ErrorHandler {
  ErrorHandler._();

  static const _errors = <String, AppError>{
    'network': AppError(
      type: 'network',
      messageEn: 'No internet connection. Please check your network.',
      messageMr: 'इंटरनेट कनेक्शन नाही. कृपया तुमचे नेटवर्क तपासा.',
      messageHi: 'इंटरनेट कनेक्शन नहीं है। कृपया अपना नेटवर्क जांचें।',
    ),
    'timeout': AppError(
      type: 'timeout',
      messageEn: 'Request timed out. The server may be busy.',
      messageMr: 'विनंतीचा वेळ संपला. सर्व्हर व्यस्त असू शकतो.',
      messageHi: 'अनुरोध का समय समाप्त हो गया। सर्वर व्यस्त हो सकता है।',
    ),
    'api_error': AppError(
      type: 'api_error',
      messageEn: 'Something went wrong. Please try again.',
      messageMr: 'काहीतरी चूक झाली. कृपया पुन्हा प्रयत्न करा.',
      messageHi: 'कुछ गलत हो गया। कृपया पुनः प्रयास करें।',
    ),
    'gps_denied': AppError(
      type: 'gps_denied',
      messageEn: 'Location permission denied. Set location in profile.',
      messageMr: 'स्थान परवानगी नाकारली. प्रोफाईलमध्ये स्थान सेट करा.',
      messageHi: 'स्थान अनुमति अस्वीकृत। प्रोफ़ाइल में स्थान सेट करें।',
    ),
    'image_invalid': AppError(
      type: 'image_invalid',
      messageEn: 'Could not process the image. Please try another photo.',
      messageMr: 'प्रतिमा प्रक्रिया करता आली नाही. कृपया दुसरा फोटो वापरा.',
      messageHi: 'छवि संसाधित नहीं हो सकी। कृपया दूसरी तस्वीर आज़माएं।',
    ),
    'detection_failed': AppError(
      type: 'detection_failed',
      messageEn: 'Detection failed. Using offline mode.',
      messageMr: 'तपासणी अयशस्वी. ऑफलाइन मोड वापरत आहे.',
      messageHi: 'पहचान विफल। ऑफ़लाइन मोड का उपयोग कर रहे हैं।',
    ),
    'weather_failed': AppError(
      type: 'weather_failed',
      messageEn: 'Could not fetch weather data.',
      messageMr: 'हवामान डेटा मिळवता आला नाही.',
      messageHi: 'मौसम डेटा प्राप्त नहीं हो सका।',
    ),
    'not_logged_in': AppError(
      type: 'not_logged_in',
      messageEn: 'Please log in first.',
      messageMr: 'कृपया प्रथम लॉगिन करा.',
      messageHi: 'कृपया पहले लॉगिन करें।',
    ),
    'save_failed': AppError(
      type: 'save_failed',
      messageEn: 'Could not save. Please try again.',
      messageMr: 'जतन करता आले नाही. कृपया पुन्हा प्रयत्न करा.',
      messageHi: 'सहेजा नहीं जा सका। कृपया पुनः प्रयास करें।',
    ),
  };

  static AppError get(String type) {
    return _errors[type] ?? _errors['api_error']!;
  }

  static String getLocalizedMessage(String errorType, String langCode) {
    return get(errorType).getMessage(langCode);
  }

  /// Determine error type from exception.
  static String classifyError(dynamic error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('timeout') || msg.contains('timed out')) return 'timeout';
    if (msg.contains('socket') || msg.contains('network') || msg.contains('connection')) return 'network';
    if (msg.contains('validation')) return 'image_invalid';
    if (msg.contains('401') || msg.contains('unauthorized')) return 'not_logged_in';
    return 'api_error';
  }
}
