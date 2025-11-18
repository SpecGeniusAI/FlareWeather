import os
import random
import re
from datetime import datetime, timedelta
from typing import List, Tuple, Dict, Optional
from openai import OpenAI
from dotenv import load_dotenv
from paper_search import format_papers_for_prompt
import json

# Load environment variables from .env file
load_dotenv()

# Initialize OpenAI client only if API key is available
api_key = os.getenv("OPENAI_API_KEY")
client = OpenAI(api_key=api_key) if api_key else None


def _describe_temperature(value: float) -> str:
    if value <= 2:
        return "chilly air"
    if value <= 10:
        return "cool air"
    if value <= 18:
        return "mild air"
    if value <= 26:
        return "warm air"
    return "heat leaning heavy"


def _describe_humidity(value: float) -> str:
    if value >= 80:
        return "heavy humidity"
    if value >= 65:
        return "humid air"
    if value <= 35:
        return "dry air"
    return ""


def _describe_wind(value: float) -> str:
    if value >= 30:
        return "gusty winds"
    if value >= 18:
        return "steady breeze"
    return ""


def _describe_pressure_trend(trend: Optional[str]) -> str:
    if not trend:
        return ""
    if "dropping" in trend:
        return "pressure is easing"
    if "rising" in trend:
        return "pressure is building"
    return f"pressure feels {trend}"


def _combine_descriptors(*descriptors: str) -> str:
    parts = [d for d in descriptors if d]
    if not parts:
        return "steady weather"
    if len(parts) == 1:
        return parts[0]
    return ", ".join(parts[:-1]) + f", {parts[-1]}"


def _next_weekday_labels(start: datetime, count: int = 7) -> List[str]:
    labels: List[str] = []
    for i in range(1, count + 1):
        day = start + timedelta(days=i)
        labels.append(day.strftime("%a"))
    return labels


def _format_daily_message(
    summary: Optional[str],
    why_line: Optional[str],
    comfort_tip: Optional[str],
    sign_off: Optional[str]
) -> str:
    summary_text = summary.strip() if summary else "Weather feels gentle and steady today."
    why_text = why_line.strip() if why_line else "Soft shifts may keep bodies feeling steadier."
    comfort_text = comfort_tip.strip() if comfort_tip else ""
    sign_off_text = sign_off.strip() if sign_off else "Move at a pace that feels kind to you."
    
    lines: List[str] = ["☀️ Daily Insight", "", summary_text, "", f"Why: {why_text}"]
    
    if comfort_text:
        lines.extend(["", f"Comfort tip: {comfort_text}"])
    
    lines.extend(["", sign_off_text])
    return "\n".join(lines).strip()


ALLOWED_COMFORT_TIPS = [
    "Keep your day flexible.",
    "Move at a pace that feels kind to you.",
    "Small pauses can help you stay grounded."
]


FORECAST_VARIANTS = {
    "LOW": [
        "No major shifts expected—take a deep breath and enjoy the calm.",
        "Conditions appear stable—today might offer you a little space.",
        "Weather looks gentle—move at your pace and consider light routines.",
        "The skies are steady for now—energy permitting, this may be a good window.",
        "Today's forecast holds quiet trends—you might find a soft rhythm to settle into."
    ],
    "MODERATE": [
        "Weather nudges are on the way—ease into the day and keep buffers open.",
        "You may feel the atmosphere shifting—pacing plans can keep things manageable.",
        "Conditions are wobbling—gently layering rest and light movement could help.",
        "Forecast changes are brewing—consider lighter commitments where you can.",
        "Weather signals are mixed—moving thoughtfully may soften any symptom echoes."
    ],
    "HIGH": [
        "Significant weather swings are lining up—consider scaling back and creating calm pockets.",
        "Rapid shifts are likely—prioritize rest, hydration, and essentials only.",
        "The atmosphere is in flux—many people cushion the day with extra pacing.",
        "Sharp changes are ahead—front-load care and keep the schedule flexible.",
        "Big swings usually call for gentle planning—give yourself room to adapt."
    ]
}

SUPPORT_NOTE_VARIANTS = {
    "fibromyalgia": [
        "Soft clothes, warm drinks, and gentle pacing can make a difference today.",
        "Give your muscles room to loosen slowly—comfort matters.",
        "Stretch gently and avoid rushing—your body deserves grace.",
        "Balance rest and warmth to stay ahead of any tightness.",
        "Even light movement might help—listen closely to how you feel."
    ],
    "migraine": [
        "Dim light and hydration can help buffer sensory load.",
        "Find quiet where you can, and avoid pressure triggers if possible.",
        "Prep a cozy, low-sensory zone in case you need to retreat.",
        "Take breaks in calm spaces—bright screens or noise may add to load.",
        "Stay hydrated and consider limiting abrupt exposure to the elements."
    ],
    "chronic fatigue syndrome": [
        "Layer in gentle rest before the weather shifts demand it.",
        "Micro-rests and steady nourishment can help conserve energy.",
        "Plan for brief pauses—slow pacing can head off payback.",
        "Keep essentials within reach to spare extra effort.",
        "Prioritize restorative moments; small breaks can soften the strain."
    ],
    "pots": [
        "Compression, salted hydration, and unrushed transitions may support circulation.",
        "Keep fluids close and rise slowly—steady pacing helps the autonomic system.",
        "Consider electrolyte support and seated breaks to stay level.",
        "Gentle movement paired with rest can keep blood flow steadier.",
        "Cool cloths and mindful breathing can temper sudden head rushes."
    ],
    "arthritis": [
        "Warmth, gentle mobility, and trusted comfort tools can settle joints.",
        "Keep layers or heat packs handy if stiffness creeps in.",
        "Easing into movement may help joints stay happier as weather shifts.",
        "Slow stretches and supportive footwear can soften jolts.",
        "Give yourself permission to rest the joints that grumble first."
    ]
}

