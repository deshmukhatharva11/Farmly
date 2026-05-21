"""
Image validation service for crop disease detection.

Validates uploaded images before running YOLOv8 detection:
1. Fast OpenCV pre-checks (blur, brightness, green-channel dominance)
2. Gemini Vision validation (is this a plant/leaf?)

Returns structured validation result with trilingual messages.
"""

import io
import numpy as np
from PIL import Image
from typing import Optional

# Lazy imports for OpenCV (may not be installed everywhere)
_cv2 = None


def _get_cv2():
    """Lazy-load OpenCV."""
    global _cv2
    if _cv2 is None:
        try:
            import cv2
            _cv2 = cv2
        except ImportError:
            _cv2 = False  # Mark as unavailable
    return _cv2 if _cv2 is not False else None


# ─── Validation Messages (trilingual) ───────────────────────────

VALIDATION_MESSAGES = {
    "not_plant": {
        "en": "This image does not appear to contain a crop or leaf. Please upload a clear photo of the affected plant.",
        "mr": "या प्रतिमेमध्ये पीक किंवा पान दिसत नाही. कृपया प्रभावित रोपाचा स्पष्ट फोटो अपलोड करा.",
        "hi": "इस छवि में कोई फसल या पत्ती नहीं दिख रही है। कृपया प्रभावित पौधे की स्पष्ट तस्वीर अपलोड करें।",
    },
    "blurry": {
        "en": "The image is too blurry. Please capture a sharper photo of the leaf.",
        "mr": "प्रतिमा खूप धूसर आहे. कृपया पानाचा अधिक स्पष्ट फोटो घ्या.",
        "hi": "छवि बहुत धुंधली है। कृपया पत्ती की अधिक स्पष्ट तस्वीर लें।",
    },
    "too_dark": {
        "en": "The image is too dark. Please capture the photo in better lighting.",
        "mr": "प्रतिमा खूप गडद आहे. कृपया चांगल्या प्रकाशात फोटो घ्या.",
        "hi": "छवि बहुत अंधेरी है। कृपया बेहतर रोशनी में तस्वीर लें।",
    },
    "too_bright": {
        "en": "The image is overexposed. Please avoid direct sunlight glare.",
        "mr": "प्रतिमा जास्त उजळ आहे. कृपया थेट सूर्यप्रकाश टाळा.",
        "hi": "छवि अत्यधिक चमकीली है। कृपया सीधी धूप से बचें।",
    },
    "small_subject": {
        "en": "The leaf appears too small in the image. Please move closer and capture again.",
        "mr": "प्रतिमेमध्ये पान खूप लहान दिसत आहे. कृपया जवळ जाऊन पुन्हा फोटो घ्या.",
        "hi": "छवि में पत्ती बहुत छोटी दिख रही है। कृपया करीब जाकर फिर से तस्वीर लें।",
    },
    "valid": {
        "en": "Image validated successfully.",
        "mr": "प्रतिमा यशस्वीरित्या तपासली.",
        "hi": "छवि सफलतापूर्वक सत्यापित।",
    },
}


# ─── OpenCV Pre-checks ──────────────────────────────────────────

