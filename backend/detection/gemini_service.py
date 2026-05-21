"""
AI Advice service with DB-first caching via OpenRouter API.

Flow: Disease detected → Check DB cache → If cached, return → Else call OpenRouter (Gemini) → Cache & return.
Location-aware, weather-aware advice for Maharashtra farmers.
Enhanced with structured prompts, strict language quality, and new advisory fields.
"""

import json
import time
from datetime import datetime
from openai import OpenAI
from sqlalchemy.orm import Session

_client = None


def _get_client(api_key: str):
    global _client
    if _client is None:
        _client = OpenAI(base_url="https://openrouter.ai/api/v1", api_key=api_key)
    return _client


def _get_season() -> str:
    month = datetime.now().month
    if month in (6, 7, 8, 9, 10):
        return "Kharif (monsoon season - June to October)"
    elif month in (11, 12, 1, 2, 3):
        return "Rabi (winter season - November to March)"
    else:
        return "Zaid/Summer (April to May)"


def _get_region_soil_info(location: str) -> str:
    location_lower = location.lower()
    region_map = {
        "mumbai": ("Konkan", "laterite soil", "high rainfall (2500-4000mm), coastal humid"),
        "thane": ("Konkan", "laterite soil", "high rainfall, coastal humid"),
        "raigad": ("Konkan", "laterite soil", "high rainfall, coastal humid"),
        "ratnagiri": ("Konkan", "laterite soil", "very high rainfall, coastal"),
        "sindhudurg": ("Konkan", "laterite soil", "very high rainfall, coastal"),
        "palghar": ("Konkan", "laterite soil", "high rainfall, coastal"),
        "pune": ("Western Maharashtra", "red laterite and black soil mix", "moderate rainfall (600-800mm), semi-arid"),
        "satara": ("Western Maharashtra", "deep black soil", "moderate rainfall, semi-arid"),
        "sangli": ("Western Maharashtra", "deep black soil", "moderate rainfall, semi-arid"),
        "kolhapur": ("Western Maharashtra", "alluvial and black soil", "high rainfall (1000-2000mm)"),
        "solapur": ("Western Maharashtra", "medium black soil", "low rainfall (500-600mm), semi-arid"),
        "aurangabad": ("Marathwada", "medium to deep black cotton soil", "low rainfall (600-700mm), drought-prone"),
        "chhatrapati sambhajinagar": ("Marathwada", "medium to deep black cotton soil", "low rainfall, drought-prone"),
        "latur": ("Marathwada", "deep black cotton soil", "low rainfall, drought-prone"),
        "osmanabad": ("Marathwada", "deep black cotton soil", "low rainfall, semi-arid"),
        "dharashiv": ("Marathwada", "deep black cotton soil", "low rainfall, semi-arid"),
        "beed": ("Marathwada", "medium black soil", "low rainfall, drought-prone"),
        "jalna": ("Marathwada", "medium black soil", "low rainfall"),
        "nanded": ("Marathwada", "black cotton soil", "moderate rainfall"),
        "parbhani": ("Marathwada", "black cotton soil", "moderate rainfall"),
        "hingoli": ("Marathwada", "black cotton soil", "moderate rainfall"),
        "nagpur": ("Vidarbha", "black cotton soil (regur)", "moderate rainfall (800-1000mm), extreme temperatures"),
        "amravati": ("Vidarbha", "medium black soil", "moderate rainfall, hot summers"),
        "akola": ("Vidarbha", "medium black soil", "moderate rainfall"),
        "yavatmal": ("Vidarbha", "black cotton soil", "moderate rainfall"),
        "wardha": ("Vidarbha", "black cotton soil", "moderate rainfall"),
        "chandrapur": ("Vidarbha", "alluvial and black soil", "moderate-high rainfall"),
        "gadchiroli": ("Vidarbha", "red and laterite soil", "high rainfall, forest region"),
        "nashik": ("North Maharashtra", "light to medium black soil", "moderate rainfall (600-800mm)"),
        "jalgaon": ("North Maharashtra", "deep black soil", "moderate rainfall"),
        "dhule": ("North Maharashtra", "medium black soil", "low-moderate rainfall"),
        "nandurbar": ("North Maharashtra", "medium black and alluvial soil", "moderate rainfall"),
        "ahmednagar": ("Western Maharashtra", "light to medium black soil", "low rainfall, semi-arid"),
    }
    for city, (region, soil, climate) in region_map.items():
        if city in location_lower:
            return f"Region: {region}\nSoil Type: {soil}\nClimate: {climate}"
    return "Region: Maharashtra (General)\nSoil Type: varied (black cotton, laterite, alluvial)\nClimate: tropical monsoon"


