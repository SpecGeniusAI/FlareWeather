from datetime import datetime, timedelta
from typing import List, Dict, Optional

import numpy as np
import pandas as pd

from models import SymptomEntry, WeatherSnapshot


def calculate_correlations(symptoms: List[SymptomEntry], weather: List[WeatherSnapshot]) -> Dict[str, float]:
    """
    Calculate Pearson correlations between symptom severity and weather variables.
    
    Args:
        symptoms: List of SymptomEntry objects
        weather: List of WeatherSnapshot objects
        
    Returns:
        Dictionary with top 3 strongest correlations (absolute value)
    """
    # Handle empty inputs
    if not symptoms or not weather:
        return {}
    
    # Convert to DataFrames
    df_s = pd.DataFrame([{
        'timestamp': s.timestamp,
        'severity': s.severity,
        'symptom_type': s.symptom_type
    } for s in symptoms])
    
    df_w = pd.DataFrame([{
        'timestamp': w.timestamp,
        'temperature': w.temperature,
        'humidity': w.humidity,
        'pressure': w.pressure,
        'wind': w.wind
    } for w in weather])
    
    # Sort by timestamp for merge_asof
    df_s = df_s.sort_values("timestamp").reset_index(drop=True)
    df_w = df_w.sort_values("timestamp").reset_index(drop=True)
    
    # Merge dataframes by timestamp with 3-hour tolerance
    try:
        df = pd.merge_asof(
            df_s,
            df_w,
            on="timestamp",
            direction="nearest",
            tolerance=pd.Timedelta("3h")
        )
    except Exception as e:
        # If merge fails, return empty correlations
        print(f"Warning: Failed to merge dataframes: {e}")
        return {}
    
    # Check if we have enough data points for correlation (need at least 2)
    if len(df) < 2:
        return {}
    
    # Calculate correlations for each weather variable
    correlations = {}
    weather_columns = ["temperature", "humidity", "pressure", "wind"]
    
    for col in weather_columns:
        if col in df.columns:
            # Check if column has valid data
            valid_data = df[[col, "severity"]].dropna()
            if len(valid_data) >= 2:
                try:
                    corr_value = valid_data["severity"].corr(valid_data[col])
                    if not np.isnan(corr_value) and not np.isinf(corr_value):
                        correlations[col] = float(corr_value)
                except Exception as e:
                    # Skip this column if correlation calculation fails
                    print(f"Warning: Failed to calculate correlation for {col}: {e}")
                    continue
    
    # Return top 3 strongest correlations (by absolute value)
    if not correlations:
        return {}
    
    top_correlations = dict(
        sorted(correlations.items(), key=lambda x: abs(x[1]), reverse=True)[:3]
    )
    
    return top_correlations


def generate_correlation_summary(correlations: Dict[str, float], symptoms: List[SymptomEntry] = None) -> str:
    """
    Generate a human-readable summary of the correlation results, focusing on forecasting.
    
    Args:
        correlations: Dictionary of weather variable correlations
        symptoms: Optional list of symptoms to identify which symptoms are affected
        
    Returns:
        String summary of correlations focused on forecasting
    """
    if not correlations:
        return "No significant correlations found. Keep tracking symptoms to identify patterns."
    
    # Get symptom types if available
    symptom_types = []
    if symptoms:
        symptom_types = list(set([s.symptom_type for s in symptoms if s.symptom_type]))
    
    summary_parts = []
    
    # Sort by absolute correlation strength
    sorted_correlations = sorted(correlations.items(), key=lambda x: abs(x[1]), reverse=True)
    
    for variable, correlation in sorted_correlations:
        strength = "strong" if abs(correlation) > 0.7 else "moderate" if abs(correlation) > 0.4 else "weak"
        direction = "increases" if correlation > 0 else "decreases"
        
        # Map weather variable to human-readable names
        weather_name = {
            "temperature": "Temperature",
            "humidity": "Humidity",
            "pressure": "Barometric Pressure",
            "wind": "Wind Speed"
        }.get(variable, variable.title())
        
        if symptom_types:
            symptoms_str = ", ".join(symptom_types[:2])  # Show up to 2 symptom types
            if len(symptom_types) > 2:
                symptoms_str += f", and {len(symptom_types) - 2} more"
            summary_parts.append(
                f"{weather_name} has a {strength} effect on {symptoms_str} - "
                f"when {weather_name.lower()} {direction}, symptom severity tends to {direction}."
            )
        else:
            summary_parts.append(
                f"{weather_name} shows a {strength} {direction.replace('increases', 'positive').replace('decreases', 'negative')} correlation "
                f"(r={correlation:.3f}) with your symptoms."
            )
    
    return " ".join(summary_parts)


