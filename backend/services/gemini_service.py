"""
Gemini advisory service using google-genai SDK.

Generates and translates disease treatment advisories.
Uses native Google Gemini API (not OpenRouter).

Endpoints served:
- generate_advisory() → POST /api/generate-advisory
- translate_advisory() → POST /api/translate-advisory

Advisory JSON schema:
{
    "summary": "",
    "symptoms": [],
    "possible_causes": [],
    "prevention": [],
    "recommended_actions": [],
    "safety_note": ""
}

Rules:
- Never invent pesticide dosage
- Never present advice as guaranteed
- Always include safety note
- Support English, Hindi, Marathi
"""

import json
import os
import time
import base64
from typing import Optional
from typing import Optional

# Lazy-loaded Gemini client
_client = None
_primary_key_exhausted = False


def _get_client(force_fallback=False):
    """Get or create the appropriate client: native Gemini or OpenRouter."""
    global _client, _primary_key_exhausted
    
    if force_fallback:
        _primary_key_exhausted = True
        _client = None

    if _client is not None:
        return _client

    if not _primary_key_exhausted:
        api_key = os.environ.get("GEMINI_API_KEY", "")
        if api_key:
            try:
                from google import genai
                client = genai.Client(api_key=api_key)
                _client = ("gemini", client)
                return _client
            except ImportError:
                pass

        # Fallback to OpenRouter
        openrouter_key = os.environ.get("OPENROUTER_API_KEY", "")
        if openrouter_key:
            try:
                from openai import OpenAI
                client = OpenAI(base_url="https://openrouter.ai/api/v1", api_key=openrouter_key)
                _client = ("openrouter", client)
                return _client
            except ImportError:
                pass

    # Attempt Fallback API Key
    fallback_key = os.environ.get("OPENROUTER_FALLBACK_API_KEY", "")
    if fallback_key:
        try:
            from openai import OpenAI
            client = OpenAI(base_url="https://openrouter.ai/api/v1", api_key=fallback_key)
            _client = ("openrouter", client)
            print("[Farmly] Using OPENROUTER_FALLBACK_API_KEY")
            return _client
        except ImportError:
            pass

    raise RuntimeError(
        "Neither GEMINI_API_KEY nor OPENROUTER_API_KEY (or fallback) environment variable is set. "
        "Please configure them in your .env file."
    )


ADVISORY_SCHEMA = """{
    "summary": "2-3 sentence overview of this disease and its impact on the crop",
    "symptoms": ["symptom 1", "symptom 2", "symptom 3"],
    "possible_causes": ["cause 1", "cause 2", "cause 3"],
    "prevention": ["prevention tip 1", "prevention tip 2", "prevention tip 3"],
    "recommended_actions": [
        "specific action 1 with product names if applicable",
        "specific action 2",
        "specific action 3"
    ],
    "safety_note": "Always follow local agricultural extension office guidance and product label instructions before applying any treatment."
}"""


def generate_advisory(
    crop: str,
    disease: str,
    confidence: float,
    language: str = "English",
) -> dict:
    """
    Generate AI advisory for a detected crop disease.

    Args:
        crop: Detected crop name (from YOLO)
        disease: Detected disease name (from classifier)
        confidence: Disease detection confidence (0-1)
        language: Target language (English, Hindi, Marathi)

    Returns:
        Advisory JSON dict or error dict.
    """
    try:
        client_info = _get_client()
    except RuntimeError as e:
        print(f"[Farmly] WARN: {e} - Using fallback advisory.")
        return _fallback_advisory(crop, disease, language)

    client_type, client = client_info
    lang_instruction = _get_language_instruction(language)

    prompt = f"""You are an expert agricultural advisor specializing in crop disease management.

CONTEXT:
- Crop: {crop}
- Crop detection confidence: {confidence*100:.1f}%
- Disease: {disease}
- Disease detection confidence: {confidence*100:.1f}%
- Language requested: {language}

{lang_instruction}

STRICT RULES:
1. Do NOT invent specific pesticide dosages — only suggest general product categories
2. Do NOT present advice as guaranteed cures
3. ALWAYS include a safety note advising users to consult local agricultural officers
4. Be practical and farmer-friendly
5. If the disease is "Healthy" or indicates no disease, say the plant appears healthy

Respond with ONLY valid JSON in this exact structure:
{ADVISORY_SCHEMA}

Respond ONLY with the JSON object, no markdown fences, no explanation."""

    return _run_gemini_prompt(client_type, client, prompt, crop, disease, language)

