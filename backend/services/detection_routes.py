"""
Detection API routes — Single-model YOLOv8 pipeline.

POST /api/detect-leaf-and-disease  — Full detection pipeline
POST /api/generate-advisory        — Gemini advisory (after success)
POST /api/translate-advisory       — Translate existing advisory

Pipeline:
  1. Image validation (file type, size, corruption checks)
  2. FODUU YOLOv8 leaf detector  → bounding box + annotated image
  3. PlantVillage YOLOv8 classifier → crop name + disease label + confidence
  4. Build and return unified response
"""

import os
import uuid
from fastapi import APIRouter, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional, List

from services.image_validation import validate_upload
from services.leaf_detector import detect_leaf
from services.disease_classifier import classify_disease
from services import gemini_service
from detection.yolo_service import detect_disease as detect_rice_disease

router = APIRouter(prefix="/api", tags=["Detection V2"])


# ── Request / Response Schemas ────────────────────────────────────────────────

class AdvisoryRequest(BaseModel):
    crop: str
    disease: str
    confidence: float
    language: str = "English"


class TranslateRequest(BaseModel):
    advisory: dict
    language: str


class PredictionItem(BaseModel):
    label: str
    confidence: float


class BoundingBox(BaseModel):
    x1: int = 0
    y1: int = 0
    x2: int = 0
    y2: int = 0


# ── Directories ───────────────────────────────────────────────────────────────

UPLOADS_DIR = os.path.join(os.path.dirname(__file__), "..", "uploads")
OUTPUTS_DIR = os.path.join(os.path.dirname(__file__), "..", "outputs")


def _ensure_dirs():
    os.makedirs(UPLOADS_DIR, exist_ok=True)
    os.makedirs(OUTPUTS_DIR, exist_ok=True)


def get_clean_custom_label(raw_label: str) -> tuple[str, str]:
    """Map raw 41-class label to (crop, disease)."""
    # Lowercase and strip
    label = raw_label.lower().strip()
    
    # Static mapping dictionary
    mapping = {
        'apple black rot': ('Apple', 'Apple - Black rot'),
        'apple healthy': ('Apple', 'Apple - Healthy'),
        'apple scab': ('Apple', 'Apple - Scab'),
        'bell pepper bacterial spot': ('Bell Pepper', 'Bell Pepper - Bacterial spot'),
        'bell pepper healthy': ('Bell Pepper', 'Bell Pepper - Healthy'),
        'cassava Brown Streak Disease': ('Cassava', 'Cassava - Brown Streak Disease'),
        'cassava bacterial blight': ('Cassava', 'Cassava - Bacterial blight'),
        'cassava green mottle': ('Cassava', 'Cassava - Green mottle'),
        'cedar apple rust': ('Apple', 'Apple - Cedar apple rust'),
        'cherry healthy': ('Cherry', 'Cherry - Healthy'),
        'cherry powdery mildew': ('Cherry', 'Cherry - Powdery mildew'),
        'corn cerespora leaf spot': ('Corn', 'Corn - Cercospora leaf spot'),
        'corn common rust': ('Corn', 'Corn - Common rust'),
        'corn healthy': ('Corn', 'Corn - Healthy'),
        'grape black rot': ('Grape', 'Grape - Black rot'),
        'grape esca': ('Grape', 'Grape - Esca'),
        'grape healthy': ('Grape', 'Grape - Healthy'),
        'grape leaf blight': ('Grape', 'Grape - Leaf blight'),
        'healthy cassava': ('Cassava', 'Cassava - Healthy'),
        'mosaic  cassava': ('Cassava', 'Cassava - Mosaic'),
        'northern leaf blight': ('Corn', 'Corn - Northern leaf blight'),
        'orange citrus greening': ('Orange', 'Orange - Citrus greening'),
        'peach bacterial spot': ('Peach', 'Peach - Bacterial spot'),
        'peach healthy': ('Peach', 'Peach - Healthy'),
        'potato early blight': ('Potato', 'Potato - Early blight'),
        'potato healthy': ('Potato', 'Potato - Healthy'),
        'potato late blight': ('Potato', 'Potato - Late blight'),
        'rice brown spot': ('Rice', 'Rice - Brown spot'),
        'rice healthy': ('Rice', 'Rice - Healthy'),
        'rice hispa': ('Rice', 'Rice - Hispa'),
        'rice leaf blast': ('Rice', 'Rice - Leaf blast'),
        'spider mites two-spotted spider mite': ('Spider Mites', 'Spider Mites - Two-spotted spider mite'),
        'squash powdery mildew': ('Squash', 'Squash - Powdery mildew'),
        'strawberry healthy': ('Strawberry', 'Strawberry - Healthy'),
        'strawberry leaf scorch': ('Strawberry', 'Strawberry - Leaf scorch'),
        'tomato bacterial spot': ('Tomato', 'Tomato - Bacterial spot'),
        'tomato early blight': ('Tomato', 'Tomato - Early blight'),
        'tomato late blight': ('Tomato', 'Tomato - Late blight'),
        'tomato leaf healthy': ('Tomato', 'Tomato - Healthy'),
        'tomato leaf mould': ('Tomato', 'Tomato - Leaf mould'),
        'tomato septoria leaf spot': ('Tomato', 'Tomato - Septoria leaf spot')
    }
    
    # Try direct match
    if label in mapping:
        return mapping[label]
        
    # Fallback parsing
    parts = raw_label.replace("_", " ").split()
    if parts:
        crop = parts[0].capitalize()
        disease = f"{crop} - " + " ".join(parts[1:])
        return crop, disease
        
    return "Unknown", raw_label