def _opencv_precheck(pil_image: Image.Image) -> dict:
    """
    Fast OpenCV-based image quality checks.
    Returns: {"passed": bool, "issues": [...], "scores": {...}}
    """
    cv2 = _get_cv2()
    if cv2 is None:
        # OpenCV not available, skip pre-checks
        return {"passed": True, "issues": [], "scores": {}}

    # Convert PIL to OpenCV format
    img_array = np.array(pil_image)
    if len(img_array.shape) == 2:
        # Grayscale
        gray = img_array
        bgr = cv2.cvtColor(img_array, cv2.COLOR_GRAY2BGR)
    else:
        bgr = cv2.cvtColor(img_array, cv2.COLOR_RGB2BGR)
        gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)

    issues = []
    scores = {}

    # 1. Blur detection (Laplacian variance)
    laplacian_var = cv2.Laplacian(gray, cv2.CV_64F).var()
    scores["sharpness"] = round(float(laplacian_var), 2)
    if laplacian_var < 50:
        issues.append("blurry")

    # 2. Brightness check (mean pixel value)
    mean_brightness = float(np.mean(gray))
    scores["brightness"] = round(mean_brightness, 2)
    if mean_brightness < 40:
        issues.append("too_dark")
    elif mean_brightness > 240:
        issues.append("too_bright")

    # 3. Green channel dominance (plant detection heuristic)
    if len(img_array.shape) == 3:
        # Convert to HSV for better green detection
        hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)

        # Green range in HSV
        lower_green = np.array([25, 30, 30])
        upper_green = np.array([95, 255, 255])
        green_mask = cv2.inRange(hsv, lower_green, upper_green)

        green_ratio = float(np.count_nonzero(green_mask)) / green_mask.size
        scores["green_ratio"] = round(green_ratio, 4)

        # Also check for brown/yellow (diseased leaves)
        lower_brown = np.array([10, 30, 30])
        upper_brown = np.array([30, 255, 255])
        brown_mask = cv2.inRange(hsv, lower_brown, upper_brown)
        brown_ratio = float(np.count_nonzero(brown_mask)) / brown_mask.size
        scores["brown_ratio"] = round(brown_ratio, 4)

        # Plant-like content: green + brown/yellow should be significant
        plant_ratio = green_ratio + brown_ratio
        scores["plant_ratio"] = round(plant_ratio, 4)

        if plant_ratio < 0.05:
            # Very little plant-like color — suspicious
            issues.append("low_plant_content")
    else:
        scores["green_ratio"] = 0.0
        scores["plant_ratio"] = 0.0

    # 4. Image size check (subject should fill frame)
    h, w = gray.shape[:2]
    if h < 200 or w < 200:
        issues.append("small_subject")

    return {
        "passed": len([i for i in issues if i in ("blurry", "too_dark", "too_bright")]) == 0,
        "issues": issues,
        "scores": scores,
    }


# ─── Gemini Vision Validation ───────────────────────────────────