def analyze_image_vision(
    image_bytes: bytes,
    mime_type: str = "image/jpeg",
    language: str = "English",
) -> dict:
    """
    Analyze crop image directly using Gemini Vision.
    Returns JSON with crop, disease, confidence, and advisory.
    """
    try:
        client_info = _get_client()
    except RuntimeError as e:
        return {"status": "error", "message": str(e), "_error": str(e)}

    client_type, client = client_info
    lang_instruction = _get_language_instruction(language)

    prompt = f"""You are an expert agricultural AI. Analyze this image of a plant/crop leaf.

TASK:
1. Identify the crop/plant.
2. Diagnose any visible disease, pest, or nutrient deficiency. If healthy, state that.
3. Provide an advisory.
4. Language requested: {language}

{lang_instruction}

STRICT RULES:
1. Do NOT invent specific pesticide dosages — only suggest general product categories.
2. ALWAYS include a safety note advising users to consult local agricultural officers.
3. Be practical and farmer-friendly.

Respond with ONLY valid JSON in this EXACT structure:
{{
    "crop": "Name of crop (e.g. Tomato)",
    "disease": "Name of disease/issue (e.g. Tomato Early Blight, or Healthy)",
    "confidence": 0.95,
    "advisory": {ADVISORY_SCHEMA}
}}

Respond ONLY with the JSON object, no markdown fences, no explanation."""

    max_retries = 3
    for attempt in range(max_retries):
        try:
            if client_type == "gemini":
                # For google-genai, we can pass PIL Image directly
                from google import genai
                from PIL import Image
                import io
                
                img = Image.open(io.BytesIO(image_bytes))
                response = client.models.generate_content(
                    model="gemini-2.5-flash",
                    contents=[img, prompt],
                )
                text = response.text.strip()
            else:
                # OpenRouter format
                base64_image = base64.b64encode(image_bytes).decode('utf-8')
                model_name = os.environ.get("AI_MODEL", "google/gemini-2.5-flash")
                response = client.chat.completions.create(
                    model=model_name,
                    messages=[{
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {"type": "image_url", "image_url": {"url": f"data:{mime_type};base64,{base64_image}"}}
                        ]
                    }],
                    max_tokens=1500,
                )
                text = response.choices[0].message.content.strip()

            if text.startswith("```"):
                text = text.split("\n", 1)[1]
                if "```" in text:
                    text = text[:text.rfind("```")]
                text = text.strip()

            result = json.loads(text)
            
            # Ensure safety note is present
            if "advisory" in result and not result["advisory"].get("safety_note"):
                result["advisory"]["safety_note"] = (
                    "Always follow local agricultural extension office guidance "
                    "and product label instructions before applying any treatment."
                )

            print(f"[Farmly] Vision analysis generated for {result.get('crop')}/{result.get('disease')} via {client_type}")
            result["status"] = "success"
            return result

        except json.JSONDecodeError as e:
            print(f"[Farmly] WARN: Invalid JSON from Vision AI (attempt {attempt + 1}): {e}")
            if attempt < max_retries - 1:
                time.sleep(1)
                continue
            return {"status": "error", "message": "Failed to parse AI response."}
        except Exception as e:
            error_str = str(e).lower()
            if "429" in error_str or "rate limit" in error_str or "quota" in error_str:
                print(f"[Farmly] Rate limit exceeded in Vision AI. Switching to fallback API key...")
                try:
                    client_type, client = _get_client(force_fallback=True)
                    continue
                except Exception as fb_err:
                    print(f"[Farmly] Fallback client init failed: {fb_err}")
            print(f"[Farmly] WARN: Vision AI API error (attempt {attempt + 1}): {e}")
            if attempt < max_retries - 1:
                time.sleep(2)
                continue
            return {"status": "error", "message": f"AI API error: {e}"}

    return {"status": "error", "message": "Failed after retries."}

def _run_gemini_prompt(client_type, client, prompt, crop, disease, language) -> dict:
    max_retries = 3
    for attempt in range(max_retries):
        try:
            if client_type == "gemini":
                response = client.models.generate_content(
                    model="gemini-2.5-flash",
                    contents=prompt,
                )
                text = response.text.strip()
            else:
                model_name = os.environ.get("AI_MODEL", "google/gemini-2.5-flash")
                response = client.chat.completions.create(
                    model=model_name,
                    messages=[{"role": "user", "content": prompt}],
                    max_tokens=1000,
                )
                text = response.choices[0].message.content.strip()

            # Clean markdown fences if present
            if text.startswith("```"):
                text = text.split("\n", 1)[1]
                if "```" in text:
                    text = text[:text.rfind("```")]
                text = text.strip()

            advisory = json.loads(text)

            # Validate required keys
            required_keys = [
                "summary", "symptoms", "possible_causes",
                "prevention", "recommended_actions", "safety_note",
            ]
            for key in required_keys:
                if key not in advisory:
                    advisory[key] = [] if key in (
                        "symptoms", "possible_causes",
                        "prevention", "recommended_actions"
                    ) else ""

            # Ensure safety note is present
            if not advisory.get("safety_note"):
                advisory["safety_note"] = (
                    "Always follow local agricultural extension office guidance "
                    "and product label instructions before applying any treatment."
                )

            print(f"[Farmly] Advisory generated for {crop}/{disease}/{language} via {client_type}")
            return advisory

        except json.JSONDecodeError as e:
            print(f"[Farmly] WARN: Invalid JSON from AI (attempt {attempt + 1}): {e}")
            if attempt < max_retries - 1:
                time.sleep(1)
                continue
            return _fallback_advisory(crop, disease, language)
        except Exception as e:
            error_str = str(e).lower()
            if "429" in error_str or "rate limit" in error_str or "quota" in error_str:
                print(f"[Farmly] Rate limit exceeded in prompt generation. Switching to fallback API key...")
                try:
                    client_type, client = _get_client(force_fallback=True)
                    continue
                except Exception as fb_err:
                    print(f"[Farmly] Fallback client init failed: {fb_err}")
            print(f"[Farmly] WARN: AI API error (attempt {attempt + 1}): {e}")
            if attempt < max_retries - 1:
                time.sleep(2)
                continue
            return _fallback_advisory(crop, disease, language)

    return _fallback_advisory(crop, disease, language)


