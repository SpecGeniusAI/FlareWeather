from datetime import datetime
from typing import List, Optional, Dict
from pydantic import BaseModel, Field, EmailStr


# Authentication models
class SignupRequest(BaseModel):
    """Request model for user signup"""
    email: EmailStr
    password: str = Field(min_length=8, description="Password must be at least 8 characters")
    name: Optional[str] = None


class LoginRequest(BaseModel):
    """Request model for user login"""
    email: EmailStr
    password: str


class AppleSignInRequest(BaseModel):
    """Request model for Apple Sign In"""
    user_identifier: str
    identity_token: str
    authorization_code: Optional[str] = None
    email: Optional[EmailStr] = None
    name: Optional[str] = None


class AuthResponse(BaseModel):
    """Response model for authentication"""
    access_token: str
    token_type: str = "bearer"
    user_id: str
    email: str
    name: Optional[str] = None


class UserResponse(BaseModel):
    """Response model for user info"""
    user_id: str
    email: str = ""  # Allow empty string for Apple Sign In users
    name: Optional[str] = None
    created_at: datetime


# Request models matching iOS format (with string timestamps)
class SymptomEntryPayload(BaseModel):
    """Request model for symptom entry from iOS"""
    timestamp: str
    symptom_type: str
    severity: int = Field(ge=1, le=10, description="Severity scale from 1-10")


class WeatherSnapshotPayload(BaseModel):
    """Request model for weather snapshot from iOS"""
    timestamp: str
    temperature: float = Field(description="Temperature in Celsius")
    humidity: float = Field(ge=0, le=100, description="Humidity percentage")
    pressure: float = Field(gt=0, description="Atmospheric pressure in hPa")
    wind: float = Field(ge=0, description="Wind speed in km/h")


class CorrelationRequest(BaseModel):
    """Request model for correlation analysis (matches iOS format)"""
    symptoms: Optional[List[SymptomEntryPayload]] = []  # Optional - can be empty for weather-only insights
    weather: List[WeatherSnapshotPayload]
    hourly_forecast: Optional[List[WeatherSnapshotPayload]] = []  # Optional hourly forecast data
    weekly_forecast: Optional[List[WeatherSnapshotPayload]] = []  # Optional weekly forecast data (7-day)
    user_id: Optional[str] = None
    diagnoses: Optional[List[str]] = None  # User's health diagnoses/conditions for personalization


# Internal models for processing (with datetime objects)
class SymptomEntry(BaseModel):
    """Model for individual symptom entries (internal use)"""
    id: str
    timestamp: datetime
    symptom_type: str
    severity: int = Field(ge=1, le=10, description="Severity scale from 1-10")
    notes: Optional[str] = None


class WeatherSnapshot(BaseModel):
    """Model for weather data at a specific timestamp (internal use)"""
    timestamp: datetime
    temperature: float = Field(description="Temperature in Celsius")
    humidity: float = Field(ge=0, le=100, description="Humidity percentage")
    pressure: float = Field(gt=0, description="Atmospheric pressure in hPa")
    wind: float = Field(ge=0, description="Wind speed in km/h")


class InsightResponse(BaseModel):
    """Response model for AI-generated insights"""
    correlation_summary: str
    strongest_factors: Dict[str, float]
    ai_message: str
    citations: List[str] = []  # List of source filenames used in RAG response
    risk: Optional[str] = None  # LOW, MODERATE, or HIGH
    forecast: Optional[str] = None  # 1-sentence forecast message
    why: Optional[str] = None  # Plain-language explanation for the risk
    weekly_forecast_insight: Optional[str] = None  # Weekly forecast preview insight
