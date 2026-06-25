"""
Plant disease classifier — YOLOv8 classification model (PlantVillage).

Model: MudassirFayaz/YoloV8-PlantVillage-classes-detection
Source: https://huggingface.co/MudassirFayaz/YoloV8-PlantVillage-classes-detection

Uses ultralytics YOLO in classify mode (task="classify").
NO transformers dependency — works with the same ultralytics package
already used for leaf detection.

Supports 38 disease/health classes across 14 crops from PlantVillage:
  Apple, Blueberry, Cherry, Corn, Grape, Orange, Peach,
  Pepper-bell, Potato, Raspberry, Soybean, Squash, Strawberry, Tomato

Label format from model: "Tomato___Early_blight"
  → parsed into crop="Tomato", disease="Early blight"
  → returned as "Tomato - Early blight"

Confidence thresholds:
  >= 0.65  → status: success
  0.35–0.65 → status: uncertain
  < 0.35   → status: invalid_or_unclear
"""

import os
from typing import Optional
from PIL import Image

# ── Model Config ─────────────────────────────────────────────────────────────
HF_REPO_ID   = "MudassirFayaz/YoloV8-PlantVillage-classes-detection"
HF_FILENAME  = "train2/weights/best.pt"

# Confidence Thresholds
HIGH_CONFIDENCE = 0.35
UNCERTAIN_CONFIDENCE = 0.10

# How many top predictions to return
TOP_K = 5

# Lazy-loaded model
_model = None
_model_path: Optional[str] = None
_load_error: Optional[str] = None


# ── Model Loading ─────────────────────────────────────────────────────────────

def _download_model() -> str:
    """Download best.pt from HuggingFace if not already cached."""
    global _model_path
    if _model_path and os.path.exists(_model_path):
        return _model_path

    try:
        from huggingface_hub import hf_hub_download
        print(f"[Farmly] Downloading PlantVillage YOLOv8 classifier from HuggingFace: {HF_REPO_ID}")
        _model_path = hf_hub_download(repo_id=HF_REPO_ID, filename=HF_FILENAME)
        print(f"[Farmly] Classifier model cached at: {_model_path}")
        return _model_path
    except Exception as e:
        raise RuntimeError(
            f"Failed to download PlantVillage disease classifier from HuggingFace: {e}. "
            "Check your internet connection."
        )


def _load_model():
    """Lazy-load the YOLOv8 classification model."""
    global _model, _load_error

    if _model is not None:
        return _model
    if _load_error:
        raise RuntimeError(_load_error)

    try:
        from ultralytics import YOLO
        path = _download_model()
        print(f"[Farmly] Loading PlantVillage YOLOv8 classifier from: {path}")
        _model = YOLO(path)
        print(f"[Farmly] PlantVillage classifier ready — {len(_model.names)} classes")
        return _model
    except Exception as e:
        _load_error = str(e)
        raise RuntimeError(_load_error)


# ── Public API ────────────────────────────────────────────────────────────────