COMBO_SUPPORT_VARIANTS = {
    frozenset({"fibromyalgia", "migraine"}): [
        "When pressure {direction} like this, muscle tightness and sensory load can combine—soft layers, dim spaces, and hydration may smooth things out.",
        "Both fibro flare-ups and migraine sensitivity can stir here—balance gentle stretches with low-stimulus rest breaks.",
        "Expect both muscles and senses to react—pair warmth and slow movement with quiet, shaded pockets.",
        "Hydration, soft attire, and calm lighting can support both tender muscles and sensitive nerves.",
        "Layer warmth for fibro while guarding against sensory overload—slow pacing keeps both systems happier."
    ],
    frozenset({"chronic fatigue syndrome", "pots"}): [
        "Pressure {direction} can tap both energy reserves and autonomic balance—salted hydration, compression, and pre-planned rest can help.",
        "When weather swings arrive, both fatigue and circulation may wobble—schedule micro-rests and unrushed transitions.",
        "Keep electrolytes, compression, and gentle pacing in play to support both stamina and blood flow.",
        "Layer seated breaks with fluids and supportive stockings to steady both symptoms.",
        "A mix of calm pacing, hydration, and compressive support can cushion both fatigue and POTS responses."
    ]
}

GENERIC_SUPPORT_VARIANTS = [
    "Pacing, hydration, and kind self-talk can make any weather wobble easier.",
    "Line up comfort items and low-effort meals so you can respond softly.",
    "Gentle movement, rest breaks, and warm layers can cushion the day.",
    "Keep plans flexible and energy-friendly—you're allowed to adjust as needed.",
    "Small comforts—tea, calm music, or grounding breaths—can go a long way."
]

STRONG_CONDITIONAL = "Many in your situation may want to preemptively scale back or buffer the day."

PERSONAL_ANECDOTES = {
    "fibromyalgia": [
        "Some users with fibromyalgia say evenings hit harder after fast pressure drops.",
        "When the pressure drops like this, many people with fibro notice extra muscle tightness.",
        "Fibro flare-ups often follow days like this—gentle pacing could help."
    ],
    "migraine": [
        "People with migraines often report sharper sensory spikes when pressure shifts quickly.",
        "Past users with migraines said storm fronts were the most triggering.",
        "This kind of drop has historically flared migraines—hydration and quiet can go a long way."
    ],
    "arthritis": [
        "Some users with arthritis mention stiffness on cooler, low-pressure mornings.",
        "When humidity rises after a pressure drop, joint soreness is a common report.",
        "Fast-moving fronts often bring joint aches—warmth and rest might ease it."
    ]
}

BEHAVIOR_PROMPTS = [
    "Remember to stay hydrated and rest when needed.",
    "Take breaks and pace yourself throughout the day.",
    "Listen to your body and adjust your plans as needed."
]


def _parse_iso_timestamp(value: Optional[str]) -> Optional[datetime]:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def _analyze_pressure_window(hourly_forecast: Optional[List[Dict[str, float]]], current_weather: Dict[str, float]) -> Tuple[str, float, str]:
    if not hourly_forecast:
        return "low", 0.0, "stable"

    points: List[Tuple[datetime, float]] = []
    for entry in hourly_forecast:
        dt = _parse_iso_timestamp(entry.get("timestamp"))
        pressure = entry.get("pressure")
        if dt is None or pressure is None:
            continue
        points.append((dt, float(pressure)))

    if not points:
        return "low", 0.0, "stable"

    points.sort(key=lambda p: p[0])
    start_time = points[0][0]
    base_pressure = current_weather.get("pressure", points[0][1])
    signed_delta = 0.0

    for dt, pressure in points:
        if dt - start_time > timedelta(hours=6):
            break
        delta = pressure - base_pressure
        if abs(delta) > abs(signed_delta):
            signed_delta = delta

    magnitude = abs(signed_delta)
    if magnitude >= 10:
        severity = "sharp"
    elif magnitude >= 5:
        severity = "moderate"
    else:
        severity = "low"

    if signed_delta < -0.1:
        direction = "drops"
    elif signed_delta > 0.1:
        direction = "rises"
    else:
        direction = "levels"

    return severity, signed_delta, direction


def _choose_forecast(risk: str, severity: str) -> str:
    variants = FORECAST_VARIANTS.get(risk.upper(), FORECAST_VARIANTS["LOW"])
    forecast = random.choice(variants)
    if severity == "sharp":
        forecast = f"{forecast} {STRONG_CONDITIONAL}"
    return forecast


def _choose_support_note(
    diagnoses: Optional[List[str]],
    severity: str,
    signed_delta: float,
    direction: str,
    risk: str
) -> Optional[str]:
    diagnoses = diagnoses or []
    normalized = [d.lower() for d in diagnoses]
    diag_set = frozenset(normalized)

    magnitude = abs(signed_delta)
    if severity == "low" and magnitude <= 2 and random.random() < 0.4:
        return None

    combo_template = COMBO_SUPPORT_VARIANTS.get(diag_set)
    if combo_template:
        base_note = random.choice(combo_template).format(direction=direction)
    else:
        collected: List[str] = []
        for diag in normalized:
            key = diag
            if key in SUPPORT_NOTE_VARIANTS:
                collected.append(random.choice(SUPPORT_NOTE_VARIANTS[key]))
        if not collected:
            collected = [random.choice(GENERIC_SUPPORT_VARIANTS)]
        elif len(collected) > 1:
            collected = collected[:2]
        base_note = " ".join(collected)

    if severity == "sharp" and STRONG_CONDITIONAL not in base_note:
        base_note = f"{base_note} {STRONG_CONDITIONAL}".strip()

    return base_note


