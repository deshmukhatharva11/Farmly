"""
Detection API router.

POST /detect/analyze       - Single image → Validate → YOLOv8 → Gemini advice → response
POST /detect/analyze-multi - Multiple images → Validate each → YOLOv8 multi → Gemini advice → response
GET  /detect/health        - Detection module health check
"""

import io
from typing import List
from fastapi import APIRouter, Depends, File, Form, UploadFile, HTTPException
from sqlalchemy.orm import Session
from PIL import Image
from database import get_db
from config import get_settings
from detection.yolo_service import detect_disease, detect_multi
from detection.gemini_service import generate_advice
from detection.image_validator import validate_image

router = APIRouter(prefix="/detect", tags=["Detection"])

# Valid language codes
VALID_LANGUAGES = {"en", "mr", "hi"}

# Max image size: 10MB
MAX_IMAGE_SIZE = 10 * 1024 * 1024

# Max images for multi-upload
MAX_MULTI_IMAGES = 5


def _validate_language(language: str) -> str:
    """Validate and return language code."""
    if language not in VALID_LANGUAGES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid language '{language}'. Must be one of: {', '.join(VALID_LANGUAGES)}"
        )
    return language


def _validate_location(location: str) -> str:
    """Validate and return location string."""
    if not location or not location.strip():
        return "Maharashtra"
    return location.strip()


async def _read_and_validate_image(image: UploadFile) -> bytes:
    """Read and validate an uploaded image file."""
    # Validate file type
    valid_types = ("image/jpeg", "image/png", "image/webp", "image/jpg")
    if image.content_type not in valid_types:
        raise HTTPException(
            status_code=400,
            detail={
                "error": "invalid_format",
                "message": "Only JPEG, PNG, and WebP images are supported",
                "message_mr": "फक्त JPEG, PNG आणि WebP प्रतिमा स्वीकारल्या जातात",
                "message_hi": "केवल JPEG, PNG और WebP छवियां स्वीकार की जाती हैं",
            }
        )

    contents = await image.read()

    if len(contents) > MAX_IMAGE_SIZE:
        raise HTTPException(
            status_code=400,
            detail={
                "error": "too_large",
                "message": f"Image too large. Maximum size is {MAX_IMAGE_SIZE // (1024 * 1024)}MB",
                "message_mr": f"प्रतिमा खूप मोठी आहे. कमाल आकार {MAX_IMAGE_SIZE // (1024 * 1024)}MB",
                "message_hi": f"छवि बहुत बड़ी है। अधिकतम आकार {MAX_IMAGE_SIZE // (1024 * 1024)}MB",
            }
        )

    return contents


def _get_weather_context(location: str) -> dict:
    """Fetch current weather for context in disease advice (sync for simplicity)."""
    try:
        import httpx
        from weather.router import MAHARASHTRA_CITIES, _get_condition

        city_key = location.lower().strip()
        coords = MAHARASHTRA_CITIES.get(city_key, MAHARASHTRA_CITIES.get("default", (18.52, 73.86)))
        latitude, longitude = coords

        url = (
            f"https://api.open-meteo.com/v1/forecast"
            f"?latitude={latitude}&longitude={longitude}"
            f"&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code,precipitation"
            f"&daily=precipitation_probability_max"
            f"&forecast_days=3"
            f"&timezone=Asia/Kolkata"
        )

        response = httpx.get(url, timeout=5.0)
        data = response.json()
        current = data.get("current", {})
        daily = data.get("daily", {})

        rain_probs = daily.get("precipitation_probability_max", [])
        rain_chance = rain_probs[0] if rain_probs else 0

        return {
            "temperature": round(current.get("temperature_2m", 28)),
            "humidity": round(current.get("relative_humidity_2m", 65)),
            "wind_speed": round(current.get("wind_speed_10m", 10)),
            "precipitation": round(current.get("precipitation", 0), 1),
            "rain_chance_today": rain_chance,
        }
    except Exception as e:
        print(f"⚠️ Weather context fetch failed: {e}")
        return {
            "temperature": 28,
            "humidity": 65,
            "wind_speed": 10,
            "precipitation": 0,
            "rain_chance_today": 20,
        }