def _gemini_vision_validate(pil_image: Image.Image, api_key: str) -> dict:
    """
    Use Gemini Vision via OpenRouter to validate if image contains a plant/leaf.
    Returns: {"is_plant": bool, "quality_score": int, "description": str}
    """
    try:
        import base64
        from openai import OpenAI

        # Convert PIL image to base64
        buffer = io.BytesIO()
        # Resize for faster validation (max 512px)
        img = pil_image.copy()
        img.thumbnail((512, 512), Image.Resampling.LANCZOS)
        img.save(buffer, format="JPEG", quality=70)
        img_base64 = base64.b64encode(buffer.getvalue()).decode("utf-8")

        client = OpenAI(
            base_url="https://openrouter.ai/api/v1",
            api_key=api_key,
        )

        response = client.chat.completions.create(
            model="google/gemini-2.0-flash-001",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": """Analyze this image and respond ONLY with valid JSON:
{
  "is_plant": true/false,
  "is_leaf": true/false,
  "is_crop": true/false,
  "quality_score": 1-10,
  "issues": [],
  "description": "brief description"
}

Rules:
- "is_plant": true if image shows any plant, leaf, crop, tree, vegetation
- "is_leaf": true if a leaf is clearly visible
- "is_crop": true if it appears to be an agricultural crop
- "quality_score": 1=terrible, 10=perfect. Consider focus, lighting, leaf visibility
- "issues": array of any issues from: ["blurry", "too_dark", "too_bright", "small_subject", "no_leaf_visible", "not_plant"]
- "description": one-line description of what you see

Respond ONLY with JSON, nothing else.""",
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{img_base64}",
                            },
                        },
                    ],
                }
            ],
            temperature=0.1,
            max_tokens=300,
        )

        import json
        text = response.choices[0].message.content.strip()

        # Clean markdown fences
        if text.startswith("```"):
            text = text.split("\n", 1)[1]
            if "```" in text:
                text = text[:text.rfind("```")]
            text = text.strip()

        result = json.loads(text)

        return {
            "is_plant": result.get("is_plant", False) or result.get("is_leaf", False) or result.get("is_crop", False),
            "quality_score": result.get("quality_score", 5),
            "issues": result.get("issues", []),
            "description": result.get("description", ""),
        }

    except Exception as e:
        print(f"⚠️ Gemini Vision validation failed: {e}")
        # Return uncertain — don't block on validation failure
        return {
            "is_plant": True,  # Give benefit of doubt
            "quality_score": 5,
            "issues": [],
            "description": "Validation skipped (API error)",
        }


# ─── Main Validation Function ───────────────────────────────────

def validate_image(
    pil_image: Image.Image,
    api_key: str,
    language: str = "en",
    skip_gemini: bool = False,
) -> dict:
    """
    Validate an uploaded image for crop disease detection.

    Pipeline:
    1. OpenCV pre-checks (fast: blur, brightness, green content)
    2. Gemini Vision check (is this a plant/leaf?)

    Returns:
    {
        "valid": bool,
        "can_proceed": bool,  # True if valid or has warnings but can still try
        "issues": ["blurry", "not_plant", ...],
        "quality_score": int (1-10),
        "message": str (localized),
        "message_en": str,
        "message_mr": str,
        "message_hi": str,
        "cv_scores": {...},
    }
    """
    all_issues = []
    quality_score = 7  # Default reasonable score

    # Step 1: OpenCV pre-checks
    cv_result = _opencv_precheck(pil_image)
    all_issues.extend(cv_result["issues"])
    cv_scores = cv_result["scores"]

    # Adjust quality score based on CV checks
    if "blurry" in all_issues:
        quality_score -= 3
    if "too_dark" in all_issues:
        quality_score -= 2
    if "too_bright" in all_issues:
        quality_score -= 2

    # Step 2: Gemini Vision validation (if API key available and not skipped)
    gemini_result = None
    if api_key and not skip_gemini:
        # Only call Gemini if CV pre-check suggests possible non-plant
        needs_gemini = (
            "low_plant_content" in all_issues
            or cv_scores.get("plant_ratio", 1.0) < 0.15
            or len(all_issues) == 0  # Always validate if no CV issues
        )

        if needs_gemini:
            gemini_result = _gemini_vision_validate(pil_image, api_key)
            quality_score = gemini_result.get("quality_score", quality_score)

            if not gemini_result["is_plant"]:
                all_issues.append("not_plant")
            # Merge Gemini issues
            for issue in gemini_result.get("issues", []):
                if issue not in all_issues:
                    all_issues.append(issue)

    # Remove duplicates
    all_issues = list(dict.fromkeys(all_issues))

    # Determine validity
    is_not_plant = "not_plant" in all_issues or "no_leaf_visible" in all_issues
    has_quality_issues = any(i in all_issues for i in ("blurry", "too_dark", "too_bright"))
    has_size_issue = "small_subject" in all_issues

    # Build response
    if is_not_plant:
        primary_issue = "not_plant"
        valid = False
        can_proceed = False
    elif has_quality_issues:
        # Quality issues are warnings — still allow detection attempt
        primary_issue = next(i for i in all_issues if i in ("blurry", "too_dark", "too_bright"))
        valid = False
        can_proceed = True  # Can still try
    elif has_size_issue:
        primary_issue = "small_subject"
        valid = False
        can_proceed = True
    else:
        primary_issue = "valid"
        valid = True
        can_proceed = True

    messages = VALIDATION_MESSAGES.get(primary_issue, VALIDATION_MESSAGES["valid"])

    return {
        "valid": valid,
        "can_proceed": can_proceed,
        "issues": all_issues,
        "quality_score": max(1, min(10, quality_score)),
        "message": messages.get(language, messages["en"]),
        "message_en": messages["en"],
        "message_mr": messages["mr"],
        "message_hi": messages["hi"],
        "cv_scores": cv_scores,
        "gemini_result": gemini_result,
    }
