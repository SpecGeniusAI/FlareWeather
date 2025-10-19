from datetime import datetime
from typing import List, Optional, Dict
from pydantic import BaseModel, Field


class SymptomEntry(BaseModel):
    """Model for individual symptom entries"""
    id: str
    timestamp: datetime
    symptom_type: str
    severity: int = Field(ge=1, le=10, description="Severity scale from 1-10")
    notes: Optional[str] = None


class WeatherSnapshot(BaseModel):
    """Model for weather data at a specific timestamp"""
    timestamp: datetime
    temperature: float = Field(description="Temperature in Celsius")
    humidity: float = Field(ge=0, le=100, description="Humidity percentage")
    pressure: float = Field(gt=0, description="Atmospheric pressure in hPa")
    wind: float = Field(ge=0, description="Wind speed in km/h")


class CorrelationRequest(BaseModel):
    """Request model for correlation analysis"""
    symptoms: List[SymptomEntry]
    weather: List[WeatherSnapshot]
    user_id: Optional[str] = None


class InsightResponse(BaseModel):
    """Response model for AI-generated insights"""
    correlation_summary: str
    strongest_factors: Dict[str, float]
    ai_message: str
