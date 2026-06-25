"""
Leaf detector service using FODUU YOLOv8 model.

Repository: foduucom/plant-leaf-detection-and-classification
Downloads best.pt via huggingface_hub, runs via ultralytics YOLO.

Responsibilities:
- Detect whether a supported crop leaf exists in the image
- Return crop/leaf name, confidence, bounding-box coordinates
- Generate real annotated output image with YOLO bounding box
- Select highest-confidence leaf if multiple detections
- Crop detected leaf region with 8% padding
"""

import os
import uuid
from pathlib import Path
from typing import Optional
from PIL import Image

# Lazy-loaded model
_model = None
_model_path: Optional[str] = None

# Directories
OUTPUTS_DIR = os.path.join(os.path.dirname(__file__), "..", "outputs")
UPLOADS_DIR = os.path.join(os.path.dirname(__file__), "..", "uploads")

# Lowering threshold from 0.40 to 0.20 to prevent rejecting real mobile photos
MIN_LEAF_CONFIDENCE = 0.20  # 40% minimum


def _ensure_dirs():
    """Create output and upload directories if they don't exist."""
    os.makedirs(OUTPUTS_DIR, exist_ok=True)
    os.makedirs(UPLOADS_DIR, exist_ok=True)


def _download_model() -> str:
    """Download FODUU best.pt from HuggingFace if not already cached."""
    global _model_path
    if _model_path and os.path.exists(_model_path):
        return _model_path

    try:
        from huggingface_hub import hf_hub_download

        print("[Farmly] Downloading FODUU plant-leaf-detection model from HuggingFace...")
        _model_path = hf_hub_download(
            repo_id="foduucom/plant-leaf-detection-and-classification",
            filename="best.pt",
        )
        print(f"[Farmly] Model downloaded to: {_model_path}")
        return _model_path
    except Exception as e:
        raise RuntimeError(
            f"Failed to download FODUU leaf detection model: {e}. "
            "Check your internet connection or HuggingFace availability."
        )


def _load_model():
    """Lazy-load the FODUU YOLOv8 model."""
    global _model
    if _model is not None:
        return _model

    from ultralytics import YOLO

    model_path = _download_model()
    print(f"[Farmly] Loading FODUU YOLOv8 leaf detector from: {model_path}")
    _model = YOLO(model_path)
    return _model