def _personalization_score(
    diagnoses: Optional[List[str]],
    support_note: Optional[str],
    severity: str
) -> int:
    diagnoses = diagnoses or []
    normalized = [d.lower() for d in diagnoses]
    recognized = sum(1 for d in normalized if d in SUPPORT_NOTE_VARIANTS)
    if frozenset(normalized) in COMBO_SUPPORT_VARIANTS:
        recognized = max(recognized, 2)

    score = 1
    if normalized:
        score += min(2, max(1, len(normalized)))
    if support_note:
        score += 1
    if severity != "low":
        score += 1
    if recognized > 1:
        score += 1
    return min(5, score)


def _filter_app_messages(text: Optional[str]) -> Optional[str]:
    """
    Remove any app-specific messages about logging, updating, or using Flare.
    """
    if not text:
        return text
    
    # Phrases to filter out (in order of specificity - most specific first)
    filter_phrases = [
        "take one minute later to jot how you feel in Flare",
        "take one minute to jot how you feel",
        "jot how you feel in Flare",
        "teach the app what matters most",
        "what matters most to you",
        "those notes teach",
        "teach the app",
        "drop a quick update in Flare",
        "quick update in Flare",
        "update in Flare",
        "drop a quick update",
        "so the guidance stays personal to you",
        "so the guidance stays personal",
        "if anything new pops up",
        "if you notice anything new",
        "if anything new comes up",
        "log how you feel in Flare",
        "log your symptoms",
        "logging symptoms",
        "log how you feel",
        "update Flare",
        "jot how you feel",
        "jot down",
        "take notes",
        "make a note",
        "guidance stays personal",
        "one minute later",
        "one minute to"
    ]
    
    # First, normalize the text (replace em-dashes, line breaks, multiple spaces with single space)
    # This makes it easier to match phrases that might have different formatting
    # Note: Need to escape dashes or put them at the end of character class to avoid range interpretation
    normalized_text = re.sub(r'[\n\r]+', ' ', text)  # Replace line breaks with space first
    normalized_text = re.sub(r'[—–-]+', ' ', normalized_text)  # Replace em-dashes and hyphens with space
    normalized_text = re.sub(r'\s+', ' ', normalized_text)  # Replace multiple spaces with single space
    normalized_text_lower = normalized_text.lower()
    
    # Check if the normalized text contains any filter phrases
    # Also check for strong indicator combinations that suggest app usage instructions
    text_contains_filter = False
    matched_phrases = []
    
    # Check for exact filter phrases
    for phrase in filter_phrases:
        phrase_normalized = re.sub(r'\s+', ' ', phrase.lower())
        if phrase_normalized in normalized_text_lower:
            text_contains_filter = True
            matched_phrases.append(phrase)
    
    # Also check for strong indicator combinations (very aggressive check)
    # If text contains all these keywords together, it's almost certainly an app usage instruction
    strong_indicators = ["jot", "flare", "teach", "app", "matters most"]
    if all(indicator in normalized_text_lower for indicator in strong_indicators):
        text_contains_filter = True
        matched_phrases.append("strong_indicator_combination")
    
    # Check for "one minute" + "jot" + "Flare" combination
    if "one minute" in normalized_text_lower and "jot" in normalized_text_lower and "flare" in normalized_text_lower:
        text_contains_filter = True
        matched_phrases.append("one_minute_jot_flare")
    
    # Check for "those notes teach" + "app" combination
    if "those notes teach" in normalized_text_lower and "app" in normalized_text_lower:
        text_contains_filter = True
        matched_phrases.append("notes_teach_app")
    
    # If we found filter phrases, remove sentences containing them
    filtered_text = text
    if text_contains_filter:
        # Split original text by periods, em-dashes, line breaks
        sentences = re.split(r'[\.\n\r—–-]+\s*', text)
        filtered_sentences = []
        
        for sentence in sentences:
            sentence_clean = sentence.strip()
            if not sentence_clean:
                continue
            
            # Normalize sentence for comparison
            sentence_normalized = re.sub(r'[\n\r]+', ' ', sentence_clean)
            sentence_normalized = re.sub(r'[—–-]+', ' ', sentence_normalized)
            sentence_normalized = re.sub(r'\s+', ' ', sentence_normalized).lower()
            
            # Check if sentence contains any filter phrases
            should_filter = False
            for phrase in matched_phrases:
                phrase_normalized = re.sub(r'\s+', ' ', phrase.lower())
                if phrase_normalized in sentence_normalized:
                    should_filter = True
                    break
            
            # Also check for keyword combinations
            if not should_filter:
                has_jot_or_teach = any(kw in sentence_normalized for kw in ["jot", "teach", "notes teach", "teach the"])
                has_app_reference = any(kw in sentence_normalized for kw in ["flare", "app", "the app"])
                has_matters_most = "matters most" in sentence_normalized
                has_one_minute = "one minute" in sentence_normalized
                
                if (has_jot_or_teach and has_app_reference) or (has_matters_most and has_app_reference) or (has_one_minute and has_app_reference and (has_jot_or_teach or "log" in sentence_normalized)):
                    should_filter = True
            
            if not should_filter:
                filtered_sentences.append(sentence_clean)
        
        # Rejoin sentences
        if filtered_sentences:
            filtered_text = '. '.join(filtered_sentences)
        else:
            filtered_text = ""
    else:
        # Even if we didn't find exact filter phrases, do a second pass to catch keyword combinations
        # This catches cases where the AI might phrase things differently
        sentences = re.split(r'[\.\n\r—–-]+\s*', text)
        filtered_sentences = []
        
        for sentence in sentences:
            sentence_clean = sentence.strip()
            if not sentence_clean:
                continue
            
            # Normalize sentence for comparison
            sentence_normalized = re.sub(r'[\n\r]+', ' ', sentence_clean)
            sentence_normalized = re.sub(r'[—–-]+', ' ', sentence_normalized)
            sentence_normalized = re.sub(r'\s+', ' ', sentence_normalized).lower()
            
            # Check for keyword combinations that indicate app usage instructions
            has_jot_or_teach = any(kw in sentence_normalized for kw in ["jot", "teach", "notes teach", "teach the", "those notes"])
            has_app_reference = any(kw in sentence_normalized for kw in ["flare", "app", "the app"])
            has_matters_most = "matters most" in sentence_normalized
            has_one_minute = "one minute" in sentence_normalized or "one minute later" in sentence_normalized
            has_log = "log" in sentence_normalized or "logging" in sentence_normalized
            
            # Filter if sentence contains app usage instructions
            # More aggressive: if sentence mentions "jot" or "teach" AND any app reference, filter it
            # Also filter if it mentions "one minute" with app/logging references
            # Also filter if it mentions "matters most" with app reference
            should_filter = (has_jot_or_teach and has_app_reference) or \
                           (has_matters_most and has_app_reference) or \
                           (has_one_minute and has_app_reference) or \
                           (has_one_minute and (has_jot_or_teach or has_log)) or \
                           (has_log and has_app_reference) or \
                           ("one minute" in sentence_normalized and "flare" in sentence_normalized and ("jot" in sentence_normalized or "log" in sentence_normalized))
            
            if not should_filter:
                filtered_sentences.append(sentence_clean)
        
        if filtered_sentences:
            filtered_text = '. '.join(filtered_sentences)
        else:
            filtered_text = ""
    
    # Final cleanup: remove any remaining filter phrases that might have been missed
    for phrase in filter_phrases:
        # Normalize phrase and create pattern
        phrase_normalized = re.sub(r'\s+', ' ', phrase.lower())
        # Create flexible pattern that matches phrase even with different spacing
        pattern = re.compile(re.escape(phrase_normalized).replace(r'\ ', r'[\s—–-]+'), re.IGNORECASE)
        filtered_text = pattern.sub('', filtered_text)
    
    # Clean up any double spaces, double periods, or trailing/leading issues
    filtered_text = re.sub(r'\.\s*\.', '.', filtered_text)  # Remove double periods
    filtered_text = re.sub(r'\s+', ' ', filtered_text)  # Remove multiple spaces
    filtered_text = filtered_text.strip()
    
    # Remove trailing periods if they're alone
    filtered_text = filtered_text.rstrip('. ')
    
    return filtered_text if filtered_text else None