# ═════════════════════════════════════════════════════════════════════════════
#  POST /api/detect-leaf-and-disease
# ═════════════════════════════════════════════════════════════════════════════

@router.post("/detect-leaf-and-disease")
async def detect_leaf_and_disease(image: UploadFile = File(...)):
    """
    Single-image plant disease detection.

    Pipeline:
      validate → YOLO leaf detect (bounding box) → YOLOv8 classify (disease) → response

    Returns status: success | uncertain | invalid_or_unclear | no_leaf
    """
    _ensure_dirs()

    # ── 1. Read file bytes ────────────────────────────────────────────────────
    try:
        file_bytes = await image.read()
    except Exception:
        raise HTTPException(status_code=400, detail="Could not read uploaded file.")

    # ── 2. Validate image (type, size, corruption) ────────────────────────────
    validation = validate_upload(
        file_bytes=file_bytes,
        filename=image.filename or "unknown.jpg",
        content_type=image.content_type,
    )

    if not validation["can_proceed"]:
        return JSONResponse(content={
            "status":              "invalid_or_unclear",
            "message":             validation["message"],
            "issues":              validation["issues"],
            "crop":                "",
            "crop_confidence":     0,
            "disease":             "",
            "disease_confidence":  0,
            "top_predictions":     [],
            "bounding_box":        {"x1": 0, "y1": 0, "x2": 0, "y2": 0},
            "annotated_image_url": "",
            "original_image_url":  "",
        })

    pil_image = validation["pil_image"]

    # Save original upload
    original_filename = f"upload_{uuid.uuid4().hex[:12]}.jpg"
    original_path     = os.path.join(UPLOADS_DIR, original_filename)
    try:
        pil_image.save(original_path, "JPEG", quality=90)
    except Exception:
        pass

    original_url = f"/api/uploads/{original_filename}"

    # ── 3. Call Gemini Vision API directly ──────────────────────────────────────
    print(f"[Farmly] Running Gemini Vision detection for {original_filename}...")
    
    # We pass the raw bytes directly to the new Gemini Vision service
    vision_result = gemini_service.analyze_image_vision(
        image_bytes=file_bytes,
        mime_type=image.content_type or "image/jpeg",
        language="English", # Default to English for initial detection
    )
    
    if vision_result.get("status") == "error":
        # Fallback or just error out
        return JSONResponse(content={
            "status":              "invalid_or_unclear",
            "message":             vision_result.get("message", "AI analysis failed."),
            "crop":                "",
            "crop_confidence":     0.0,
            "disease":             "",
            "disease_confidence":  0.0,
            "top_predictions":     [],
            "bounding_box":        {"x1": 0, "y1": 0, "x2": 0, "y2": 0},
            "annotated_image_url": original_url,
            "original_image_url":  original_url,
            "advisory":            None,
        })
        
    crop_name = vision_result.get("crop", "Unknown")
    disease_name = vision_result.get("disease", "Unknown")
    confidence = vision_result.get("confidence", 0.95)
    advisory = vision_result.get("advisory")
    
    status = "success"
    if "healthy" not in disease_name.lower() and confidence < 0.60:
        status = "uncertain"

    message = f"Analyzed via Gemini Vision: {disease_name} on {crop_name} ({confidence*100:.1f}% confidence)"
    if validation.get("issues"):
        message = f"Image quality note: {validation['message']}. " + message

    return JSONResponse(content={
        "status":              status,
        "message":             message,
        "crop":                crop_name,
        "crop_confidence":     round(confidence, 4),
        "disease":             disease_name,
        "disease_confidence":  round(confidence, 4),
        "top_predictions":     [{"label": disease_name, "confidence": round(confidence, 4)}],
        "bounding_box":        {"x1": 0, "y1": 0, "x2": 0, "y2": 0},
        "annotated_image_url": original_url, # Use original as annotated since no box is drawn
        "original_image_url":  original_url,
        "advisory":            advisory,
    })


