import pandas as pd
import numpy as np
from typing import List, Dict
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
