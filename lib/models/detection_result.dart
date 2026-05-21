/// Models for detection results with Gemini AI advice and validation
class DetectionResult {
  final String label;
  final String labelMarathi;
  final String labelHindi;
  final double confidence;
  final List<double> box;
  final String severity;
  final List<Treatment> treatments;
  // Gemini AI advice fields
  final String explanation;
  final String fullDescription;
  final List<String> causes;
  final List<String> prevention;
  final String medicineAvailability;
  // New advisory fields
  final String next7DayCare;
  final String sprayTiming;
  final String diseaseSpreadRisk;
  final String wateringAdvice;
  final String fertilizerCaution;
  // Detection quality flags
  final bool isHealthy;
  final bool isLowConfidence;
  final String? suggestion;

  const DetectionResult({
    required this.label,
    required this.labelMarathi,
    required this.labelHindi,
    required this.confidence,
    required this.box,
    required this.severity,
    required this.treatments,
    this.explanation = '',
    this.fullDescription = '',
    this.causes = const [],
    this.prevention = const [],
    this.medicineAvailability = '',
    this.next7DayCare = '',
    this.sprayTiming = '',
    this.diseaseSpreadRisk = '',
    this.wateringAdvice = '',
    this.fertilizerCaution = '',
    this.isHealthy = false,
    this.isLowConfidence = false,
    this.suggestion,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      label: json['label'] as String,
      labelMarathi: json['label_mr'] as String? ?? json['label'] as String,
      labelHindi: json['label_hi'] as String? ?? json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      box: (json['box'] as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
      severity: json['severity'] as String? ?? 'Medium',
      treatments: (json['treatments'] as List<dynamic>?)
              ?.map((e) => Treatment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      explanation: json['explanation'] as String? ?? '',
      fullDescription: json['full_description'] as String? ?? '',
      causes: (json['causes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      prevention: (json['prevention'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      medicineAvailability: json['medicine_availability'] as String? ?? '',
      next7DayCare: json['next_7_day_care'] as String? ?? '',
      sprayTiming: json['spray_timing'] as String? ?? '',
      diseaseSpreadRisk: json['disease_spread_risk'] as String? ?? '',
      wateringAdvice: json['watering_advice'] as String? ?? '',
      fertilizerCaution: json['fertilizer_caution'] as String? ?? '',
      isHealthy: json['is_healthy'] as bool? ?? false,
      isLowConfidence: json['is_low_confidence'] as bool? ?? false,
      suggestion: json['suggestion'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'label_mr': labelMarathi,
        'label_hi': labelHindi,
        'confidence': confidence,
        'box': box,
        'severity': severity,
        'treatments': treatments.map((e) => e.toJson()).toList(),
        'explanation': explanation,
        'full_description': fullDescription,
        'causes': causes,
        'prevention': prevention,
        'medicine_availability': medicineAvailability,
        'next_7_day_care': next7DayCare,
        'spray_timing': sprayTiming,
        'disease_spread_risk': diseaseSpreadRisk,
        'watering_advice': wateringAdvice,
        'fertilizer_caution': fertilizerCaution,
        'is_healthy': isHealthy,
        'is_low_confidence': isLowConfidence,
        'suggestion': suggestion,
      };
}

class Treatment {
  final String title;
  final String titleMarathi;
  final String titleHindi;
  final String description;
  final String descriptionMarathi;
  final String descriptionHindi;
  final String icon;

  const Treatment({
    required this.title,
    required this.titleMarathi,
    required this.titleHindi,
    required this.description,
    required this.descriptionMarathi,
    required this.descriptionHindi,
    this.icon = '💊',
  });

  factory Treatment.fromJson(Map<String, dynamic> json) {
    return Treatment(
      title: json['title'] as String,
      titleMarathi: json['title_mr'] as String? ?? json['title'] as String,
      titleHindi: json['title_hi'] as String? ?? json['title'] as String,
      description: json['description'] as String,
      descriptionMarathi: json['description_mr'] as String? ?? json['description'] as String,
      descriptionHindi: json['description_hi'] as String? ?? json['description'] as String,
      icon: json['icon'] as String? ?? '💊',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'title_mr': titleMarathi,
        'title_hi': titleHindi,
        'description': description,
        'description_mr': descriptionMarathi,
        'description_hi': descriptionHindi,
        'icon': icon,
      };
}

/// Validation result from image pre-check
class ValidationResult {
  final bool valid;
  final bool canProceed;
  final int qualityScore;
  final List<String> issues;
  final String message;
  final String messageEn;
  final String messageMr;
  final String messageHi;

  const ValidationResult({
    required this.valid,
    this.canProceed = true,
    this.qualityScore = 7,
    this.issues = const [],
    this.message = '',
    this.messageEn = '',
    this.messageMr = '',
    this.messageHi = '',
  });

  factory ValidationResult.fromJson(Map<String, dynamic> json) {
    return ValidationResult(
      valid: json['valid'] as bool? ?? true,
      canProceed: json['can_proceed'] as bool? ?? true,
      qualityScore: json['quality_score'] as int? ?? 7,
      issues: (json['issues'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      message: json['message'] as String? ?? '',
      messageEn: json['message_en'] as String? ?? '',
      messageMr: json['message_mr'] as String? ?? '',
      messageHi: json['message_hi'] as String? ?? '',
    );
  }
}

/// Multi-image scan metadata
class MultiScanInfo {
  final int totalImages;
  final int validImages;
  final int rejectedImages;
  final int agreementCount;
  final List<Map<String, dynamic>> perImageResults;

  const MultiScanInfo({
    required this.totalImages,
    required this.validImages,
    this.rejectedImages = 0,
    this.agreementCount = 0,
    this.perImageResults = const [],
  });

  factory MultiScanInfo.fromJson(Map<String, dynamic> json) {
    return MultiScanInfo(
      totalImages: json['total_images'] as int? ?? 0,
      validImages: json['valid_images'] as int? ?? 0,
      rejectedImages: json['rejected_images'] as int? ?? 0,
      agreementCount: json['agreement_count'] as int? ?? 0,
      perImageResults: (json['per_image_results'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }
}
