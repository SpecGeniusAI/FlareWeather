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
    
    # Merge dataframes by timestamp with 3-hour tolerance
    df = pd.merge_asof(
        df_s.sort_values("timestamp"),
        df_w.sort_values("timestamp"),
        on="timestamp",
        direction="nearest",
        tolerance=pd.Timedelta("3h")
    )
    
    # Calculate correlations for each weather variable
    correlations = {}
    weather_columns = ["temperature", "humidity", "pressure", "wind"]
    
    for col in weather_columns:
        if col in df.columns and not df[col].isna().all():
            corr_value = df["severity"].corr(df[col])
            if not np.isnan(corr_value):
                correlations[col] = corr_value
    
    # Return top 3 strongest correlations (by absolute value)
    top_correlations = dict(
        sorted(correlations.items(), key=lambda x: abs(x[1]), reverse=True)[:3]
    )
    
    return top_correlations


def generate_correlation_summary(correlations: Dict[str, float]) -> str:
    """
    Generate a human-readable summary of the correlation results.
    
    Args:
        correlations: Dictionary of weather variable correlations
        
    Returns:
        String summary of correlations
    """
    if not correlations:
        return "No significant correlations found between symptoms and weather patterns."
    
    summary_parts = []
    
    for variable, correlation in correlations.items():
        strength = "strong" if abs(correlation) > 0.7 else "moderate" if abs(correlation) > 0.4 else "weak"
        direction = "positive" if correlation > 0 else "negative"
        
        summary_parts.append(
            f"{variable.title()} shows a {strength} {direction} correlation "
            f"(r={correlation:.3f}) with symptom severity."
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
