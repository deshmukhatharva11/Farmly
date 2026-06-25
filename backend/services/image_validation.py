"""
Image validation service — fast local checks before any AI call.

Checks performed:
1. File extension: JPG, JPEG, PNG, WEBP only
2. File size: max 8 MB
3. Corrupt file detection (PIL verify)
4. Minimum resolution: 100×100 pixels (relaxed to allow phone close-ups)
5. Blur detection (Laplacian variance)
6. Brightness analysis (too dark / too bright)
"""

import io
import numpy as np
from PIL import Image
from typing import Tuple

# Lazy OpenCV import
_cv2 = None


def _get_cv2():
    global _cv2
    if _cv2 is None:
        try:
            import cv2
            _cv2 = cv2
        except ImportError:
            _cv2 = False
    return _cv2 if _cv2 is not False else None


# ── Constants ────────────────────────────────────────────────────

ALLOWED_EXTENSIONS = {"jpg", "jpeg", "png", "webp"}
ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp", "image/jpg"}
MAX_FILE_SIZE = 8 * 1024 * 1024  # 8 MB
MIN_DIMENSION = 100  # 100×100 minimum (relaxed — phone close-ups can be small)

BLUR_THRESHOLD = 50.0  # Laplacian variance below this → blurry
DARK_THRESHOLD = 40.0  # Mean brightness below this → too dark
BRIGHT_THRESHOLD = 240.0  # Mean brightness above this → too bright


def validate_upload(
    file_bytes: bytes,
    filename: str,
    content_type: str | None = None,
) -> dict:
    """
    Validate an uploaded image file before any AI processing.

    Returns:
        {
            "valid": bool,
            "issues": ["blurry", "too_dark", ...],
            "message": str,
            "pil_image": Image | None  (only if valid enough to proceed)
        }
    """
    issues = []

    # ── 1. File extension ────────────────────────────────────────
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    if ext not in ALLOWED_EXTENSIONS:
        return _fail(
            "invalid_format",
            f"Unsupported file format '.{ext}'. Please upload JPG, PNG, or WEBP.",
        )

    # ── 2. MIME type (if provided) ───────────────────────────────
    if content_type and content_type not in ALLOWED_MIME_TYPES:
        return _fail(
            "invalid_format",
            "Unsupported file type. Only JPEG, PNG, and WebP images are accepted.",
        )

    # ── 3. File size ─────────────────────────────────────────────
    if len(file_bytes) > MAX_FILE_SIZE:
        size_mb = len(file_bytes) / (1024 * 1024)
        return _fail(
            "too_large",
            f"Image is {size_mb:.1f} MB. Maximum allowed size is 8 MB.",
        )

    # ── 4. Corrupt file detection ────────────────────────────────
    try:
        # First pass: verify() checks internal consistency
        img_verify = Image.open(io.BytesIO(file_bytes))
        img_verify.verify()

        # Second pass: actually load pixel data (verify() closes the file)
        pil_image = Image.open(io.BytesIO(file_bytes)).convert("RGB")
        # Force load to catch truncated files
        pil_image.load()
    except Exception:
        return _fail(
            "corrupt",
            "The image file appears to be corrupt. Please upload a valid image.",
        )

    # ── 5. Minimum resolution ────────────────────────────────────
    w, h = pil_image.size
    if w < MIN_DIMENSION or h < MIN_DIMENSION:
        return _fail(
            "too_small",
            f"Image is too small ({w}×{h} px). Please use a higher resolution photo.",
        )

    # ── 6. Quality checks (blur, brightness) ─────────────────────
    quality_issues = _check_image_quality(pil_image)
    issues.extend(quality_issues)

    # Build final result
    if issues:
        # Quality issues are warnings, still allow proceeding
        primary = issues[0]
        messages = {
            "blurry": "The image appears blurry. For best results, hold your camera steady and ensure the leaf is in focus.",
            "too_dark": "The image is too dark. Please take the photo in better lighting conditions.",
            "too_bright": "The image is overexposed. Please avoid direct sunlight glare.",
        }
        return {
            "valid": False,
            "can_proceed": True,  # Warnings, not hard blocks
            "issues": issues,
            "message": messages.get(primary, "Image quality issue detected."),
            "pil_image": pil_image,
        }

    return {
        "valid": True,
        "can_proceed": True,
        "issues": [],
        "message": "Image validated successfully.",
        "pil_image": pil_image,
    }


def _check_image_quality(pil_image: Image.Image) -> list[str]:
    """OpenCV-based blur and brightness checks."""
    cv2 = _get_cv2()
    if cv2 is None:
        return []  # Skip if OpenCV unavailable

    img_array = np.array(pil_image)
    gray = cv2.cvtColor(img_array, cv2.COLOR_RGB2GRAY)

    issues = []

    # Blur detection (Laplacian variance)
    laplacian_var = cv2.Laplacian(gray, cv2.CV_64F).var()
    if laplacian_var < BLUR_THRESHOLD:
        issues.append("blurry")

    # Brightness check
    mean_brightness = float(np.mean(gray))
    if mean_brightness < DARK_THRESHOLD:
        issues.append("too_dark")
    elif mean_brightness > BRIGHT_THRESHOLD:
        issues.append("too_bright")

    return issues


def _fail(issue: str, message: str) -> dict:
    """Return a hard-fail validation result."""
    return {
        "valid": False,
        "can_proceed": False,
        "issues": [issue],
        "message": message,
        "pil_image": None,
    }