def _choose_sign_off(diagnoses: Optional[List[str]], location: Optional[str]) -> str:
    """Return a compassionate sign-off tailored to the user context."""
    base_sign_offs = [
        "Keep breathing steady and give yourself the gentlest option available.",
        "You deserve ease—take the day at the rhythm that feels kindest.",
        "Listen to your body and let supportive rest be part of the plan.",
        "Small comforts count—let them be your anchor today.",
        "You're allowed to go softly; the forecast can still be navigated with care."
    ]

    diagnosis_sign_offs = {
        "fibromyalgia": [
            "Sending warm, slow stretches your way—take the day in soft-focus.",
            "May your muscles find ease; pacing gently is more than enough.",
            "Let warmth and kindness wrap your joints—move only when it feels welcome."
        ],
        "migraine": [
            "Wishing you quiet light and hydrated pauses whenever you need them.",
            "Keep the calm close by—dim spaces and steady sips can be your allies.",
            "May today offer softened edges and gentle spaces to retreat when needed."
        ],
        "arthritis": [
            "Keep joints cozy and supported—your comfort leads the plan today.",
            "May warmth and slow motion guide you toward steadier steps.",
            "Wrap sore spots in kindness—your pace sets the tone for the day."
        ],
        "pots": [
            "Hold onto steady breaths, salted sips, and your reliable pacing.",
            "Root for calm circulation—legs up, heart steady, you're doing enough.",
            "May gentle transitions and hydration keep your day feeling grounded."
        ],
        "chronic fatigue syndrome": [
            "Energy is precious—spend it like treasure and celebrate the stillness.",
            "May each pause refill you; soft wins count just as much.",
            "Keep kindness for yourself front and center; recovery moments are productive too."
        ]
    }

    normalized = [d.lower() for d in (diagnoses or [])]
    candidate_sign_offs: List[str] = []

    for diag in normalized:
        if diag in diagnosis_sign_offs:
            candidate_sign_offs.extend(diagnosis_sign_offs[diag])

    if location:
        location_templates = [
            f"Sending steady skies over {location}—choose the calm pockets whenever they appear.",
            f"{location} can wait while you recharge—move only as the good moments allow.",
            f"Wishing you weather-kind pauses in {location}; let the gentlest plan lead the way."
        ]
        candidate_sign_offs.extend(location_templates)

    if not candidate_sign_offs:
        candidate_sign_offs = base_sign_offs

    return random.choice(candidate_sign_offs)


