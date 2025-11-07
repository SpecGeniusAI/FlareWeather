import os
from typing import List, Tuple, Dict, Optional
from openai import OpenAI
from dotenv import load_dotenv
from paper_search import format_papers_for_prompt

# Load environment variables from .env file
load_dotenv()

# Initialize OpenAI client only if API key is available
api_key = os.getenv("OPENAI_API_KEY")
client = OpenAI(api_key=api_key) if api_key else None


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
) -> Tuple[str, str, str, str, List[str]]:
    """
    Generate flare risk assessment with research papers from EuropePMC.
    
    Args:
        current_weather: Dictionary with pressure, humidity, temperature, wind, condition
        pressure_trend: Optional string describing pressure trend (e.g., "dropping quickly", "stable")
        weather_factor: Strongest weather factor affecting the user
        papers: List of paper dictionaries from paper_search
        user_diagnoses: List of user's health conditions
        location: Optional location string
        
    Returns:
        Tuple of (risk, forecast, why, full_message, citations_list)
        risk: "LOW", "MODERATE", or "HIGH"
        forecast: 1-sentence forecast message
        why: Plain-language explanation
        full_message: Full AI message for backward compatibility
        citations: List of source references
    """
    if not client:
        error_msg = "AI insights are not available. Please configure your OpenAI API key in the .env file."
        return ("MODERATE", error_msg, "Unable to generate assessment.", error_msg, [])
    
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
            from datetime import datetime
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

Your task is to:
1. Analyze the current weather AND hourly forecast in relation to THIS SPECIFIC USER'S conditions (but do NOT assume they have specific weather sensitivities - only mention weather factors that are scientifically known to affect their condition type)
2. Assign a Flare Risk rating: LOW, MODERATE, or HIGH
3. Generate a friendly, 1-sentence forecast message that speaks directly to the user (use "you", "your symptoms", etc.)
4. Provide a personalized, plain-language explanation for *why* the risk is what it is, specifically referencing:
   - How current weather patterns may affect their conditions ({diagnoses_str if user_diagnoses else "their condition"})
   - If you see significant weather changes in the hourly forecast (e.g., pressure drops, temperature swings, humidity spikes), mention specific times when symptom triggers might occur later today (e.g., "Pressure is expected to drop around 3PM, which may trigger symptoms")
   - ONLY mention weather factors that are currently happening or clearly forecasted, not assumed sensitivities
5. Include 1–2 trusted source references (e.g., Mayo Clinic, NIH, Arthritis Foundation, or from the research papers provided)

IMPORTANT: 
- Personalize everything. Write as if you know this person's specific experience with {diagnoses_str if user_diagnoses else "their condition"}. Use "you" and "your" throughout.
- NEVER tell the user how they feel or what symptoms they're experiencing. Use language like "may affect", "could trigger", "might experience", "some people with [condition] find", "weather patterns associated with", etc.
- NEVER make definitive statements about the user's current state (e.g., don't say "you're feeling", "your symptoms are", "you have"). Only discuss potential effects and patterns.
- Reference potential symptoms that people with their conditions might experience, but frame it as possibilities, not certainties.
- If the hourly forecast shows significant weather changes later in the day (pressure drops >5 hPa, temperature swings >5°C, humidity changes >15%), specifically mention when these changes might trigger symptoms (e.g., "Around 2-4 PM" or "This evening") but use conditional language.
- DO NOT assume the user has specific weather sensitivities (like "your known sensitivity to humidity"). Only discuss the current and forecasted weather conditions and how they may affect their condition type.
- Focus on what's happening with the weather right now and what's predicted to happen later today.