def translate_advisory(
    advisory: dict,
    language: str,
) -> dict:
    """
    Translate an existing advisory to a different language.
    Does NOT rerun disease detection.

    Args:
        advisory: Existing advisory JSON dict
        language: Target language (English, Hindi, Marathi)

    Returns:
        Translated advisory JSON dict.
    """
    try:
        client_info = _get_client()
    except RuntimeError as e:
        return _error_response(str(e))

    client_type, client = client_info
    advisory_json = json.dumps(advisory, ensure_ascii=False, indent=2)

    prompt = f"""Translate the following agricultural disease advisory JSON to {language}.

RULES:
1. Translate ALL text values to {language}
2. Keep the JSON structure and keys EXACTLY the same (keys stay in English)
3. Maintain agricultural terminology accuracy
4. For Hindi use Devanagari script
5. For Marathi use Devanagari script with Marathi vocabulary
6. Do not add or remove any fields
7. Respond with ONLY the translated JSON, no markdown fences

Original advisory:
{advisory_json}"""

    try:
        if client_type == "gemini":
            response = client.models.generate_content(
                model="gemini-2.5-flash",
                contents=prompt,
            )
            text = response.text.strip()
        else:
            model_name = os.environ.get("AI_MODEL", "google/gemini-2.5-flash")
            response = client.chat.completions.create(
                model=model_name,
                messages=[{"role": "user", "content": prompt}],
                max_tokens=1500,
            )
            text = response.choices[0].message.content.strip()

        if text.startswith("```"):
            text = text.split("\n", 1)[1]
            if "```" in text:
                text = text[:text.rfind("```")]
            text = text.strip()

        translated = json.loads(text)
        print(f"[Farmly] Advisory translated to {language} via {client_type}")
        return translated

    except json.JSONDecodeError as e:
        print(f"[Farmly] WARN: Translation JSON parse error: {e}")
        # Return original if translation fails
        return advisory
    except Exception as e:
        print(f"[Farmly] WARN: Translation error: {e}")
        return _error_response(f"Translation failed: {e}")


def _get_language_instruction(language: str) -> str:
    """Get language-specific writing instructions."""
    instructions = {
        "Hindi": (
            "LANGUAGE: Write EVERYTHING in simple Hindi (हिंदी). "
            "Use Devanagari script. Use everyday language a farmer can understand. "
            "Avoid complex English jargon."
        ),
        "Marathi": (
            "LANGUAGE: Write EVERYTHING in natural Marathi (मराठी). "
            "Use Devanagari script with Marathi vocabulary. "
            "Write as if advising a local farmer in Maharashtra."
        ),
        "English": (
            "LANGUAGE: Write in simple, clear English. "
            "Avoid technical jargon. Use farmer-friendly language."
        ),
    }
    return instructions.get(language, instructions["English"])


def _fallback_advisory(crop: str, disease: str, language: str) -> dict:
    """Return basic fallback advisory when Gemini is unavailable."""
    return {
        "summary": f"{disease} detected on {crop}. Please consult a local agricultural expert for detailed guidance.",
        "symptoms": ["Refer to local agricultural extension office for symptom identification"],
        "possible_causes": ["Environmental stress", "Pathogen infection", "Nutrient imbalance"],
        "prevention": [
            "Use disease-resistant varieties",
            "Maintain proper spacing between plants",
            "Ensure good drainage",
        ],
        "recommended_actions": [
            "Consult your nearest Krishi Vigyan Kendra (KVK)",
            "Remove and destroy visibly infected plant parts",
            "Avoid overhead irrigation if fungal disease is suspected",
        ],
        "safety_note": (
            "This is automated advice. Always follow local agricultural extension office "
            "guidance and product label instructions before applying any treatment."
        ),
        "_fallback": True,
    }


def _error_response(message: str) -> dict:
    """Return error response dict."""
    return {
        "summary": "",
        "symptoms": [],
        "possible_causes": [],
        "prevention": [],
        "recommended_actions": [],
        "safety_note": "",
        "_error": message,
    }
