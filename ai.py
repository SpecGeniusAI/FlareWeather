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

FORECAST_VARIANTS = {
    "LOW": [
        "No major shifts expected—take a deep breath and enjoy the calm.",
        "Conditions appear stable—today might offer you a little space.",
        "Weather looks gentle—move at your pace and consider light routines.",
        "The skies are steady for now—energy permitting, this may be a good window.",
        "Today’s forecast holds quiet trends—you might find a soft rhythm to settle into."
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
    "Keep plans flexible and energy-friendly—you’re allowed to adjust as needed.",
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
    normalized_text = re.sub(r'[—–-\n\r]+', ' ', text)  # Replace em-dashes and line breaks with space
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
            sentence_normalized = re.sub(r'[—–-\n\r]+', ' ', sentence_clean)
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
            sentence_normalized = re.sub(r'[—–-\n\r]+', ' ', sentence_clean)
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
        "You’re allowed to go softly; the forecast can still be navigated with care."
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
            "Root for calm circulation—legs up, heart steady, you’re doing enough.",
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
    """
    Generate flare risk assessment with research papers from EuropePMC.
    
    Args:
        current_weather: Dictionary with pressure, humidity, temperature, wind, condition
        pressure_trend: Optional string describing pressure trend (e.g., "dropping quickly", "stable")
        weather_factor: Strongest weather factor affecting the user
        papers: List of paper dictionaries from paper_search
        user_diagnoses: List of user's health conditions
        location: Optional location string
        hourly_forecast: Optional list of hourly forecast data
        
    Returns:
        Tuple of (risk, forecast, why, full_message, citations_list, support_note, alert_severity, personalization_score, personal_anecdote, behavior_prompt)
        risk: "LOW", "MODERATE", or "HIGH"
        forecast: 1-sentence forecast message
        why: Plain-language explanation
        full_message: Full AI message for backward compatibility
        citations: List of source references
        support_note: Optional emotional encouragement
        alert_severity: "low", "moderate", or "sharp"
        personalization_score: 1-5
        personal_anecdote: Optional anecdote
        behavior_prompt: Optional prompt for user action
    """
    if not client:
        error_msg = "AI insights are not available. Please configure your OpenAI API key in the .env file."
        return ("MODERATE", error_msg, "Unable to generate assessment.", error_msg, [], None, "moderate", 2, None, None)
    
    papers = papers or []
    
    # Build weather context
    pressure = current_weather.get("pressure", 1013)
    humidity = current_weather.get("humidity", 50)
    temperature = current_weather.get("temperature", 20)
    wind = current_weather.get("wind", 0)
    condition = current_weather.get("condition", "Unknown")
    
    # Don't assume specific triggers - only use what the user has explicitly provided
    # We'll mention common triggers for their conditions in the prompt, but won't claim the user has those sensitivities
    # This prevents the AI from referencing triggers the user hasn't confirmed
    triggers_str = "Common weather factors"  # Generic - let the AI discuss weather factors without assuming specific sensitivities
    
    # Build prompt based on whether we have papers
    if papers and len(papers) > 0:
        papers_text = format_papers_for_prompt(papers)
        
        diagnoses_str = ", ".join(user_diagnoses) if user_diagnoses else "weather-sensitive conditions"
        location_str = f" in {location}" if location else ""
        
        # Build personalized context
        personalization = ""
        if user_diagnoses and len(user_diagnoses) > 0:
            if len(user_diagnoses) == 1:
                personalization = f"You are writing for someone with {diagnoses_str}. Address them directly and personally, as if you understand their specific experience with this condition."
            else:
                personalization = f"You are writing for someone with multiple conditions: {diagnoses_str}. Address them directly and personally, acknowledging how weather affects their combination of conditions."
        else:
            personalization = "Address the user directly and personally, as someone who experiences weather sensitivity."
        
        # Build hourly forecast section if available
        hourly_forecast_text = ""
        if hourly_forecast and len(hourly_forecast) > 0:
            hourly_forecast_text = "\n\nHourly Forecast (next 24 hours):\n"
            for i, hour_data in enumerate(hourly_forecast[:24]):  # Limit to 24 hours
                hour_time = hour_data.get("timestamp", "")
                hour_pressure = hour_data.get("pressure", 0)
                hour_humidity = hour_data.get("humidity", 0)
                hour_temp = hour_data.get("temperature", 0)
                hour_wind = hour_data.get("wind", 0)
                
                # Try to format time nicely
                try:
                    if isinstance(hour_time, str):
                        dt = datetime.fromisoformat(hour_time.replace('Z', '+00:00'))
                        time_str = dt.strftime("%I:%M %p")
                    else:
                        time_str = f"Hour {i+1}"
                except:
                    time_str = f"Hour {i+1}"
                
                hourly_forecast_text += f"- {time_str}: {hour_temp:.0f}°C, {hour_pressure:.0f} hPa, {hour_humidity:.0f}% humidity, {hour_wind:.0f} km/h wind\n"
        
        prompt = f"""You are FlareWeather, an emotionally intelligent and scientifically grounded assistant built for people with weather-sensitive chronic conditions like fibromyalgia, arthritis, migraines, and fatigue.

{personalization}

Current Weather Data{location_str}:
- Pressure: {pressure:.0f} hPa {f"({pressure_trend})" if pressure_trend else ""}
- Humidity: {humidity:.0f}%
- Temperature: {temperature:.0f}°C
- Wind: {wind:.0f} km/h
- Condition: {condition}
{hourly_forecast_text}
User's Health Conditions: {diagnoses_str if user_diagnoses else "Weather-sensitive chronic condition"}

Research Papers:
{papers_text}

Your task is to provide a personalized, empathetic insight that helps this user understand how today's weather may affect them:

1. **Analyze the weather data deeply**: Look at current conditions AND the hourly forecast. Identify specific patterns:
   - Pressure changes: Is it dropping/rising? By how much? When?
   - Temperature swings: Are there significant changes coming?
   - Humidity shifts: Will it spike or drop?
   - Wind changes: Any notable shifts?

2. **Assign Flare Risk**: LOW, MODERATE, or HIGH based on the severity of weather changes and how they typically affect {diagnoses_str if user_diagnoses else "weather-sensitive conditions"}.

3. **Generate a specific, actionable forecast** (1 sentence): 
   - BAD EXAMPLES (DO NOT USE - THESE WILL BE REJECTED):
     * "Weather patterns may affect your symptoms. Monitor how you feel today."
     * "Weather may affect you today."
     * "Be careful today."
     * "Monitor how you feel."
   - GOOD EXAMPLES (USE THESE AS TEMPLATES):
     * "Pressure is dropping 8 hPa between 2-5 PM, which often triggers migraines—consider planning lighter activities this afternoon."
     * "Barometric pressure will fall from 1013 to 1005 hPa by 4 PM, potentially increasing joint stiffness—warmth and gentle movement may help."
     * "Humidity spikes to 85% around 1 PM, which can worsen fatigue—plan for rest breaks during that window."
   - REQUIREMENTS: Must include SPECIFIC TIMES (e.g., "2-5 PM", "by 4 PM") AND SPECIFIC WEATHER CHANGES (e.g., "dropping 8 hPa", "spikes to 85%"). Without both, your forecast will be REJECTED.

4. **Write a detailed, personalized "why" explanation** (3-4 sentences):
   - Start with what's happening RIGHT NOW with the weather
   - Explain HOW this specific weather pattern typically affects {diagnoses_str if user_diagnoses else "their condition"} (reference research if available)
   - Mention SPECIFIC TIMES from the hourly forecast when changes will occur
   - Be specific about which symptoms people with {diagnoses_str if user_diagnoses else "their condition"} might experience (e.g., "joint stiffness", "fatigue spikes", "migraine triggers")
   - Use conditional language: "may", "could", "might", "often", "some people find"
   
   Example of a GOOD "why":
   "Barometric pressure is currently at {pressure:.0f} hPa and will drop to {pressure-5:.0f} hPa by 3 PM—a 5 hPa decrease over 4 hours. Research shows that rapid pressure drops like this can trigger inflammation responses in people with arthritis, often leading to increased joint stiffness and discomfort. The pressure change is most significant between 1-4 PM, so you might notice symptoms building during that window. Some people with arthritis find that staying warm, moving gently, and avoiding sudden position changes helps during these shifts."

5. **Include 1–2 trusted sources**: Use research papers provided or trusted medical sources (Mayo Clinic, NIH, Arthritis Foundation, Cleveland Clinic).

6. **Support note** (only for MODERATE/HIGH): 1-2 sentences of compassionate, practical encouragement.

CRITICAL QUALITY STANDARDS - YOUR RESPONSE WILL BE REJECTED IF IT'S TOO GENERIC:

- **Be SPECIFIC**: Name exact times (e.g., "2-5 PM", "by 4 PM", "this afternoon"), exact pressure/temperature changes (e.g., "dropping 8 hPa", "rising 5°C"), exact symptoms (e.g., "joint stiffness", "migraine triggers")
- **Be ACTIONABLE**: Tell them what they can do (e.g., "plan lighter activities this afternoon", "stay hydrated during the pressure drop")
- **Be PERSONAL**: Write as if you understand their specific experience with {diagnoses_str if user_diagnoses else "their condition"}
- **Use "you" and "your"**: Make it feel like a personal conversation
- **NEVER be vague**: Generic statements like "weather may affect you" or "monitor how you feel" will be REJECTED. You MUST include specific times and weather changes.
- **NEVER assume current symptoms**: Don't say "you're feeling" or "your symptoms are"—only discuss potential effects
- **NEVER mention app usage**: No references to logging, updating, or using Flare

**VALIDATION**: Your forecast will be automatically rejected if it:
- Contains phrases like "weather patterns may affect" or "monitor how you feel" without specific times/changes
- Is shorter than 30 characters
- Lacks specific times (PM, AM, afternoon, evening) AND specific weather changes (hPa, °C, pressure drop/rise)

Output your response as valid JSON in this exact format:
{{
  "risk": "HIGH",  // LOW, MODERATE, or HIGH
  "forecast": "Flare risk is high — pressure is crashing this afternoon. If you can, build in extra rest.",
  "why": "Rapid drops in barometric pressure can worsen symptoms for people with arthritis and migraines.",
  "sources": [
    "NIH: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4516866/",
    "Mayo Clinic: https://www.mayoclinic.org/diseases-conditions/migraine-headache"
  ],
  "support_note": "Optional – include only for MODERATE or HIGH risk. Keep it compassionate and low-pressure."
}}

Make the tone calm, supportive, and practical. Never alarmist. Keep it short and empathetic. Write personally and directly to the user.

If you reference the research papers provided, use their source IDs or titles in the sources array."""
        
    else:
        # No papers - use generic sources
        diagnoses_str = ", ".join(user_diagnoses) if user_diagnoses else "weather-sensitive conditions"
        location_str = f" in {location}" if location else ""
        
        # Build personalized context
        personalization = ""
        if user_diagnoses and len(user_diagnoses) > 0:
            if len(user_diagnoses) == 1:
                personalization = f"You are writing for someone with {diagnoses_str}. Address them directly and personally, as if you understand their specific experience with this condition."
            else:
                personalization = f"You are writing for someone with multiple conditions: {diagnoses_str}. Address them directly and personally, acknowledging how weather affects their combination of conditions."
        else:
            personalization = "Address the user directly and personally, as someone who experiences weather sensitivity."
        
        # Build hourly forecast section if available
        hourly_forecast_text = ""
        if hourly_forecast and len(hourly_forecast) > 0:
            hourly_forecast_text = "\n\nHourly Forecast (next 24 hours):\n"
            for i, hour_data in enumerate(hourly_forecast[:24]):  # Limit to 24 hours
                hour_time = hour_data.get("timestamp", "")
                hour_pressure = hour_data.get("pressure", 0)
                hour_humidity = hour_data.get("humidity", 0)
                hour_temp = hour_data.get("temperature", 0)
                hour_wind = hour_data.get("wind", 0)
                
                # Try to format time nicely
                try:
                    if isinstance(hour_time, str):
                        dt = datetime.fromisoformat(hour_time.replace('Z', '+00:00'))
                        time_str = dt.strftime("%I:%M %p")
                    else:
                        time_str = f"Hour {i+1}"
                except:
                    time_str = f"Hour {i+1}"
                
                hourly_forecast_text += f"- {time_str}: {hour_temp:.0f}°C, {hour_pressure:.0f} hPa, {hour_humidity:.0f}% humidity, {hour_wind:.0f} km/h wind\n"
        
        prompt = f"""You are FlareWeather, an emotionally intelligent and scientifically grounded assistant built for people with weather-sensitive chronic conditions like fibromyalgia, arthritis, migraines, and fatigue.

{personalization}

Current Weather Data{location_str}:
- Pressure: {pressure:.0f} hPa {f"({pressure_trend})" if pressure_trend else ""}
- Humidity: {humidity:.0f}%
- Temperature: {temperature:.0f}°C
- Wind: {wind:.0f} km/h
- Condition: {condition}
{hourly_forecast_text}
User's Health Conditions: {diagnoses_str if user_diagnoses else "Weather-sensitive chronic condition"}

Your task is to provide a personalized, empathetic insight that helps this user understand how today's weather may affect them:

1. **Analyze the weather data deeply**: Look at current conditions AND the hourly forecast. Identify specific patterns:
   - Pressure changes: Is it dropping/rising? By how much? When?
   - Temperature swings: Are there significant changes coming?
   - Humidity shifts: Will it spike or drop?
   - Wind changes: Any notable shifts?

2. **Assign Flare Risk**: LOW, MODERATE, or HIGH based on the severity of weather changes and how they typically affect {diagnoses_str if user_diagnoses else "weather-sensitive conditions"}.

3. **Generate a specific, actionable forecast** (1 sentence): 
   - BAD EXAMPLES (DO NOT USE - THESE WILL BE REJECTED):
     * "Weather patterns may affect your symptoms. Monitor how you feel today."
     * "Weather may affect you today."
     * "Be careful today."
     * "Monitor how you feel."
   - GOOD EXAMPLES (USE THESE AS TEMPLATES):
     * "Pressure is dropping 8 hPa between 2-5 PM, which often triggers migraines—consider planning lighter activities this afternoon."
     * "Barometric pressure will fall from 1013 to 1005 hPa by 4 PM, potentially increasing joint stiffness—warmth and gentle movement may help."
     * "Humidity spikes to 85% around 1 PM, which can worsen fatigue—plan for rest breaks during that window."
   - REQUIREMENTS: Must include SPECIFIC TIMES (e.g., "2-5 PM", "by 4 PM") AND SPECIFIC WEATHER CHANGES (e.g., "dropping 8 hPa", "spikes to 85%"). Without both, your forecast will be REJECTED.

4. **Write a detailed, personalized "why" explanation** (3-4 sentences):
   - Start with what's happening RIGHT NOW with the weather
   - Explain HOW this specific weather pattern typically affects {diagnoses_str if user_diagnoses else "their condition"} (reference research if available)
   - Mention SPECIFIC TIMES from the hourly forecast when changes will occur
   - Be specific about which symptoms people with {diagnoses_str if user_diagnoses else "their condition"} might experience (e.g., "joint stiffness", "fatigue spikes", "migraine triggers")
   - Use conditional language: "may", "could", "might", "often", "some people find"
   
   Example of a GOOD "why":
   "Barometric pressure is currently at {pressure:.0f} hPa and will drop to {pressure-5:.0f} hPa by 3 PM—a 5 hPa decrease over 4 hours. Research shows that rapid pressure drops like this can trigger inflammation responses in people with arthritis, often leading to increased joint stiffness and discomfort. The pressure change is most significant between 1-4 PM, so you might notice symptoms building during that window. Some people with arthritis find that staying warm, moving gently, and avoiding sudden position changes helps during these shifts."

5. **Include 1–2 trusted sources**: Use research papers provided or trusted medical sources (Mayo Clinic, NIH, Arthritis Foundation, Cleveland Clinic).

6. **Support note** (only for MODERATE/HIGH): 1-2 sentences of compassionate, practical encouragement.

CRITICAL QUALITY STANDARDS - YOUR RESPONSE WILL BE REJECTED IF IT'S TOO GENERIC:

- **Be SPECIFIC**: Name exact times (e.g., "2-5 PM", "by 4 PM", "this afternoon"), exact pressure/temperature changes (e.g., "dropping 8 hPa", "rising 5°C"), exact symptoms (e.g., "joint stiffness", "migraine triggers")
- **Be ACTIONABLE**: Tell them what they can do (e.g., "plan lighter activities this afternoon", "stay hydrated during the pressure drop")
- **Be PERSONAL**: Write as if you understand their specific experience with {diagnoses_str if user_diagnoses else "their condition"}
- **Use "you" and "your"**: Make it feel like a personal conversation
- **NEVER be vague**: Generic statements like "weather may affect you" or "monitor how you feel" will be REJECTED. You MUST include specific times and weather changes.
- **NEVER assume current symptoms**: Don't say "you're feeling" or "your symptoms are"—only discuss potential effects
- **NEVER mention app usage**: No references to logging, updating, or using Flare

**VALIDATION**: Your forecast will be automatically rejected if it:
- Contains phrases like "weather patterns may affect" or "monitor how you feel" without specific times/changes
- Is shorter than 30 characters
- Lacks specific times (PM, AM, afternoon, evening) AND specific weather changes (hPa, °C, pressure drop/rise)

Output your response as valid JSON in this exact format:
{{
  "risk": "HIGH",  // LOW, MODERATE, or HIGH
  "forecast": "Flare risk is high — pressure is crashing this afternoon. If you can, build in extra rest.",
  "why": "Rapid drops in barometric pressure can worsen symptoms for people with arthritis and migraines.",
  "sources": [
    "NIH: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4516866/",
    "Mayo Clinic: https://www.mayoclinic.org/diseases-conditions/migraine-headache"
  ],
  "support_note": "Optional – include only for MODERATE or HIGH risk. Keep it compassionate and low-pressure."
}}

Make the tone calm, supportive, and practical. Never alarmist. Keep it short and empathetic. Write personally and directly to the user."""
    
    try:
        completion = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": "You are Flare, a gentle and trustworthy assistant who helps people living with chronic pain, fatigue, and invisible illnesses understand how upcoming weather changes may affect their symptoms. Use compassionate, validating language. Do not make medical claims. Instead, offer gentle guidance based on weather trends, known sensitivities, and research-backed correlations. Speak like someone who understands what it's like to plan your energy around flares — informative but never alarmist. Write naturally and personally, as if you're talking to a friend who shares your experience with weather sensitivity."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7,
            response_format={"type": "json_object"}
        )
        
        response_text = completion.choices[0].message.content.strip()
        
        # Parse JSON response
        try:
            response_json = json.loads(response_text)
            risk = response_json.get("risk", "MODERATE").upper()
            forecast_from_model = response_json.get("forecast")
            why = response_json.get("why", "Weather data analysis in progress.")
            sources = response_json.get("sources", [])
            
            # Debug logging
            print(f"📊 AI Response - Risk: {risk}, Forecast: {forecast_from_model[:100] if forecast_from_model else 'None'}...")
            
            # Filter why immediately after parsing to catch app-specific messages
            why_before_filter = why
            why = _filter_app_messages(why)
            if why != why_before_filter:
                print(f"🔍 Filtered 'why' field. Before: {why_before_filter[:150]}... After: {why[:150] if why else 'None'}...")
            
            # Check if AI returned support_note, behavior_prompt, or personal_anecdote
            # Even though we generate these ourselves, the AI might return them anyway
            # If it does, we need to filter them to ensure no app-specific messages
            ai_support_note = response_json.get("support_note")
            ai_behavior_prompt = response_json.get("behavior_prompt")
            ai_personal_anecdote = response_json.get("personal_anecdote")
            
            # Filter any AI-generated fields that might contain app-specific messages
            if ai_support_note:
                ai_support_note_before = ai_support_note
                ai_support_note = _filter_app_messages(ai_support_note)
                if ai_support_note != ai_support_note_before:
                    print(f"🔍 Filtered AI support_note. Before: {ai_support_note_before[:150]}... After: {ai_support_note[:150] if ai_support_note else 'None'}...")
                # Don't use AI's support_note - we generate our own
            if ai_behavior_prompt:
                ai_behavior_prompt_before = ai_behavior_prompt
                ai_behavior_prompt = _filter_app_messages(ai_behavior_prompt)
                if ai_behavior_prompt != ai_behavior_prompt_before:
                    print(f"🔍 Filtered AI behavior_prompt. Before: {ai_behavior_prompt_before[:150]}... After: {ai_behavior_prompt[:150] if ai_behavior_prompt else 'None'}...")
                # Don't use AI's behavior_prompt - we generate our own
            if ai_personal_anecdote:
                ai_personal_anecdote_before = ai_personal_anecdote
                ai_personal_anecdote = _filter_app_messages(ai_personal_anecdote)
                if ai_personal_anecdote != ai_personal_anecdote_before:
                    print(f"🔍 Filtered AI personal_anecdote. Before: {ai_personal_anecdote_before[:150]}... After: {ai_personal_anecdote[:150] if ai_personal_anecdote else 'None'}...")
                # Don't use AI's personal_anecdote - we generate our own
        except json.JSONDecodeError as e:
            print(f"⚠️  Failed to parse JSON response: {e}")
            print(f"📝 Raw response: {response_text[:500]}")
            response_upper = response_text.upper()
            if "HIGH" in response_upper and ("RISK" in response_upper or "FLARE" in response_upper):
                risk = "HIGH"
            elif "MODERATE" in response_upper and ("RISK" in response_upper or "FLARE" in response_upper):
                risk = "MODERATE"
            elif "LOW" in response_upper and ("RISK" in response_upper or "FLARE" in response_upper):
                risk = "LOW"
            else:
                risk = "MODERATE"
            forecast_from_model = None
            why = response_text
            sources = []
    except Exception as e:
        print(f"❌ Error generating flare risk assessment: {e}")
        import traceback
        traceback.print_exc()
        if pressure_trend and "drop" in (pressure_trend or "").lower():
            risk = "HIGH"
            why = "Barometric pressure drops may trigger symptoms for some people with weather-sensitive conditions."
        elif pressure < 1000:
            risk = "MODERATE"
            why = "Lower barometric pressure can potentially influence symptoms for some conditions."
        else:
            risk = "LOW"
            why = "Stable weather patterns are typically associated with fewer flare-ups for some people."
        sources = []
        forecast_from_model = None

    severity_label, signed_delta, direction = _analyze_pressure_window(hourly_forecast, current_weather)
    alert_severity = severity_label

    # Always prefer AI forecast - trust the AI to do a good job
    if forecast_from_model:
        forecast = forecast_from_model
        print(f"✅ Using AI-generated forecast: {forecast[:100]}...")
    else:
        # Fall back to our pool if AI didn't provide a forecast
        forecast = _choose_forecast(risk, severity_label)
        print(f"⚠️  No AI forecast, using pool: {forecast[:100]}...")

    support_note = _choose_support_note(user_diagnoses, severity_label, signed_delta, direction, risk)
    personal_anecdote = None
    normalized_diags = [d.lower() for d in (user_diagnoses or [])]
    if risk == "HIGH" and signed_delta <= -5:
        for diag in normalized_diags:
            if diag in PERSONAL_ANECDOTES:
                personal_anecdote = random.choice(PERSONAL_ANECDOTES[diag])
                break

    behavior_prompt = None
    if risk in {"MODERATE", "HIGH"} and random.random() < 0.7:
        behavior_prompt = random.choice(BEHAVIOR_PROMPTS)

    personalization_score = _personalization_score(user_diagnoses, support_note, severity_label)

    if sources:
        sources = [s for s in sources if s]

    # Filter out app-specific messages from AI response
    why = _filter_app_messages(why)
    support_note = _filter_app_messages(support_note)
    forecast = _filter_app_messages(forecast)
    
    sign_off = _choose_sign_off(user_diagnoses, location)
    if why:
        base_message = why.rstrip()
    else:
        base_message = forecast.rstrip() if forecast else ""
    if base_message:
        full_message = f"{base_message} {sign_off}"
    else:
        full_message = sign_off
    
    # Final safety check: filter full_message one more time to catch any app-specific messages
    # This ensures we catch messages that might have been in the original text or in the sign_off
    full_message = _filter_app_messages(full_message) or sign_off

    return (
        risk,
        forecast,
        why,
        full_message,
        sources,
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
    """
    Generate a weekly forecast insight previewing expected symptoms over the next 7 days.
    
    Args:
        weekly_forecast: List of dictionaries with daily forecast data (timestamp, temperature, humidity, pressure, wind)
        user_diagnoses: List of user's health conditions
        location: Optional location string
        
    Returns:
        Tuple containing the weekly forecast insight (~150 words) and a list of sources
    """
    if not client:
        return (
            "Weekly forecast insights are not available. Please configure your OpenAI API key.",
            []
        )
    
    if not weekly_forecast or len(weekly_forecast) == 0:
        return ("Weekly forecast data is not available at this time.", [])
    
    # Build forecast summary
    from datetime import datetime
    forecast_text = "\n\n7-Day Forecast:\n"
    for i, day_data in enumerate(weekly_forecast[:7]):  # Next 7 days
        day_time = day_data.get("timestamp", "")
        day_temp = day_data.get("temperature", 0)
        day_humidity = day_data.get("humidity", 0)
        day_pressure = day_data.get("pressure", 0)
        day_wind = day_data.get("wind", 0)
        
        # Format date
        try:
            if isinstance(day_time, str):
                dt = datetime.fromisoformat(day_time.replace('Z', '+00:00'))
                date_str = dt.strftime("%A, %B %d")
            else:
                date_str = f"Day {i+1}"
        except:
            date_str = f"Day {i+1}"
        
        forecast_text += f"- {date_str}: {day_temp:.0f}°C, {day_pressure:.0f} hPa, {day_humidity:.0f}% humidity, {day_wind:.0f} km/h wind\n"
    
    diagnoses_str = ", ".join(user_diagnoses) if user_diagnoses else "weather-sensitive conditions"
    location_str = f" in {location}" if location else ""
    
    # Build personalized context
    personalization = ""
    if user_diagnoses and len(user_diagnoses) > 0:
        if len(user_diagnoses) == 1:
            personalization = f"You are writing for someone with {diagnoses_str}. Address them directly and personally."
        else:
            personalization = f"You are writing for someone with multiple conditions: {diagnoses_str}. Address them directly and personally."
    else:
        personalization = "Address the user directly and personally as someone who experiences weather sensitivity."
    
    prompt = f"""You are FlareWeather, an emotionally intelligent and scientifically grounded assistant built for people with weather-sensitive chronic conditions.

{personalization}

{forecast_text}

Based on this 7-day weather forecast{location_str}, provide a brief preview (~150 words) of what the user might expect for their symptoms over the coming week. 

Focus on:
- Which days may have higher or lower symptom risk based on weather patterns
- Specific weather changes to watch for (pressure drops, temperature swings, humidity spikes)
- Days that might be better for planning activities
- General trends over the week
- If there's a stretch where weather triggers subside noticeably, call it out as a "Low Impact Window" with the relevant day/time range

IMPORTANT:
- DO NOT start with greetings like "Dear User", "Hello", or similar. Start directly with the forecast insight.
- NEVER tell the user how they feel or what symptoms they're experiencing. Use language like "may experience", "could trigger", "might find", "some people with [condition] notice", etc.
- NEVER make definitive statements about the user's current state.
- Only discuss potential effects and patterns based on the forecast.
- Keep it encouraging, practical, and focused on planning ahead (especially highlighting any Low Impact Window).
- Reference specific days (e.g., "Monday" or "mid-week") when discussing weather changes.
- Be specific about which weather factors (pressure, temperature, humidity) might affect symptoms on which days.
- Do NOT mention asking for more insights or chat features.
- Mention 1-2 trusted references (titles or organisations with URLs) that support your guidance. Introduce each reference inline with a phrase like "Source:" so it can be extracted later.
- Absolutely do NOT respond in JSON or markdown code fences. Use natural language paragraphs only.
- Present your response as 2-3 short paragraphs separated by a blank line. Avoid bullet lists.

Write in a friendly, supportive tone that helps the user plan their week. Start directly with the forecast insight (no greetings). End the message naturally without inviting further questions or mentioning chat features."""

    try:
        completion = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": "You are FlareWeather, a health and weather forecasting assistant. Your goal is to help users plan ahead by previewing how weather patterns over the next week may affect their symptoms. Always use conditional language and never make definitive statements about how the user feels."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7
        )
        response_text = completion.choices[0].message.content.strip()

        # Remove markdown code fences if present
        response_text = response_text.replace("```json", "").replace("```", "").strip()

        stripped_lower = response_text.lower()
        if stripped_lower.startswith("{") or stripped_lower.startswith("[") or "\"insight\"" in stripped_lower:
            print("⚠️  Weekly insight returned JSON despite instructions. Returning plain text fallback.")
            return ("Weekly forecast insight is currently unavailable. Please check back shortly.", [])

        sources: List[str] = []
        cleaned_lines: List[str] = []
        for line in response_text.splitlines():
            stripped = line.strip()
            if stripped.lower().startswith("source:"):
                source_text = stripped.split(":", 1)[1].strip()
                if source_text:
                    sources.append(source_text)
            else:
                cleaned_lines.append(line)

        cleaned_response = "\n".join(cleaned_lines).strip()
        if not cleaned_response:
            cleaned_response = "Unable to generate weekly forecast insight at this time."

        return (
            cleaned_response,
            sources
        )
    except Exception as e:
        print(f"❌ Error generating weekly forecast insight: {e}")
        import traceback
        traceback.print_exc()
        return ("Unable to generate weekly forecast insight at this time.", [])