def classify_disease(pil_image: Image.Image) -> dict:
    """
    Classify plant disease from a leaf image using YOLOv8 detection.

    Args:
        pil_image: PIL Image (can be full image or cropped leaf region)

    Returns:
        {
            "status": "success" | "uncertain" | "invalid_or_unclear",
            "crop": str,          # e.g. "Tomato"
            "disease": str,       # e.g. "Tomato - Early blight"
            "disease_confidence": float (0–1),
            "top_predictions": [
                {"label": str, "confidence": float},
                ...
            ],
            "message": str,
        }
    """
    try:
        model = _load_model()
    except RuntimeError as e:
        return _error_result(f"Disease classifier unavailable: {e}")

    try:
        img = pil_image.convert("RGB")

        # Run YOLOv8 in detect mode
        results = model(img, verbose=False)

        if not results or len(results) == 0:
            return _error_result("Classifier returned no results.")

        result = results[0]
        boxes = result.boxes
        if boxes is None or len(boxes) == 0:
            # Fallback to lower confidence
            results = model(img, conf=0.10, verbose=False)
            if results and len(results) > 0 and len(results[0].boxes) > 0:
                result = results[0]
                boxes = result.boxes
            else:
                return _error_result("No diseases detected by the model.")

        confidences = boxes.conf.cpu().numpy()
        classes = boxes.cls.cpu().numpy().astype(int)

        # Standard alphabetical mapping of 38 classes
        PLANT_VILLAGE_CLASSES = [
            "Apple___Apple_scab",
            "Apple___Black_rot",
            "Apple___Cedar_apple_rust",
            "Apple___healthy",
            "Blueberry___healthy",
            "Cherry_(including_sour)___healthy",
            "Cherry_(including_sour)___Powdery_mildew",
            "Corn_(maize)___Cercospora_leaf_spot_Gray_leaf_spot",
            "Corn_(maize)___Common_rust_",
            "Corn_(maize)___healthy",
            "Corn_(maize)___Northern_Leaf_Blight",
            "Grape___Black_rot",
            "Grape___Esca_(Black_Measles)",
            "Grape___healthy",
            "Grape___Leaf_blight_(Isariopsis_Leaf_Spot)",
            "Orange___Haunglongbing_(Citrus_greening)",
            "Peach___Bacterial_spot",
            "Peach___healthy",
            "Pepper,_bell___Bacterial_spot",
            "Pepper,_bell___healthy",
            "Potato___Early_blight",
            "Potato___healthy",
            "Potato___Late_blight",
            "Raspberry___healthy",
            "Soybean___healthy",
            "Squash___Powdery_mildew",
            "Strawberry___healthy",
            "Strawberry___Leaf_scorch",
            "Tomato___Bacterial_spot",
            "Tomato___Early_blight",
            "Tomato___healthy",
            "Tomato___Late_blight",
            "Tomato___Leaf_Mold",
            "Tomato___Septoria_leaf_spot",
            "Tomato___Spider_mites_Two-spotted_spider_mite",
            "Tomato___Target_Spot",
            "Tomato___Tomato_yellow_Leaf_Curl_Virus",
            "Tomato___Tomato_mosaic_virus"
        ]

        # Build predictions list sorted by confidence
        all_preds = []
        for i in range(len(confidences)):
            cls_id = int(classes[i])
            conf = float(confidences[i])
            raw_label = PLANT_VILLAGE_CLASSES[cls_id] if cls_id < len(PLANT_VILLAGE_CLASSES) else f"class_{cls_id}"
            label = _clean_label(raw_label)
            all_preds.append({
                "label": label,
                "confidence": round(conf, 4)
            })

        # Sort descending
        all_preds.sort(key=lambda x: x["confidence"], reverse=True)

        if not all_preds:
            return _error_result("No predictions returned by classifier.")

        top = all_preds[0]
        disease_name = top["label"]
        disease_conf = top["confidence"]

        # Extract crop from the top label
        crop_name = _extract_crop(disease_name)

        # Determine status
        if disease_conf >= HIGH_CONFIDENCE:
            status = "success"
            message = f"Disease identified: {disease_name} ({disease_conf*100:.1f}% confidence)"
        elif disease_conf >= UNCERTAIN_CONFIDENCE:
            status = "uncertain"
            message = (
                f"Results uncertain. Top prediction: {disease_name} "
                f"({disease_conf*100:.1f}% confidence). "
                "Please upload a clearer, closer image for better accuracy."
            )
        else:
            status = "invalid_or_unclear"
            message = (
                "Could not confidently identify a disease. "
                "Please upload a clear image of one leaf with visible symptoms."
            )

        return {
            "status":            status,
            "crop":              crop_name,
            "disease":           disease_name,
            "disease_confidence": disease_conf,
            "top_predictions":   all_preds[:TOP_K],
            "message":           message,
        }

    except Exception as e:
        print(f"[Farmly] WARN: Disease classification error: {e}")
        return _error_result(f"Disease classification failed: {e}")


# ── Helpers ───────────────────────────────────────────────────────────────────

def _clean_label(raw: str) -> str:
    """
    Convert raw PlantVillage label to human-readable string.

    Examples:
      "Tomato___Early_blight"           → "Tomato - Early blight"
      "Apple___Apple_scab"              → "Apple - Apple scab"
      "Corn_(maize)___healthy"          → "Corn - Healthy"
      "Pepper,_bell___Bacterial_spot"   → "Pepper bell - Bacterial spot"
    """
    # Strip parentheses/commas from crop part
    label = raw.replace("(", "").replace(")", "").replace(",", "")

    if "___" in label:
        parts   = label.split("___", 1)
        crop    = parts[0].replace("_", " ").strip()
        disease = parts[1].replace("_", " ").strip().capitalize() if len(parts) > 1 else ""

        # Normalise "healthy" capitalisation
        if disease.lower() == "healthy":
            disease = "Healthy"

        if disease:
            return f"{crop} - {disease}"
        return crop

    # Fallback
    return label.replace("_", " ").strip()


def _extract_crop(cleaned_label: str) -> str:
    """Extract just the crop name from a cleaned label like 'Tomato - Early blight'."""
    if " - " in cleaned_label:
        return cleaned_label.split(" - ")[0].strip()
    return cleaned_label.strip()


def _error_result(message: str) -> dict:
    """Return a standardised error result."""
    return {
        "status":            "invalid_or_unclear",
        "crop":              "",
        "disease":           "",
        "disease_confidence": 0.0,
        "top_predictions":   [],
        "message":           message,
    }
