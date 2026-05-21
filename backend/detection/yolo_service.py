"""
YOLOv8 inference service for rice leaf disease detection.
Loads the fine-tuned model from the cloned repo and runs inference
on uploaded images.

Features:
- Single-image detection with confidence gating
- Multi-image detection with result aggregation
- Low-confidence warnings with retake suggestions
- Healthy leaf detection
"""

import os
from pathlib import Path
from typing import Optional
from PIL import Image

# Lazy-load the model to keep startup fast
_model = None

# Path to the fine-tuned weights
WEIGHTS_PATH = os.path.join(
    os.path.dirname(__file__),
    "..",
    "rice_model",
    "runs",
    "detect",
    "train",
    "weights",
    "best.pt",
)

# Disease class names (from data.yaml)
CLASS_NAMES = [
    "Bacterial_Leaf_Blight",
    "Brown_Spot",
    "HealthyLeaf",
    "Leaf_Blast",
    "Leaf_Scald",
    "Narrow_Brown_Leaf_Spot",
    "Neck_Blast",
    "Rice_Hispa",
]

# Marathi translations
CLASS_NAMES_MR = {
    "Bacterial_Leaf_Blight": "जिवाणू करपा",
    "Brown_Spot": "तपकिरी ठिपके",
    "HealthyLeaf": "निरोगी पान",
    "Leaf_Blast": "पानावरील करपा",
    "Leaf_Scald": "पान पोळणे",
    "Narrow_Brown_Leaf_Spot": "अरुंद तपकिरी ठिपके",
    "Neck_Blast": "मानेचा करपा",
    "Rice_Hispa": "भात हिस्पा",
    "No Disease Detected": "कोणताही रोग आढळला नाही",
}

# Hindi translations
CLASS_NAMES_HI = {
    "Bacterial_Leaf_Blight": "जीवाणु झुलसा",
    "Brown_Spot": "भूरा धब्बा",
    "HealthyLeaf": "स्वस्थ पत्ती",
    "Leaf_Blast": "पत्ती का झुलसा",
    "Leaf_Scald": "पत्ती का जलना",
    "Narrow_Brown_Leaf_Spot": "सँकरा भूरा धब्बा",
    "Neck_Blast": "गर्दन का झुलसा",
    "Rice_Hispa": "धान हिस्पा",
    "No Disease Detected": "कोई रोग नहीं मिला",
}

# Severity mapping per disease
SEVERITY_MAP = {
    "Bacterial_Leaf_Blight": "High",
    "Brown_Spot": "Medium",
    "HealthyLeaf": "None",
    "Leaf_Blast": "Critical",
    "Leaf_Scald": "Medium",
    "Narrow_Brown_Leaf_Spot": "Medium",
    "Neck_Blast": "Critical",
    "Rice_Hispa": "High",
}

# Confidence thresholds
CONFIDENCE_THRESHOLD = 0.45       # Minimum to even consider a detection
HIGH_CONFIDENCE_THRESHOLD = 0.65  # Below this → low confidence warning


def _load_model():
    """Lazy-load the YOLOv8 model."""
    global _model
    if _model is None:
        from ultralytics import YOLO

        resolved_path = str(Path(WEIGHTS_PATH).resolve())
        if os.path.exists(resolved_path):
            print(f"🔬 Loading fine-tuned YOLOv8 model from: {resolved_path}")
            _model = YOLO(resolved_path)
        else:
            # Fallback to base model
            print(f"⚠️  Fine-tuned weights not found at {resolved_path}, using yolov8n.pt")
            _model = YOLO("yolov8n.pt")
    return _model