def generate_insight(correlations, rag_context: List[Tuple[str, str]] = None):
    """
    Generate AI insight with optional RAG context.
    
    Args:
        correlations: Dictionary of weather variable correlations
        rag_context: List of (chunk_text, source_filename) tuples from RAG
        
    Returns:
        Tuple of (ai_message, citations_list)
    """
    if not client:
        return ("AI insights are not available. Please configure your OpenAI API key in the .env file.", [])
    
    # Build base prompt
    base_prompt = f"""
You are FlareWeather, a health and weather assistant.
Based on these correlations: {correlations},
write a short, empathetic insight (~150 words) explaining
how the user's symptoms relate to weather patterns.
Keep it encouraging and clear for a wellness app tone.
"""
    
    # If RAG context is available, enhance the prompt
    if rag_context and len(rag_context) > 0:
        # Extract relevant context
        context_text = "\n\n".join([
            f"[Source: {source}]\n{chunk}"
            for chunk, source in rag_context
        ])
        
        # Build RAG-enhanced prompt
        prompt = f"""
You are FlareWeather, a health and weather assistant.

Based on these correlations: {correlations},

Use the following research context to inform your response:
{context_text}

Write a short, empathetic insight (~150 words) explaining
how the user's symptoms relate to weather patterns.
Reference the research when relevant and cite sources using [Source: filename].
Keep it encouraging and clear for a wellness app tone.
"""
        
        # Extract citations from sources
        citations = [source for _, source in rag_context]
    else:
        prompt = base_prompt
        citations = []
    
    try:
        completion = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": "You are FlareWeather, a health and weather forecasting assistant. Your goal is to help users predict how they'll feel during the week based on weather patterns. Focus on forecasting, expected symptoms, and actionable advice for managing weather-related health changes."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7
        )
        ai_message = completion.choices[0].message.content.strip()
        
        # Deduplicate citations
        citations = list(set(citations))
        
        return (ai_message, citations)
    except Exception as e:
        print(f"Error generating insight: {e}")
        # Fallback to basic insight without RAG
        try:
            fallback_prompt = f"""
You are FlareWeather, a health and weather forecasting assistant.
Based on these correlations: {correlations},
write a forecasting-focused insight (~180 words) that helps users predict how they'll feel.
Focus on expected symptoms and weather patterns to watch for.
Keep it encouraging and clear for a wellness app tone.
"""
            completion = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "You are FlareWeather, a health and weather forecasting assistant. Help users predict how they'll feel based on weather patterns."},
                    {"role": "user", "content": fallback_prompt}
                ]
            )
            ai_message = completion.choices[0].message.content.strip()
            return (ai_message, [])
        except Exception as e2:
            print(f"Fallback also failed: {e2}")
            return ("Unable to generate insights at this time.", [])