def _build_response(detection: dict, advice: dict, validation: dict = None) -> dict:
    """Build the standardized API response."""
    treatments = []
    for t in advice.get("treatments", []):
        treatments.append({
            "title": t.get("title", ""),
            "title_mr": t.get("title_mr", t.get("title", "")),
            "title_hi": t.get("title_hi", t.get("title", "")),
            "description": t.get("description", ""),
            "description_mr": t.get("description_mr", t.get("description", "")),
            "description_hi": t.get("description_hi", t.get("description", "")),
            "icon": t.get("icon", "💊"),
        })

    response = {
        "success": True,
        "detection": {
            "label": detection["disease_name"].replace("_", " "),
            "label_mr": detection["disease_name_mr"],
            "label_hi": detection["disease_name_hi"],
            "confidence": detection["confidence"],
            "severity": advice.get("severity", detection["severity"]),
            "box": detection["box"],
            "is_healthy": detection.get("is_healthy", False),
            "is_low_confidence": detection.get("is_low_confidence", False),
            "suggestion": detection.get("suggestion"),
            "crop": "Rice",
        },
        "advice": {
            "explanation": advice.get("explanation", ""),
            "full_description": advice.get("full_description", ""),
            "causes": advice.get("causes", []),
            "treatments": treatments,
            "prevention": advice.get("prevention", []),
            "medicine_availability": advice.get("medicine_availability", ""),
            "next_7_day_care": advice.get("next_7_day_care", ""),
            "spray_timing": advice.get("spray_timing", ""),
            "disease_spread_risk": advice.get("disease_spread_risk", ""),
            "watering_advice": advice.get("watering_advice", ""),
            "fertilizer_caution": advice.get("fertilizer_caution", ""),
            "from_cache": advice.get("from_cache", False),
        },
        "all_detections": detection.get("all_detections", []),
    }

    # Add validation info if available
    if validation:
        response["validation"] = {
            "valid": validation.get("valid", True),
            "quality_score": validation.get("quality_score", 7),
            "issues": validation.get("issues", []),
            "message": validation.get("message", ""),
            "message_en": validation.get("message_en", ""),
            "message_mr": validation.get("message_mr", ""),
            "message_hi": validation.get("message_hi", ""),
        }

    return response


@router.post("/analyze")
async def analyze_image(
    image: UploadFile = File(...),
    language: str = Form("en"),
    location: str = Form("Maharashtra"),
    db: Session = Depends(get_db),
):
    """
    Analyze a crop image for disease detection.

    Pipeline: Validate image → YOLOv8 detection → Gemini advice → response

    Parameters:
    - **image**: JPEG/PNG/WebP image (max 10MB)
    - **language**: Language code - 'en', 'mr', or 'hi' (default: 'en')
    - **location**: City/district name (default: 'Maharashtra')

    Returns Plantix-style diagnosis with Maharashtra-specific advice.
    """
    settings = get_settings()
    language = _validate_language(language)
    location = _validate_location(location)

    # Read and validate image format/size
    try:
        contents = await _read_and_validate_image(image)
        pil_image = Image.open(io.BytesIO(contents)).convert("RGB")
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=400, detail="Could not process the uploaded image")

    # Step 1: Image validation
    print(f"🔍 Validating image for {language}/{location}...")
    validation = validate_image(
        pil_image,
        api_key=settings.openrouter_api_key,
        language=language,
    )

    if not validation["can_proceed"]:
        # Image is not a plant — reject
        return {
            "success": False,
            "validation_error": True,
            "validation": {
                "valid": False,
                "quality_score": validation["quality_score"],
                "issues": validation["issues"],
                "message": validation["message"],
                "message_en": validation["message_en"],
                "message_mr": validation["message_mr"],
                "message_hi": validation["message_hi"],
            },
        }

    # Step 2: YOLOv8 detection
    print(f"🔬 Running YOLOv8 detection...")
    detection = detect_disease(pil_image)

    # Step 3: Get weather context for advice
    weather = _get_weather_context(location)

    # Step 4: Get Gemini advice
    advice = generate_advice(
        api_key=settings.openrouter_api_key,
        disease_name=detection["disease_name"],
        confidence=detection["confidence"],
        location=location,
        language=language,
        db=db,
        weather=weather,
    )

    return _build_response(detection, advice, validation)