def get_cached_advice(db: Session, disease_name: str, language: str, location: str) -> dict | None:
    from models import DiseaseAdviceCache
    cache = (
        db.query(DiseaseAdviceCache)
        .filter(
            DiseaseAdviceCache.disease_name == disease_name,
            DiseaseAdviceCache.language == language,
            DiseaseAdviceCache.location == location,
        )
        .first()
    )
    if cache:
        try:
            return json.loads(cache.advice_json)
        except (json.JSONDecodeError, TypeError):
            return None
    return None


def save_advice_to_cache(db: Session, disease_name: str, language: str, location: str, advice: dict):
    from models import DiseaseAdviceCache
    existing = (
        db.query(DiseaseAdviceCache)
        .filter(
            DiseaseAdviceCache.disease_name == disease_name,
            DiseaseAdviceCache.language == language,
            DiseaseAdviceCache.location == location,
        )
        .first()
    )
    if existing:
        existing.advice_json = json.dumps(advice, ensure_ascii=False)
        db.commit()
    else:
        cache = DiseaseAdviceCache(
            disease_name=disease_name, language=language, location=location,
            advice_json=json.dumps(advice, ensure_ascii=False),
        )
        db.add(cache)
        db.commit()


def generate_advice(
    api_key: str, disease_name: str, confidence: float,
    location: str, language: str, db: Session,
    weather: dict = None,
) -> dict:
    """Get disease advice. DB cache first → OpenRouter (Gemini) fallback."""
    if disease_name in ("HealthyLeaf", "No Disease Detected"):
        return _healthy_response(language)

    # Check DB cache
    cached = get_cached_advice(db, disease_name, language, location)
    if cached:
        cached["from_cache"] = True
        print(f"✅ Cache hit for {disease_name}/{language}/{location}")
        return cached

    # Build weather context string
    weather = weather or {}
    weather_str = (
        f"Temperature: {weather.get('temperature', 28)}°C, "
        f"Humidity: {weather.get('humidity', 65)}%, "
        f"Wind: {weather.get('wind_speed', 10)} km/h, "
        f"Rain chance today: {weather.get('rain_chance_today', 20)}%"
    )

    client = _get_client(api_key)
    lang_name = {"mr": "Marathi", "hi": "Hindi", "en": "English"}.get(language, "English")
    location_str = location if location else "Maharashtra, India"
    season = _get_season()
    region_info = _get_region_soil_info(location_str)

    # Language-specific writing instructions
    lang_instructions = {
        "mr": """LANGUAGE: Write EVERYTHING in natural Marathi (मराठी) as spoken by farmers in Maharashtra.
- Use simple conversational Marathi, NOT formal/literary Marathi
- Do NOT transliterate English words into Devanagari — use proper Marathi terms
- For chemical names, you may use the brand name as-is (e.g., Bavistin)
- Use Marathi numbers where natural (e.g., ३-४ दिवस)
- Write as if you are a trusted local कृषी सल्लागार (agriculture advisor) talking to a farmer""",
        "hi": """LANGUAGE: Write EVERYTHING in simple Hindi (हिंदी) understandable by a farmer with basic education.
- Use everyday spoken Hindi, not complex or formal language
- For chemical names, use the brand name as-is
- Write as if you are a trusted local कृषि सलाहकार talking to a farmer""",
        "en": """LANGUAGE: Write in simple, clear English suitable for someone with basic English.
- Avoid technical jargon — explain in farmer-friendly terms
- Use short sentences and bullet points"""
    }

    prompt = f"""You are "Plantix" — a trusted agricultural expert for rice farmers in Maharashtra, India.

━━━ CONTEXT ━━━
Crop: Rice (Bhaat/धान)
Disease: {disease_name.replace('_', ' ')}
Detection Confidence: {int(confidence * 100)}%
Location: {location_str}, Maharashtra
Season: {season}
{region_info}
Weather: {weather_str}

━━━ {lang_instructions.get(language, lang_instructions['en'])} ━━━

━━━ REQUIRED JSON OUTPUT ━━━
{{
  "full_description": "4-5 sentence scientific but understandable description of this disease, its pathogen, how it spreads, and impact on yield. Include relevance to {location_str}'s conditions.",
  "explanation": "2-3 simple sentences a farmer can understand. How this disease affects rice in current weather/season.",
  "causes": ["cause 1", "cause 2", "cause 3"],
  "treatments": [
    {{"title": "Chemical treatment name", "description": "Exact product name + dosage per litre and per acre", "icon": "🧪"}},
    {{"title": "Organic/bio remedy", "description": "Step-by-step with local materials", "icon": "🌿"}},
    {{"title": "Cultural practice", "description": "Farm management recommendation", "icon": "🌾"}}
  ],
  "prevention": ["tip 1", "tip 2", "tip 3", "tip 4"],
  "severity": "Low/Medium/High/Critical",
  "medicine_availability": "Where to buy in Maharashtra",
  "next_7_day_care": "Day-by-day care plan for the next week considering current weather",
  "spray_timing": "Best time and conditions for spraying based on current weather",
  "disease_spread_risk": "Risk assessment based on current humidity/rain/temperature",
  "watering_advice": "Irrigation guidance considering disease and weather",
  "fertilizer_caution": "What fertilizers to avoid or adjust during treatment"
}}

━━━ MEDICINE RULES ━━━
- ONLY recommend pesticides available in Maharashtra agri-shops
- Use Indian brands: Dhanuka, UPL, Bayer India, Syngenta India, BASF India, Tata Rallis, PI Industries
- Include exact dosage: ml/gm per litre AND per acre
- Include specific product + active ingredient (e.g., "Bavistin 50% WP (Carbendazim) - 1 gm/litre")
- For organic: use neem oil (कडुनिंबाचे तेल), cow urine (गोमूत्र), Trichoderma, Pseudomonas, buttermilk (ताक)
- At least 3 treatments: chemical, organic/bio, cultural

━━━ WEATHER-AWARE ADVICE ━━━
- If humidity >{'>'}70%: warn about fungal spread risk
- If rain expected (>{'>'}50% chance): advise against spraying, suggest waiting
- If temperature >{'>'}35°C: advise early morning/evening spraying only
- Include weather impact in spray_timing and disease_spread_risk

Respond ONLY with valid JSON. No markdown, no explanation outside JSON."""

    max_retries = 3
    for attempt in range(max_retries):
        try:
            print(f"🤖 Calling Gemini for {disease_name}/{language} (attempt {attempt + 1})")
            response = client.chat.completions.create(
                model="google/gemini-2.0-flash-001",
                messages=[
                    {"role": "system", "content": f"You are Plantix, a Maharashtra agricultural expert. Respond ONLY with valid JSON in {lang_name}."},
                    {"role": "user", "content": prompt},
                ],
                temperature=0.7,
                max_tokens=4000,
            )
            text = response.choices[0].message.content.strip()

            if text.startswith("```"):
                text = text.split("\n", 1)[1]
                if "```" in text:
                    text = text[:text.rfind("```")]
                text = text.strip()

            advice = json.loads(text)

            # Validate required keys
            required_keys = ["explanation", "causes", "treatments", "prevention", "severity", "full_description"]
            for key in required_keys:
                if key not in advice:
                    advice[key] = [] if key in ("causes", "treatments", "prevention") else ""

            # Ensure new fields exist
            for key in ("next_7_day_care", "spray_timing", "disease_spread_risk", "watering_advice", "fertilizer_caution"):
                if key not in advice:
                    advice[key] = ""

            save_advice_to_cache(db, disease_name, language, location, advice)
            advice["from_cache"] = False
            print(f"✅ Advice generated and cached for {disease_name}")
            return advice

        except json.JSONDecodeError as e:
            print(f"⚠️ Invalid JSON (attempt {attempt + 1}): {e}")
            if attempt < max_retries - 1:
                time.sleep(1)
                continue
            return _fallback_advice(disease_name, language, location_str)
        except Exception as e:
            print(f"⚠️ API error (attempt {attempt + 1}): {e}")
            if attempt < max_retries - 1:
                time.sleep(2)
                continue
            return _fallback_advice(disease_name, language, location_str)

    return _fallback_advice(disease_name, language, location_str)