def detect_leaf(pil_image: Image.Image) -> dict:
    """
    Run FODUU YOLOv8 leaf detection on a PIL Image.

    Returns:
        {
            "found": bool,
            "crop_name": str,
            "confidence": float (0-1),
            "bounding_box": {"x1": int, "y1": int, "x2": int, "y2": int},
            "annotated_image_path": str (path to annotated image),
            "cropped_image": Image | None (cropped leaf region),
            "cropped_image_path": str | None,
            "all_detections": [...],
            "message": str
        }
    """
    _ensure_dirs()

    try:
        model = _load_model()
    except RuntimeError as e:
        return _no_leaf_result(str(e))

    # Run inference
    results = model(pil_image, conf=0.15, verbose=False)

    if not results or len(results) == 0:
        return _no_leaf_result(
            "No supported crop leaf was detected. "
            "Please upload a clear, close image of one crop leaf."
        )

    result = results[0]

    if result.boxes is None or len(result.boxes) == 0:
        return _no_leaf_result(
            "No supported crop leaf was detected. "
            "Please upload a clear, close image of one crop leaf."
        )

    # Extract all detections
    boxes = result.boxes
    confidences = boxes.conf.cpu().numpy()
    classes = boxes.cls.cpu().numpy().astype(int)
    xyxy = boxes.xyxy.cpu().numpy()

    # Get class names from the model
    class_names = model.names if hasattr(model, "names") else {}

    # Collect all detections
    all_detections = []
    for i in range(len(confidences)):
        cls_id = int(classes[i])
        name = class_names.get(cls_id, f"class_{cls_id}")
        all_detections.append({
            "label": name,
            "confidence": round(float(confidences[i]), 4),
            "box": {
                "x1": int(xyxy[i][0]),
                "y1": int(xyxy[i][1]),
                "x2": int(xyxy[i][2]),
                "y2": int(xyxy[i][3]),
            },
        })

    # Sort by confidence descending
    all_detections.sort(key=lambda d: d["confidence"], reverse=True)

    # Select highest-confidence detection
    best = all_detections[0]

    # Check confidence threshold
    if best["confidence"] < MIN_LEAF_CONFIDENCE:
        return _no_leaf_result(
            "No supported crop leaf was detected. "
            "Please upload a clear, close image of one crop leaf."
        )

    # Generate annotated image with real YOLO bounding boxes
    annotated_filename = f"annotated_{uuid.uuid4().hex[:12]}.jpg"
    annotated_path = os.path.join(OUTPUTS_DIR, annotated_filename)

    try:
        annotated_frame = result.plot()  # numpy array with boxes drawn
        import cv2
        cv2.imwrite(annotated_path, annotated_frame)
    except Exception as e:
        print(f"[Farmly] WARN: Failed to save annotated image: {e}")
        # Fallback: save original
        pil_image.save(annotated_path, "JPEG", quality=85)

    # Crop the detected leaf region with 8% padding
    cropped_image, cropped_path = _crop_leaf_region(
        pil_image, best["box"]
    )

    return {
        "found": True,
        "crop_name": best["label"],
        "confidence": best["confidence"],
        "bounding_box": best["box"],
        "annotated_image_path": annotated_path,
        "annotated_image_filename": annotated_filename,
        "cropped_image": cropped_image,
        "cropped_image_path": cropped_path,
        "all_detections": all_detections,
        "message": f"Crop leaf detected: {best['label']} ({best['confidence']*100:.1f}% confidence)",
    }


def _crop_leaf_region(
    pil_image: Image.Image, box: dict
) -> tuple[Image.Image | None, str | None]:
    """
    Crop the detected leaf region with 8% padding.
    Returns (cropped_image, saved_path).
    """
    try:
        img_w, img_h = pil_image.size
        x1, y1, x2, y2 = box["x1"], box["y1"], box["x2"], box["y2"]

        # Calculate 8% padding
        box_w = x2 - x1
        box_h = y2 - y1
        pad_x = int(box_w * 0.08)
        pad_y = int(box_h * 0.08)

        # Apply padding without exceeding image boundaries
        crop_x1 = max(0, x1 - pad_x)
        crop_y1 = max(0, y1 - pad_y)
        crop_x2 = min(img_w, x2 + pad_x)
        crop_y2 = min(img_h, y2 + pad_y)

        cropped = pil_image.crop((crop_x1, crop_y1, crop_x2, crop_y2))

        # Save cropped image
        cropped_filename = f"cropped_{uuid.uuid4().hex[:12]}.jpg"
        cropped_path = os.path.join(OUTPUTS_DIR, cropped_filename)
        cropped.save(cropped_path, "JPEG", quality=90)

        return cropped, cropped_path
    except Exception as e:
        print(f"[Farmly] WARN: Failed to crop leaf region: {e}")
        return None, None


def _no_leaf_result(message: str) -> dict:
    """Return result when no leaf is detected."""
    return {
        "found": False,
        "crop_name": "",
        "confidence": 0.0,
        "bounding_box": {"x1": 0, "y1": 0, "x2": 0, "y2": 0},
        "annotated_image_path": None,
        "annotated_image_filename": None,
        "cropped_image": None,
        "cropped_image_path": None,
        "all_detections": [],
        "message": message,
    }


def cleanup_temp_files(*paths: str):
    """Clean up temporary cropped/annotated images."""
    for path in paths:
        if path and os.path.exists(path):
            try:
                os.remove(path)
            except OSError:
                pass