def generate_flare_risk_assessment(
    current_weather: Dict[str, float],
    pressure_trend: Optional[str] = None,
    weather_factor: str = "pressure",
    papers: List[Dict[str, str]] = None,
    user_diagnoses: Optional[List[str]] = None,
    location: Optional[str] = None,
    hourly_forecast: Optional[List[Dict[str, float]]] = None
) -> Tuple[str, str, str, str, List[str], Optional[str], str, int, Optional[str], Optional[str]]:
    """Generate a daily flare insight that obeys strict formatting rules."""
    if not client:
        fallback_message = _format_daily_message(
            "Weather feels steady today.",
            "Soft shifts keep things gentler on sensitive bodies.",
            ALLOWED_COMFORT_TIPS[1],
            "Move kindly through the day."
        )
        return (
            "MODERATE",
            "Weather looks gentle today.",
            "Soft shifts keep things gentler on sensitive bodies.",
            fallback_message,
            [],
            None,
            "moderate",
            2,
            None,
            None
        )

    papers = papers or []
    pressure = current_weather.get("pressure", 1013)
    humidity = current_weather.get("humidity", 50)
    temperature = current_weather.get("temperature", 20)
    wind = current_weather.get("wind", 0)

    severity_label, signed_delta, direction = _analyze_pressure_window(hourly_forecast, current_weather)
    alert_severity = severity_label

    weather_descriptor = _combine_descriptors(
        _describe_pressure_trend(pressure_trend),
        _describe_temperature(temperature),
        _describe_humidity(humidity),
        _describe_wind(wind)
    )

    if direction == "drops":
        hourly_note = "Upcoming hours lean more changeable."
    elif direction == "rises":
        hourly_note = "Upcoming hours may feel more settled."
    else:
        hourly_note = "Upcoming hours stay fairly steady."

    diagnoses_str = ", ".join(user_diagnoses) if user_diagnoses else "general weather sensitivity"
    location_str = f"around {location}" if location else "in your area"
    comfort_clause = ", ".join([f'"{tip}"' for tip in ALLOWED_COMFORT_TIPS])
    papers_text = format_papers_for_prompt(papers) if papers else "Reference trusted health organizations only if needed."

    prompt = f"""You are the FlareWeather Forecasting Assistant.

CONTEXT:
- Location: {location_str}
- Weather mood: {weather_descriptor}.
- Hourly cue: {hourly_note}
- Diagnoses in mind: {diagnoses_str}
- Comfort tips you may use exactly: {comfort_clause}
- Optional research notes: {papers_text}

MANDATORY STYLE:
- Plain, everyday language only.
- Never use numbers, units, or percentages.
- Never reference technical meteorology (no hPa, dewpoint, fronts, etc.).
- Never give medical advice or instructions.
- Never promise outcomes; use gentle "may" framing.
- Allowed feeling words: reactive, easier, gentle, steady, calmer.
- Keep sentences short and calm.
- Even if context shows numbers, do NOT include them in your output.

OUTPUT VALID JSON EXACTLY:
{{
  "risk": "LOW | MODERATE | HIGH",
  "forecast": "Short headline with no numbers.",
  "why": "Brief sentence on why bodies may notice today.",
  "sources": ["Optional short source names"],
  "support_note": "Optional gentle note.",
  "personal_anecdote": "Optional relatable line.",
  "behavior_prompt": "Optional gentle reminder.",
  "daily_insight": {{
    "summary_sentence": "REQUIRED FORMAT: '[Weather description] which could [impact statement].' You MUST include both parts: 1) describe the weather pattern (cool air, heavy humidity, dropping pressure, rising temperatures, etc.) 2) ALWAYS end with 'which could [impact]' - describe potential body impacts like discomfort, joint stiffness, inflammation, headaches, muscle tension, breathing challenges, etc. Never just describe weather alone. Example: 'Today brings cool air with a heavy blanket of humidity which could cause some discomfort.'",
    "why_line": "Explain why this specific weather event causes flares or symptoms. Focus on the scientific mechanism: how pressure changes affect joint fluid, how humidity impacts inflammation, how temperature shifts affect blood flow, etc. Be educational but accessible. Example: 'Dropping pressure can cause tissues to expand slightly, increasing pressure on sensitive joints and nerves.'",
    "comfort_tip": "Either one of the allowed comfort tips or empty string.",
    "sign_off": "One calm sign-off sentence."
  }}
}}

DO NOT:
- Use numbers, degrees, or percentages.
- Mention pain, attacks, flare-ups, or danger.
- Add extra sections beyond the JSON.
- Break the required tone."""

    risk = "MODERATE"
    forecast_from_model: Optional[str] = None
    why_from_model: Optional[str] = None
    sources: List[str] = []
    daily_summary: Optional[str] = None
    daily_why_line: Optional[str] = None
    daily_comfort_tip: str = ""
    daily_sign_off: Optional[str] = None

    try:
        completion = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": "You translate weather moods into calm, compassionate guidance for weather-sensitive people."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.6,
            response_format={"type": "json_object"}
        )
        response_text = completion.choices[0].message.content.strip()
        response_json = json.loads(response_text)

        risk = response_json.get("risk", "MODERATE").upper()
        forecast_from_model = response_json.get("forecast")
        why_from_model = response_json.get("why")
        sources = response_json.get("sources", []) or []

        daily_json = response_json.get("daily_insight", {}) or {}
        daily_summary = daily_json.get("summary_sentence")
        daily_why_line = daily_json.get("why_line")
        daily_comfort_tip = daily_json.get("comfort_tip") or ""
        daily_sign_off = daily_json.get("sign_off")

        if daily_comfort_tip:
            normalized_tip = daily_comfort_tip.strip().lower()
            allowed_normalized = [tip.lower() for tip in ALLOWED_COMFORT_TIPS]
            if normalized_tip not in allowed_normalized:
                daily_comfort_tip = ""
    except Exception as exc:  # noqa: BLE001
        print(f"❌ Error generating daily insight JSON: {exc}")
        import traceback
        traceback.print_exc()
        if pressure_trend and "drop" in (pressure_trend or "").lower():
            risk = "HIGH"
            why_from_model = "Quick shifts may leave sensitive bodies feeling more reactive."
        elif pressure < 1005:
            risk = "MODERATE"
            why_from_model = "Soft swings may feel a little less steady."
        else:
            risk = "LOW"
            why_from_model = "Steadier cues often feel gentler on sensitive bodies."
        forecast_from_model = None
        daily_summary = None
        daily_why_line = None
        daily_comfort_tip = ""
        daily_sign_off = None
        sources = []

    if not daily_summary:
        if risk == "HIGH":
            daily_summary = "Fast swings keep the day feeling more reactive."
        elif risk == "LOW":
            daily_summary = "Weather settles into a gentler groove."
        else:
            daily_summary = "Weather wobbles softly through the day."

    if not daily_why_line:
        if severity_label == "sharp":
            daily_why_line = "Rapid cues may leave sensitive bodies feeling more reactive."
        elif severity_label == "moderate":
            daily_why_line = "Mixed cues may feel a touch less steady."
        else:
            daily_why_line = "Steady cues often feel easier on the body."

    if not daily_comfort_tip and risk != "LOW":
        daily_comfort_tip = ALLOWED_COMFORT_TIPS[0]
    elif not daily_comfort_tip:
        daily_comfort_tip = ""

    daily_sign_off = daily_sign_off or _choose_sign_off(user_diagnoses, location)

    filtered_summary = _filter_app_messages(daily_summary) or daily_summary
    filtered_why_line = _filter_app_messages(daily_why_line) or daily_why_line
    filtered_comfort = _filter_app_messages(daily_comfort_tip) or daily_comfort_tip
    filtered_sign_off = _filter_app_messages(daily_sign_off) or daily_sign_off

    formatted_daily_message = _format_daily_message(
        filtered_summary,
        filtered_why_line,
        filtered_comfort,
        filtered_sign_off
    )

    if forecast_from_model:
        forecast = _filter_app_messages(forecast_from_model)
    else:
        forecast = _filter_app_messages(_choose_forecast(risk, severity_label))

    why_text = _filter_app_messages(daily_why_line) or _filter_app_messages(why_from_model) or ""

    support_note = _filter_app_messages(
        _choose_support_note(user_diagnoses, severity_label, signed_delta, direction, risk)
    )

    personal_anecdote = None
    normalized_diags = [d.lower() for d in (user_diagnoses or [])]
    if risk == "HIGH" and signed_delta <= -5:
        for diag in normalized_diags:
            if diag in PERSONAL_ANECDOTES:
                personal_anecdote = _filter_app_messages(random.choice(PERSONAL_ANECDOTES[diag]))
                break

    behavior_prompt = None
    if risk in {"MODERATE", "HIGH"} and random.random() < 0.5:
        behavior_prompt = _filter_app_messages(random.choice(BEHAVIOR_PROMPTS))

    personalization_score = _personalization_score(user_diagnoses, support_note, severity_label)

    if sources:
        sources = [s for s in sources if s]
    elif papers:
        sources = [
            paper.get("source") or paper.get("title")
            for paper in papers
            if paper.get("source") or paper.get("title")
        ]

    return (
        risk,
        forecast or "",
        why_text or "",
        formatted_daily_message,
        sources or [],
        support_note,
        alert_severity,
        personalization_score,
        personal_anecdote,
        behavior_prompt
    )


