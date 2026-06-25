// Models for the new detection V2 workflow.
//
// Matches the API response from POST /api/detect-leaf-and-disease
// and the advisory from POST /api/generate-advisory.

class LeafDetectionResult {
  final String status; // success | uncertain | invalid_or_unclear | no_leaf
  final String message;
  final String crop;
  final double cropConfidence;
  final String disease;
  final double diseaseConfidence;
  final List<PredictionItem> topPredictions;
  final BoundingBoxResult boundingBox;
  final String annotatedImageUrl;
  final String originalImageUrl;
  final Map<String, dynamic>? advisory;

  const LeafDetectionResult({
    required this.status,
    required this.message,
    this.crop = '',
    this.cropConfidence = 0,
    this.disease = '',
    this.diseaseConfidence = 0,
    this.topPredictions = const [],
    this.boundingBox = const BoundingBoxResult(),
    this.annotatedImageUrl = '',
    this.originalImageUrl = '',
    this.advisory,
  });

  factory LeafDetectionResult.fromJson(Map<String, dynamic> json) {
    return LeafDetectionResult(
      status: json['status'] as String? ?? 'invalid_or_unclear',
      message: json['message'] as String? ?? '',
      crop: json['crop'] as String? ?? '',
      cropConfidence: (json['crop_confidence'] as num?)?.toDouble() ?? 0,
      disease: json['disease'] as String? ?? '',
      diseaseConfidence: (json['disease_confidence'] as num?)?.toDouble() ?? 0,
      topPredictions: (json['top_predictions'] as List<dynamic>?)
              ?.map((e) => PredictionItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      boundingBox: json['bounding_box'] != null
          ? BoundingBoxResult.fromJson(json['bounding_box'] as Map<String, dynamic>)
          : const BoundingBoxResult(),
      annotatedImageUrl: json['annotated_image_url'] as String? ?? '',
      originalImageUrl: json['original_image_url'] as String? ?? '',
      advisory: json['advisory'] as Map<String, dynamic>?,
    );
  }

  bool get isSuccess => status == 'success';
  bool get isUncertain => status == 'uncertain';
  bool get isNoLeaf => status == 'no_leaf';
  bool get isInvalid => status == 'invalid_or_unclear';
}

class PredictionItem {
  final String label;
  final double confidence;

  const PredictionItem({required this.label, required this.confidence});

  factory PredictionItem.fromJson(Map<String, dynamic> json) {
    return PredictionItem(
      label: json['label'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BoundingBoxResult {
  final int x1;
  final int y1;
  final int x2;
  final int y2;

  const BoundingBoxResult({this.x1 = 0, this.y1 = 0, this.x2 = 0, this.y2 = 0});

  factory BoundingBoxResult.fromJson(Map<String, dynamic> json) {
    return BoundingBoxResult(
      x1: json['x1'] as int? ?? 0,
      y1: json['y1'] as int? ?? 0,
      x2: json['x2'] as int? ?? 0,
      y2: json['y2'] as int? ?? 0,
    );
  }
}

/// Advisory result from Gemini
class AdvisoryResult {
  final String summary;
  final List<String> symptoms;
  final List<String> possibleCauses;
  final List<String> prevention;
  final List<String> recommendedActions;
  final String safetyNote;
  final bool isError;
  final String? errorMessage;

  const AdvisoryResult({
    this.summary = '',
    this.symptoms = const [],
    this.possibleCauses = const [],
    this.prevention = const [],
    this.recommendedActions = const [],
    this.safetyNote = '',
    this.isError = false,
    this.errorMessage,
  });

  factory AdvisoryResult.fromJson(Map<String, dynamic> json) {
    return AdvisoryResult(
      summary: json['summary'] as String? ?? '',
      symptoms: _toStringList(json['symptoms']),
      possibleCauses: _toStringList(json['possible_causes']),
      prevention: _toStringList(json['prevention']),
      recommendedActions: _toStringList(json['recommended_actions']),
      safetyNote: json['safety_note'] as String? ?? '',
      isError: json['_error'] != null,
      errorMessage: json['_error'] as String?,
    );
  }

  bool get isEmpty =>
      summary.isEmpty &&
      symptoms.isEmpty &&
      possibleCauses.isEmpty &&
      prevention.isEmpty &&
      recommendedActions.isEmpty;

  static List<String> _toStringList(dynamic val) {
    if (val is List) return val.map((e) => e.toString()).toList();
    return [];
  }
}