def get_weather_variable_description(variable: str) -> str:
    """
    Get a description of what each weather variable represents.
    
    Args:
        variable: Weather variable name
        
    Returns:
        Description string
    """
    descriptions = {
        "temperature": "Temperature changes can affect blood vessel dilation and inflammation",
        "humidity": "Humidity levels impact air pressure and can trigger respiratory symptoms",
        "pressure": "Barometric pressure changes are known triggers for migraines and joint pain",
        "wind": "Wind patterns can carry allergens and affect air quality"
    }
    return descriptions.get(variable, f"{variable.title()} may influence symptom patterns")


def get_upcoming_pressure_change(
    forecast_entries: List[Dict],
    current_time: datetime,
    diagnoses: Optional[List[str]] = None,
    threshold_mb: float = 5.0,
    window_hours: float = 2.0
) -> Optional[Dict]:
    """
    Detect a significant barometric pressure change in the upcoming forecast window.

    Args:
        forecast_entries: List of forecast dictionaries containing "timestamp" and "pressure" keys
        current_time: Baseline datetime for evaluation
        diagnoses: Optional list of user diagnoses/conditions for message tailoring
        threshold_mb: Minimum absolute pressure delta (in hPa) to trigger an alert
        window_hours: Maximum lookahead window in hours

    Returns:
        Dictionary with alert payload or None if no meaningful change detected.
    """
    if not forecast_entries:
        return None

    diagnoses = diagnoses or []
    future_points = []

    for entry in forecast_entries:
        ts = entry.get("timestamp")
        pressure = entry.get("pressure")
        if pressure is None or ts is None:
            continue

        if isinstance(ts, datetime):
            dt = ts
        else:
            try:
                # Handle timestamps with or without timezone "Z"
                dt = datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
            except ValueError:
                continue

        if dt < current_time:
            continue

        future_points.append((dt, float(pressure)))

    if len(future_points) < 2:
        return None

    future_points.sort(key=lambda item: item[0])

    window = timedelta(hours=window_hours)

    for i, (start_time, start_pressure) in enumerate(future_points):
        if start_time - current_time > window:
            break

        for j in range(i + 1, len(future_points)):
            target_time, target_pressure = future_points[j]
            delta_time = target_time - start_time

            if delta_time <= timedelta(seconds=0):
                continue
            if delta_time > window:
                break

            pressure_delta = target_pressure - start_pressure
            if abs(pressure_delta) >= threshold_mb:
                alert_level = _classify_pressure_delta(abs(pressure_delta))
                message = _build_pressure_message(pressure_delta, diagnoses)

                return {
                    "alert_level": alert_level,
                    "pressure_delta": round(pressure_delta, 1),
                    "trigger_time": target_time.isoformat(),
                    "suggested_message": message,
                }

    return None


def _classify_pressure_delta(delta_mb: float) -> str:
    if delta_mb >= 10:
        return "high"
    if delta_mb >= 7:
        return "moderate"
    return "mild"


def _build_pressure_message(delta: float, diagnoses: List[str]) -> str:
    direction = "drop" if delta < 0 else "rise"

    sensitivity_prompts = {
        "migraine": {
            "drop": "Migraine brains often flare when pressure drops fast. Consider hydration and a quiet break if you can.",
            "rise": "Rapid pressure rises can also bother migraine patterns—gentle stretches and steady breathing may help.",
        },
        "fibromyalgia": {
            "drop": "Fibromyalgia can feel heavier during quick pressure drops. Soft layers and pacing could ease the evening.",
            "rise": "Pressure swings may stir up fibro aches—plan a low-effort block to stay ahead of discomfort.",
        },
        "fatigue": {
            "drop": "When pressure shifts quickly, many people with chronic fatigue feel it. Build in rest where possible.",
            "rise": "Keep things gentle—pressure jumps sometimes sap energy when fatigue is in the mix.",
        },
        "arthritis": {
            "drop": "Joint pain can spike when pressure falls quickly. Warmth and mobility breaks might help.",
            "rise": "Rising pressure can still feel stiff—consider light movement to stay comfortable.",
        },
    }

    diagnoses_lower = [d.lower() for d in diagnoses]

    for condition, messages in sensitivity_prompts.items():
        if any(condition in d for d in diagnoses_lower):
            return messages[direction]

    generic = {
        "drop": "Pressure is due to drop quickly soon. A calm pocket and hydration may ease the transition.",
        "rise": "Pressure will rise quickly soon. Keep things light and listen to your body as it adjusts.",
    }

    return generic[direction]