def _healthy_response(language: str) -> dict:
    base = {
        "severity": "None", "medicine_availability": "", "from_cache": False,
        "next_7_day_care": "", "spray_timing": "", "disease_spread_risk": "",
        "watering_advice": "", "fertilizer_caution": "",
    }
    if language == "mr":
        return {**base,
            "full_description": "तुमच्या भाताच्या पानावर कोणताही रोग आढळला नाही. पान निरोगी आणि हिरवे आहे.",
            "explanation": "तुमचे भाताचे पान निरोगी आहे! कोणताही रोग आढळला नाही.",
            "causes": [], "treatments": [],
            "prevention": ["नियमित तपासणी करत रहा", "योग्य पाणी व्यवस्थापन ठेवा", "संतुलित खत वापरा"],
        }
    elif language == "hi":
        return {**base,
            "full_description": "आपकी धान की पत्ती पर कोई रोग नहीं पाया गया। पत्ती स्वस्थ और हरी है।",
            "explanation": "आपकी धान की पत्ती स्वस्थ है! कोई रोग नहीं पाया गया.",
            "causes": [], "treatments": [],
            "prevention": ["नियमित जांच करते रहें", "उचित सिंचाई प्रबंधन रखें", "संतुलित उर्वरक का उपयोग करें"],
        }
    else:
        return {**base,
            "full_description": "No disease was detected on your rice leaf. The leaf appears healthy and green.",
            "explanation": "Your rice leaf is healthy! No disease was detected.",
            "causes": [], "treatments": [],
            "prevention": ["Continue regular monitoring", "Maintain proper water management", "Use balanced fertilizers"],
        }