Output your response as valid JSON in this exact format:
{{
  "risk": "HIGH",  // LOW, MODERATE, or HIGH
  "forecast": "Flare risk is high — pressure is crashing this afternoon. If you can, build in extra rest.",
  "why": "Rapid drops in barometric pressure can worsen symptoms for people with arthritis and migraines.",
  "sources": [
    "NIH: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4516866/",
    "Mayo Clinic: https://www.mayoclinic.org/diseases-conditions/migraine-headache"
  ]
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
            from datetime import datetime
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

Your task is to:
1. Analyze the current weather AND hourly forecast in relation to THIS SPECIFIC USER'S conditions (but do NOT assume they have specific weather sensitivities - only mention weather factors that are scientifically known to affect their condition type)
2. Assign a Flare Risk rating: LOW, MODERATE, or HIGH
3. Generate a friendly, 1-sentence forecast message that speaks directly to the user (use "you", "your symptoms", etc.)
4. Provide a personalized, plain-language explanation for *why* the risk is what it is, specifically referencing:
   - How current weather patterns may affect their conditions ({diagnoses_str if user_diagnoses else "their condition"})
   - If you see significant weather changes in the hourly forecast (e.g., pressure drops, temperature swings, humidity spikes), mention specific times when symptom triggers might occur later today (e.g., "Pressure is expected to drop around 3PM, which may trigger symptoms")
   - ONLY mention weather factors that are currently happening or clearly forecasted, not assumed sensitivities
5. Include 1–2 trusted source references (e.g., Mayo Clinic, NIH, Arthritis Foundation, Cleveland Clinic)

IMPORTANT: 
- Personalize everything. Write as if you know this person's specific experience with {diagnoses_str if user_diagnoses else "their condition"}. Use "you" and "your" throughout.
- NEVER tell the user how they feel or what symptoms they're experiencing. Use language like "may affect", "could trigger", "might experience", "some people with [condition] find", "weather patterns associated with", etc.
- NEVER make definitive statements about the user's current state (e.g., don't say "you're feeling", "your symptoms are", "you have"). Only discuss potential effects and patterns.
- Reference potential symptoms that people with their conditions might experience, but frame it as possibilities, not certainties.
- If the hourly forecast shows significant weather changes later in the day (pressure drops >5 hPa, temperature swings >5°C, humidity changes >15%), specifically mention when these changes might trigger symptoms (e.g., "Around 2-4 PM" or "This evening") but use conditional language.
- DO NOT assume the user has specific weather sensitivities (like "your known sensitivity to humidity"). Only discuss the current and forecasted weather conditions and how they may affect their condition type.
- Focus on what's happening with the weather right now and what's predicted to happen later today.

Output your response as valid JSON in this exact format:
{{
  "risk": "HIGH",  // LOW, MODERATE, or HIGH
  "forecast": "Flare risk is high — pressure is crashing this afternoon. If you can, build in extra rest.",
  "why": "Rapid drops in barometric pressure can worsen symptoms for people with arthritis and migraines.",
  "sources": [
    "NIH: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4516866/",
    "Mayo Clinic: https://www.mayoclinic.org/diseases-conditions/migraine-headache"
  ]
}}

Make the tone calm, supportive, and practical. Never alarmist. Keep it short and empathetic. Write personally and directly to the user."""
    
    try:
        completion = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": "You are FlareWeather, an emotionally intelligent and scientifically grounded assistant built for people with weather-sensitive chronic conditions. Your goal is to provide calm, supportive, and practical flare risk assessments. Never be alarmist."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7,
            response_format={"type": "json_object"}
        )
        
        response_text = completion.choices[0].message.content.strip()
        
        # Parse JSON response
        import json
        try:
            response_json = json.loads(response_text)
            risk = response_json.get("risk", "MODERATE").upper()
            forecast = response_json.get("forecast", "Unable to assess flare risk at this time.")
            why = response_json.get("why", "Weather data analysis in progress.")
            sources = response_json.get("sources", [])
            
            # Build full message for backward compatibility (without sources)
            # The "why" explanation is now the main personalized AI insight
            full_message = why if why else forecast
            
            # Extract citations from sources (PMCID or titles)
            citations = sources.copy()
            
            print(f"✅ Generated flare risk assessment: {risk}")
            print(f"📋 Forecast: {forecast}")
            print(f"📚 Sources: {sources}")
            
            return (risk, forecast, why, full_message, citations)
        except json.JSONDecodeError as e:
            print(f"⚠️  Failed to parse JSON response: {e}")
            print(f"📝 Raw response: {response_text[:500]}")
            # Fallback: try to extract risk from text
            response_upper = response_text.upper()
            if "HIGH" in response_upper and ("RISK" in response_upper or "FLARE" in response_upper):
                risk = "HIGH"
            elif "MODERATE" in response_upper and ("RISK" in response_upper or "FLARE" in response_upper):
                risk = "MODERATE"
            elif "LOW" in response_upper and ("RISK" in response_upper or "FLARE" in response_upper):
                risk = "LOW"
            else:
                risk = "MODERATE"
            
            return (risk, response_text, "Weather analysis completed.", response_text, [])
    except Exception as e:
        print(f"❌ Error generating flare risk assessment: {e}")
        import traceback
        traceback.print_exc()
        
        # Fallback: simple risk assessment based on pressure trends
        if pressure_trend and "drop" in pressure_trend.lower():
            risk = "HIGH"
            forecast = "Flare risk may be elevated due to dropping pressure. Consider taking things slowly."
            why = "Barometric pressure drops may trigger symptoms for some people with weather-sensitive conditions."
        elif pressure < 1000:
            risk = "MODERATE"
            forecast = "Current weather conditions may affect symptoms for some people. Monitor how you're feeling."
            why = "Lower barometric pressure can potentially influence symptoms for some conditions."
        else:
            risk = "LOW"
            forecast = "Weather conditions look relatively stable. Continue monitoring your symptoms."
            why = "Stable weather patterns are typically associated with fewer flare-ups for some people."
        
        fallback_message = f"{forecast}\n\n{why}"
        return (risk, forecast, why, fallback_message, [])


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
    
    risk, forecast, why, full_message, citations = generate_flare_risk_assessment(
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
) -> str:
    """
    Generate a weekly forecast insight previewing expected symptoms over the next 7 days.
    
    Args:
        weekly_forecast: List of dictionaries with daily forecast data (timestamp, temperature, humidity, pressure, wind)
        user_diagnoses: List of user's health conditions
        location: Optional location string
        
    Returns:
        String with weekly forecast insight (~150 words)
    """
    if not client:
        return "Weekly forecast insights are not available. Please configure your OpenAI API key."
    
    if not weekly_forecast or len(weekly_forecast) == 0:
        return "Weekly forecast data is not available at this time."
    
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

IMPORTANT:
- NEVER tell the user how they feel or what symptoms they're experiencing. Use language like "may experience", "could trigger", "might find", "some people with [condition] notice", etc.
- NEVER make definitive statements about the user's current state.
- Only discuss potential effects and patterns based on the forecast.
- Keep it encouraging, practical, and focused on planning ahead.
- Reference specific days (e.g., "Monday" or "mid-week") when discussing weather changes.
- Be specific about which weather factors (pressure, temperature, humidity) might affect symptoms on which days.
- Do NOT include messages about asking for more insights, chat features, or being available to help. Just provide the forecast insight and end.

Write in a friendly, supportive tone that helps the user plan their week. End the message naturally without inviting further questions or mentioning chat features."""
    
    try:
        completion = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": "You are FlareWeather, a health and weather forecasting assistant. Your goal is to help users plan ahead by previewing how weather patterns over the next week may affect their symptoms. Always use conditional language and never make definitive statements about how the user feels."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7
        )
        insight = completion.choices[0].message.content.strip()
        return insight
    except Exception as e:
        print(f"❌ Error generating weekly forecast insight: {e}")
        import traceback
        traceback.print_exc()
        return "Unable to generate weekly forecast insight at this time."