def detect_disease(image: Image.Image, confidence_threshold: float = CONFIDENCE_THRESHOLD) -> dict:
    """
    Run YOLOv8 inference on a PIL Image.

    Returns:
        {
            "disease_name": str,
            "disease_name_mr": str,
            "disease_name_hi": str,
            "confidence": float (0-1),
            "severity": str,
            "box": [x1, y1, x2, y2],
            "is_healthy": bool,
            "is_low_confidence": bool,
            "suggestion": str | None,
            "all_detections": [...]
        }
    """
    model = _load_model()

    # Run inference
    results = model(image, conf=confidence_threshold, verbose=False)

    if not results or len(results) == 0:
        return _no_detection_result()

    result = results[0]

    if result.boxes is None or len(result.boxes) == 0:
        return _no_detection_result()

    # Get the highest confidence detection
    boxes = result.boxes
    confidences = boxes.conf.cpu().numpy()
    classes = boxes.cls.cpu().numpy().astype(int)
    xyxy = boxes.xyxy.cpu().numpy()

    best_idx = confidences.argmax()
    best_class = int(classes[best_idx])
    best_conf = float(confidences[best_idx])
    best_box = xyxy[best_idx].tolist()

    disease_name = CLASS_NAMES[best_class] if best_class < len(CLASS_NAMES) else "Unknown"

    # Confidence gating
    is_low_confidence = best_conf < HIGH_CONFIDENCE_THRESHOLD
    suggestion = None
    if is_low_confidence and disease_name != "HealthyLeaf":
        suggestion = "retake"

    # Collect all detections
    all_detections = []
    for i in range(len(confidences)):
        cls = int(classes[i])
        name = CLASS_NAMES[cls] if cls < len(CLASS_NAMES) else "Unknown"
        all_detections.append({
            "disease_name": name,
            "disease_name_mr": CLASS_NAMES_MR.get(name, name),
            "disease_name_hi": CLASS_NAMES_HI.get(name, name),
            "confidence": float(confidences[i]),
            "severity": SEVERITY_MAP.get(name, "Medium"),
            "box": xyxy[i].tolist(),
        })

    # Sort all detections by confidence descending
    all_detections.sort(key=lambda d: d["confidence"], reverse=True)

    return {
        "disease_name": disease_name,
        "disease_name_mr": CLASS_NAMES_MR.get(disease_name, disease_name),
        "disease_name_hi": CLASS_NAMES_HI.get(disease_name, disease_name),
        "confidence": best_conf,
        "severity": SEVERITY_MAP.get(disease_name, "Medium"),
        "box": best_box,
        "is_healthy": disease_name == "HealthyLeaf",
        "is_low_confidence": is_low_confidence,
        "suggestion": suggestion,
        "all_detections": all_detections,
    }


def detect_multi(images: list[Image.Image], confidence_threshold: float = CONFIDENCE_THRESHOLD) -> dict:
    """
    Run YOLOv8 on multiple images and aggregate results.

    Strategy:
    - Run detection on each image independently
    - Select the detection with highest confidence across all images
    - Calculate weighted average confidence
    - Return combined result with per-image details

    Returns:
        {
            "disease_name": str,
            "confidence": float (weighted best),
            "per_image_results": [...],
            ...standard detection fields...
        }
    """
    per_image_results = []
    best_overall = None
    best_overall_conf = 0.0

    for idx, img in enumerate(images):
        result = detect_disease(img, confidence_threshold)
        per_image_results.append({
            "image_index": idx,
            "disease_name": result["disease_name"],
            "confidence": result["confidence"],
            "is_healthy": result["is_healthy"],
            "severity": result["severity"],
            "box": result["box"],
        })

        # Track the best detection (skip "No Disease Detected" unless all are)
        if result["confidence"] > best_overall_conf:
            if not result["is_healthy"] or best_overall is None:
                best_overall = result
                best_overall_conf = result["confidence"]

    if best_overall is None:
        best_overall = _no_detection_result()

    # Calculate aggregated confidence
    # Weighted average of all detections for the same disease
    same_disease = [r for r in per_image_results if r["disease_name"] == best_overall["disease_name"]]
    if same_disease:
        total_conf = sum(r["confidence"] for r in same_disease)
        avg_conf = total_conf / len(same_disease)
        # Boost confidence slightly for multi-image agreement
        agreement_ratio = len(same_disease) / len(images)
        boosted_conf = min(0.99, avg_conf * (1 + 0.1 * agreement_ratio))
    else:
        boosted_conf = best_overall["confidence"]

    # Update flags
    is_low_confidence = boosted_conf < HIGH_CONFIDENCE_THRESHOLD
    suggestion = "retake" if is_low_confidence and not best_overall.get("is_healthy", False) else None

    return {
        "disease_name": best_overall["disease_name"],
        "disease_name_mr": best_overall["disease_name_mr"],
        "disease_name_hi": best_overall["disease_name_hi"],
        "confidence": round(boosted_conf, 4),
        "severity": best_overall["severity"],
        "box": best_overall["box"],
        "is_healthy": best_overall.get("is_healthy", False),
        "is_low_confidence": is_low_confidence,
        "suggestion": suggestion,
        "all_detections": best_overall.get("all_detections", []),
        "per_image_results": per_image_results,
        "images_analyzed": len(images),
        "agreement_count": len(same_disease) if same_disease else 0,
    }


def _no_detection_result() -> dict:
    """Return a default result when no disease is detected."""
    return {
        "disease_name": "No Disease Detected",
        "disease_name_mr": "कोणताही रोग आढळला नाही",
        "disease_name_hi": "कोई रोग नहीं मिला",
        "confidence": 0.0,
        "severity": "None",
        "box": [0.0, 0.0, 0.0, 0.0],
        "is_healthy": True,
        "is_low_confidence": False,
        "suggestion": None,
        "all_detections": [],
    }