@router.post("/analyze-multi")
async def analyze_multi_images(
    images: List[UploadFile] = File(...),
    language: str = Form("en"),
    location: str = Form("Maharashtra"),
    db: Session = Depends(get_db),
):
    """
    Analyze multiple crop images for disease detection (advanced scan).

    Pipeline: Validate each → YOLOv8 multi-detect → Aggregate → Gemini advice

    Parameters:
    - **images**: 2-5 JPEG/PNG/WebP images (max 10MB each)
    - **language**: Language code - 'en', 'mr', or 'hi'
    - **location**: City/district name

    Returns aggregated Plantix-style diagnosis with per-image details.
    """
    settings = get_settings()
    language = _validate_language(language)
    location = _validate_location(location)

    if len(images) > MAX_MULTI_IMAGES:
        raise HTTPException(
            status_code=400,
            detail={
                "error": "too_many_images",
                "message": f"Maximum {MAX_MULTI_IMAGES} images allowed",
                "message_mr": f"कमाल {MAX_MULTI_IMAGES} प्रतिमा स्वीकारल्या जातात",
                "message_hi": f"अधिकतम {MAX_MULTI_IMAGES} छवियां स्वीकार की जाती हैं",
            }
        )

    if len(images) < 1:
        raise HTTPException(status_code=400, detail="At least 1 image is required")

    # Read all images and validate
    pil_images = []
    validation_results = []

    for idx, img in enumerate(images):
        try:
            contents = await _read_and_validate_image(img)
            pil_img = Image.open(io.BytesIO(contents)).convert("RGB")

            # Validate each image (skip Gemini for speed, use CV only for multi)
            val = validate_image(
                pil_img,
                api_key=settings.openrouter_api_key,
                language=language,
                skip_gemini=(idx > 0),  # Only Gemini-validate first image for speed
            )
            validation_results.append(val)

            if val["can_proceed"]:
                pil_images.append(pil_img)
            else:
                print(f"⚠️ Image {idx + 1} rejected: {val['issues']}")
        except HTTPException:
            raise
        except Exception as e:
            print(f"⚠️ Image {idx + 1} failed to process: {e}")

    if not pil_images:
        # All images rejected
        return {
            "success": False,
            "validation_error": True,
            "validation": {
                "valid": False,
                "issues": ["all_images_rejected"],
                "message": VALIDATION_MESSAGES_MULTI[language],
                "per_image": validation_results,
            },
        }

    # Run multi-image detection
    print(f"🔬 Running multi-image detection on {len(pil_images)} images...")
    detection = detect_multi(pil_images)

    # Get weather context
    weather = _get_weather_context(location)

    # Get Gemini advice (once, for best detection)
    advice = generate_advice(
        api_key=settings.openrouter_api_key,
        disease_name=detection["disease_name"],
        confidence=detection["confidence"],
        location=location,
        language=language,
        db=db,
        weather=weather,
    )

    response = _build_response(detection, advice)
    response["multi_scan"] = {
        "total_images": len(images),
        "valid_images": len(pil_images),
        "rejected_images": len(images) - len(pil_images),
        "per_image_results": detection.get("per_image_results", []),
        "agreement_count": detection.get("agreement_count", 0),
        "per_image_validation": [
            {"index": i, "valid": v["valid"], "issues": v["issues"]}
            for i, v in enumerate(validation_results)
        ],
    }

    return response


# Multi-image rejection messages
VALIDATION_MESSAGES_MULTI = {
    "en": "None of the uploaded images contain valid crop/leaf content. Please upload clear photos of the affected plant.",
    "mr": "अपलोड केलेल्या कोणत्याही प्रतिमेमध्ये वैध पीक/पान सापडले नाही. कृपया प्रभावित रोपाचे स्पष्ट फोटो अपलोड करा.",
    "hi": "अपलोड की गई किसी भी छवि में वैध फसल/पत्ती नहीं मिली। कृपया प्रभावित पौधे की स्पष्ट तस्वीरें अपलोड करें।",
}


@router.get("/health")
def detection_health():
    """Check if the detection module is loaded."""
    from detection.yolo_service import _model, WEIGHTS_PATH
    from pathlib import Path

    return {
        "status": "ok",
        "model_loaded": _model is not None,
        "weights_exist": Path(WEIGHTS_PATH).resolve().exists(),
        "disease_classes": 8,
        "crop": "Rice",
        "features": ["single_scan", "multi_scan", "image_validation", "confidence_gating"],
    }