# ═════════════════════════════════════════════════════════════════════════════
#  POST /api/detect-fallback
# ═════════════════════════════════════════════════════════════════════════════

@router.post("/detect-fallback")
async def detect_fallback(image: UploadFile = File(...)):
    """
    Fallback detection API to be implemented later by the user.
    Called by the app if the primary /detect-leaf-and-disease endpoint fails.
    """
    _ensure_dirs()
    
    # ── 1. Read file bytes ────────────────────────────────────────────────────
    try:
        file_bytes = await image.read()
    except Exception:
        raise HTTPException(status_code=400, detail="Could not read uploaded file.")
    
    # TODO: Implement fallback logic here
    # For now, return a placeholder response so the app handles it correctly
    
    return JSONResponse(content={
        "status":              "success",
        "message":             "Fallback API placeholder response",
        "crop":                "Unknown",
        "crop_confidence":     1.0,
        "disease":             "Unknown",
        "disease_confidence":  1.0,
        "top_predictions":     [{"label": "Unknown", "confidence": 1.0}],
        "bounding_box":        {"x1": 0, "y1": 0, "x2": 0, "y2": 0},
        "annotated_image_url": "", 
        "original_image_url":  "",
        "advisory":            None,
    })


# ═════════════════════════════════════════════════════════════════════════════
#  POST /api/generate-advisory
# ═════════════════════════════════════════════════════════════════════════════

@router.post("/generate-advisory")
async def generate_advisory(request: AdvisoryRequest):
    """
    Generate a Gemini advisory for a successfully detected disease.
    Call only after status=success from detect-leaf-and-disease.

    Input:  {crop, disease, confidence, language}
    Output: Gemini advisory JSON
    """
    if not request.crop or not request.disease:
        raise HTTPException(
            status_code=400,
            detail="Both 'crop' and 'disease' are required.",
        )

    if request.language not in ("English", "Hindi", "Marathi"):
        raise HTTPException(
            status_code=400,
            detail="Language must be one of: English, Hindi, Marathi",
        )

    print(f"[Farmly] Generating advisory: {request.crop}/{request.disease}/{request.language}")

    advisory = gemini_service.generate_advisory(
        crop=request.crop,
        disease=request.disease,
        confidence=request.confidence,
        language=request.language,
    )

    if advisory.get("_error"):
        return JSONResponse(
            status_code=503,
            content={
                "error":    advisory["_error"],
                "advisory": advisory,
            },
        )

    return JSONResponse(content=advisory)


# ═════════════════════════════════════════════════════════════════════════════
#  POST /api/translate-advisory
# ═════════════════════════════════════════════════════════════════════════════

@router.post("/translate-advisory")
async def translate_advisory(request: TranslateRequest):
    """
    Translate an existing advisory to a different language.
    Does NOT rerun disease detection.

    Input:  {advisory: {...}, language: "Hindi"}
    Output: Translated advisory JSON
    """
    if not request.advisory:
        raise HTTPException(
            status_code=400,
            detail="'advisory' object is required.",
        )

    if request.language not in ("English", "Hindi", "Marathi"):
        raise HTTPException(
            status_code=400,
            detail="Language must be one of: English, Hindi, Marathi",
        )

    print(f"[Farmly] Translating advisory to {request.language}")

    translated = gemini_service.translate_advisory(
        advisory=request.advisory,
        language=request.language,
    )

    if translated.get("_error"):
        return JSONResponse(
            status_code=503,
            content={
                "error":    translated["_error"],
                "advisory": request.advisory,
            },
        )

    return JSONResponse(content=translated)