def _fallback_advice(disease_name: str, language: str, location: str = "Maharashtra") -> dict:
    name = disease_name.replace("_", " ")
    base_new = {
        "next_7_day_care": "", "spray_timing": "", "disease_spread_risk": "Medium",
        "watering_advice": "", "fertilizer_caution": "", "from_cache": False,
    }
    if language == "mr":
        return {**base_new,
            "full_description": f"{name} हा भाताच्या पिकावरील एक सामान्य रोग आहे. {location} मधील हवामान या रोगाच्या प्रसारास कारणीभूत ठरू शकते. जवळच्या कृषी विज्ञान केंद्राला भेट द्या.",
            "explanation": f"तुमच्या भाताच्या पिकावर {name} रोग आढळला आहे. कृपया जवळच्या कृषी विज्ञान केंद्राला भेट द्या.",
            "causes": ["पर्यावरणीय ताण", "बुरशीजन्य/जिवाणू संसर्ग", "अयोग्य पीक व्यवस्थापन"],
            "treatments": [
                {"title": "बाविस्टिन (कार्बेन्डाझिम) फवारणी", "description": "बाविस्टिन 50% WP प्रति लिटर पाण्यात 1 ग्रॅम मिसळून फवारणी करा.", "icon": "🧪"},
                {"title": "कडुनिंबाचे तेल फवारणी", "description": "5 मिली कडुनिंबाचे तेल प्रति लिटर पाण्यात मिसळून 7 दिवसांच्या अंतराने फवारणी करा.", "icon": "🌿"},
                {"title": "प्रभावित पाने काढा", "description": "संक्रमित पाने काढून शेताबाहेर नष्ट करा.", "icon": "🌾"},
            ],
            "prevention": ["रोग प्रतिकारक जाती वापरा", "योग्य अंतर ठेवा", "जास्त नायट्रोजन टाळा", "पाण्याचा निचरा करा"],
            "severity": "Medium",
            "medicine_availability": f"{location} मधील कृषी दुकाने",
        }
    elif language == "hi":
        return {**base_new,
            "full_description": f"{name} धान की फसल पर पाया जाने वाला एक सामान्य रोग है। {location} की जलवायु इसके प्रसार में योगदान कर सकती है।",
            "explanation": f"आपकी धान की फसल पर {name} रोग पाया गया है। निकटतम कृषि विज्ञान केंद्र से संपर्क करें।",
            "causes": ["पर्यावरणीय तनाव", "फफूंद/जीवाणु संक्रमण", "खराब फसल प्रबंधन"],
            "treatments": [
                {"title": "बाविस्टिन (कार्बेन्डाज़िम) छिड़काव", "description": "बाविस्टिन 50% WP 1 ग्राम/लीटर पानी में मिलाकर छिड़काव करें।", "icon": "🧪"},
                {"title": "नीम तेल छिड़काव", "description": "5 मिली नीम तेल प्रति लीटर पानी में मिलाकर 7 दिनों के अंतराल पर छिड़काव करें।", "icon": "🌿"},
                {"title": "प्रभावित भाग हटाएं", "description": "संक्रमित पत्तियां हटाकर खेत से बाहर नष्ट करें।", "icon": "🌾"},
            ],
            "prevention": ["रोग प्रतिरोधी किस्में लगाएं", "उचित दूरी रखें", "अत्यधिक नाइट्रोजन से बचें", "उचित जल निकासी करें"],
            "severity": "Medium",
            "medicine_availability": f"{location} के कृषि दुकान",
        }
    else:
        return {**base_new,
            "full_description": f"{name} is a common disease in rice crops. Climate in {location} can contribute to its spread.",
            "explanation": f"{name} detected on your rice crop. Visit nearest Krishi Vigyan Kendra for guidance.",
            "causes": ["Environmental stress", "Fungal/bacterial infection", "Poor crop management"],
            "treatments": [
                {"title": "Bavistin (Carbendazim) Spray", "description": "Mix Bavistin 50% WP at 1gm/litre of water and spray.", "icon": "🧪"},
                {"title": "Neem Oil Spray", "description": "Mix 5ml neem oil per litre of water, spray at 7-day intervals.", "icon": "🌿"},
                {"title": "Remove Affected Parts", "description": "Remove and destroy infected leaves outside the field.", "icon": "🌾"},
            ],
            "prevention": ["Use disease-resistant varieties", "Maintain proper spacing", "Avoid excess nitrogen", "Ensure proper drainage"],
            "severity": "Medium",
            "medicine_availability": f"Available at agri-shops in {location}",
        }