# Backward compatibility function
def generate_insight_with_papers(
    correlations: Dict[str, float],
    symptom: str,
    weather_factor: str,
    papers: List[Dict[str, str]],
    user_diagnoses: Optional[List[str]] = None,
    all_symptoms: List[str] = None,
    current_weather: Optional[Dict[str, float]] = None,
    pressure_trend: Optional[str] = None,
    location: Optional[str] = None
) -> Tuple[str, List[str]]:
    """
    Generate AI insight with research papers (backward compatibility wrapper).
    
    Returns:
        Tuple of (ai_message, citations_list)
    """
    if current_weather is None:
        # Build current_weather from correlations (fallback)
        current_weather = {
            "pressure": 1013,
            "humidity": 50,
            "temperature": 20,
            "wind": 0,
            "condition": "Unknown"
        }
    
    _, _, _, full_message, citations, _, _, _, _, _, _ = generate_flare_risk_assessment(
        current_weather=current_weather,
        pressure_trend=pressure_trend,
        weather_factor=weather_factor,
        papers=papers,
        user_diagnoses=user_diagnoses,
        location=location
    )
    
    return (full_message, citations)


def generate_weekly_forecast_insight(
    weekly_forecast: List[Dict[str, float]],
    user_diagnoses: Optional[List[str]] = None,
    location: Optional[str] = None
) -> Tuple[str, List[str]]:
    """Generate a weekly outlook that follows the locked structure."""
    if not client:
        payload = json.dumps({
            "weekly_summary": "Weekly outlook is offline. Please check back soon.",
            "daily_breakdown": []
        })
        return (payload, [])

    if not weekly_forecast:
        payload = json.dumps({
            "weekly_summary": "Weekly forecast data is not available at this time.",
            "daily_breakdown": []
        })
        return (payload, [])

    forecast_entries = weekly_forecast[:7]
    if not forecast_entries:
        payload = json.dumps({
            "weekly_summary": "Weekly forecast data is not available at this time.",
            "daily_breakdown": []
        })
        return (payload, [])

    # Always start weekday labels from tomorrow (user's perspective)
    # The forecast entries might start from any day, but we want to show tomorrow-first
    # Parse first entry to detect timezone, but always calculate from "tomorrow"
    first_entry = forecast_entries[0]
    now_utc = datetime.utcnow()
    
    # Try to detect user's timezone from first forecast entry
    user_offset_hours = 0
    first_entry_date_utc = None
    
    if "timestamp" in first_entry:
        try:
            timestamp_str = first_entry["timestamp"]
            if isinstance(timestamp_str, str):
                if timestamp_str.endswith("Z"):
                    timestamp_str = timestamp_str.replace("Z", "+00:00")
                first_entry_date = datetime.fromisoformat(timestamp_str)
                first_entry_date_utc = first_entry_date.astimezone(datetime.now().astimezone().tzinfo).replace(tzinfo=None) if first_entry_date.tzinfo else first_entry_date
                
                # Calculate timezone offset if present
                if first_entry_date.tzinfo:
                    user_offset = first_entry_date.utcoffset()
                    if user_offset:
                        user_offset_hours = user_offset.total_seconds() / 3600
        except (ValueError, AttributeError, KeyError):
            pass
    
    # Calculate "today" in user's timezone, then "tomorrow"
    # Add 1 day to ensure we always start from tomorrow, not today
    now_user_tz = now_utc + timedelta(hours=user_offset_hours)
    today_user_tz = now_user_tz.replace(hour=0, minute=0, second=0, microsecond=0)
    tomorrow_user_tz = today_user_tz + timedelta(days=1)
    
    # Generate weekday labels starting from tomorrow (always +1 day from today)
    weekday_labels = []
    for i in range(7):
        day = tomorrow_user_tz + timedelta(days=i)
        weekday_labels.append(day.strftime("%a"))
    
    # Use forecast entries directly - they should already start from tomorrow
    ordered_entries = forecast_entries[:len(weekday_labels)]

    while len(ordered_entries) < len(weekday_labels):
        ordered_entries.append(ordered_entries[-1])

    context_lines = ["Weekly Weather Notes:"]
    prev_pressure: Optional[float] = None

    for label, day_data in zip(weekday_labels, ordered_entries):
        temp = day_data.get("temperature", 0)
        humidity = day_data.get("humidity", 0)
        wind = day_data.get("wind", 0)
        pressure = day_data.get("pressure", prev_pressure if prev_pressure is not None else 1013)

        descriptors = [_describe_temperature(temp)]
        humidity_desc = _describe_humidity(humidity)
        if humidity_desc:
            descriptors.append(humidity_desc)
        wind_desc = _describe_wind(wind)
        if wind_desc:
            descriptors.append(wind_desc)

        if prev_pressure is None:
            descriptors.append("pressure steadies")
        else:
            delta = pressure - prev_pressure
            if delta <= -4:
                descriptors.append("pressure eases")
            elif delta >= 4:
                descriptors.append("pressure builds")
            else:
                descriptors.append("pressure steadies")

        descriptor_text = _combine_descriptors(*descriptors)
        context_lines.append(f"- {label}: {descriptor_text}")
        prev_pressure = pressure

    diagnoses_str = ", ".join(user_diagnoses) if user_diagnoses else "weather-sensitive conditions"
    location_note = f" near {location}" if location else ""
    weekday_clause = ", ".join(weekday_labels)

    prompt_context = "\n".join(context_lines)
    prompt = f"""You are FlareWeather, a calm weekly planning assistant for weather-sensitive people.

User context: {diagnoses_str}{location_note}.

{prompt_context}

Use the weekday order exactly as provided: {weekday_clause}.
For each day in that order, craft:
- weather_pattern: 3-6 everyday words describing the weather feel (no numbers).
- body_feel: 5-9 gentle words on how a sensitive body may feel (use "may"/"might").

Return JSON EXACTLY:
{{
  "weekly_summary": "REQUIRED FORMAT: '[Overall weekly weather pattern description] which could [impact statement].' You MUST include both parts: 1) describe the overall weekly weather pattern (shifting pressures, humidity trends, temperature changes, wind patterns, etc.) 2) ALWAYS end with 'which could [impact]' - describe potential body impacts like discomfort, joint stiffness, inflammation, headaches, muscle tension, breathing challenges, etc. Never just describe weather alone. One to two sentences, no numbers, no greetings. Example: 'The week ahead brings dropping pressure midweek with rising humidity which could increase joint discomfort and inflammation.'",
  "daily_patterns": [
    {{"weather_pattern": "...", "body_feel": "..."}},
    ... (7 total entries)
  ],
  "sources": ["Optional short source names"]
}}

RULES:
- No numbers, measurements, or percentages.
- No technical meteorology.
- No instructions or medical advice.
- Mention low-impact windows by noting when things "may feel easier".
- Tone stays steady, kind, and factual.
- Do not start with greetings or end with sign-offs.
- Even if context shows numbers, do NOT include them in your output."""

    try:
        completion = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": "You produce calm weekly outlooks in plain language and valid JSON."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.5,
            response_format={"type": "json_object"}
        )
        response_text = completion.choices[0].message.content.strip().strip("` ")
        response_data = json.loads(response_text)
    except Exception as exc:  # noqa: BLE001
        print(f"❌ Error generating weekly forecast insight: {exc}")
        import traceback
        traceback.print_exc()
        fallback = json.dumps({
            "weekly_summary": "Weekly outlook is unavailable right now.",
            "daily_breakdown": []
        })
        return (fallback, [])

    weekly_summary = response_data.get("weekly_summary", "").strip()
    weekly_summary = _filter_app_messages(weekly_summary) or weekly_summary

    patterns = response_data.get("daily_patterns", [])
    if not isinstance(patterns, list):
        patterns = []

    sources = response_data.get("sources", []) or []

    while len(patterns) < len(weekday_labels):
        patterns.append({"weather_pattern": "steady pattern", "body_feel": "may feel easier on the body"})
    if len(patterns) > len(weekday_labels):
        patterns = patterns[:len(weekday_labels)]

    daily_breakdown: List[Dict[str, str]] = []
    previous_weather_pattern = None
    previous_insight_line = None
    
    for label, entry in zip(weekday_labels, patterns):
        weather_pattern = entry.get("weather_pattern", "steady pattern")
        body_feel = entry.get("body_feel", "may feel steady on the body")
        weather_pattern = _filter_app_messages(weather_pattern) or weather_pattern
        body_feel = _filter_app_messages(body_feel) or body_feel
        
        # Normalize weather pattern for comparison (trim whitespace, lowercase)
        weather_pattern_normalized = weather_pattern.strip().lower()
        
        # Check if weather pattern is the same as previous day
        # If weather conditions are identical, show fallback even if body_feel wording differs
        is_same_weather = (
            previous_weather_pattern and
            weather_pattern_normalized == previous_weather_pattern
        )
        
        if is_same_weather:
            insight_line = "Expect similar comfort levels to the previous day"
            # Don't update previous values - keep comparing against original pattern
        else:
            insight_line = f"{weather_pattern} — {body_feel}"
            previous_weather_pattern = weather_pattern_normalized
            previous_insight_line = insight_line
        
        daily_breakdown.append({
            "label": label,
            "insight": insight_line
        })

    payload = json.dumps({
        "weekly_summary": weekly_summary,
        "daily_breakdown": daily_breakdown
    })

    return (payload, sources)
