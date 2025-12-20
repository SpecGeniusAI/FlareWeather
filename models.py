from datetime import datetime
from typing import List, Optional, Dict, Any
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


class ForgotPasswordRequest(BaseModel):
    """Request model for password reset"""
    email: EmailStr


class ForgotPasswordResponse(BaseModel):
    """Response model for forgot password flow"""
    message: str


class ResetPasswordRequest(BaseModel):
    """Request model for resetting password with code"""
    email: EmailStr
    code: str = Field(min_length=6, max_length=6)
    new_password: str = Field(min_length=8)


class ResetPasswordResponse(BaseModel):
    """Response model for reset password"""
    success: bool = True


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
    has_access: Optional[bool] = None  # Whether user has active access (subscription or free)
    access_type: Optional[str] = None  # "subscription" | "free" | "none"
    access_expires_at: Optional[str] = None  # ISO datetime string or None
    access_required: Optional[bool] = None  # Whether access is required for full features
    access_expired: Optional[bool] = None  # True if user's free access has expired
    logout_message: Optional[str] = None  # Message to show under logout button


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
    sensitivities: Optional[List[str]] = None  # User's weather sensitivities/triggers (e.g., "Pressure shifts", "Humidity changes")
    skip_weekly: Optional[bool] = False  # If True, skip weekly forecast generation for faster daily insight response


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
    weekly_insight_sources: Optional[List[str]] = None  # Sources for the weekly insight
    support_note: Optional[str] = None  # Optional emotional encouragement for moderate/high risk
    pressure_alert: Optional[Dict[str, Any]] = None  # Optional pressure alert payload
    alert_severity: Optional[str] = None  # low, moderate, sharp
    personalization_score: Optional[int] = None  # 1-5 personalization rating
    personal_anecdote: Optional[str] = None
    behavior_prompt: Optional[str] = None
    access_required: Optional[bool] = None  # True if user needs to subscribe/upgrade for full access
    access_expired: Optional[bool] = None  # True if user's free access has expired
    logout_message: Optional[str] = None  # Message to show under logout button


class FeedbackRequest(BaseModel):
    """Request model for AI insight feedback"""
    was_helpful: bool
    analysis_id: Optional[str] = None
    analysis_hash: Optional[str] = None
    user_id: Optional[str] = None
    risk: Optional[str] = None
    forecast: Optional[str] = None
    why: Optional[str] = None
    support_note: Optional[str] = None
    citations: List[str] = Field(default_factory=list)
    diagnoses: Optional[List[str]] = None
    location: Optional[str] = None
    app_version: Optional[str] = None
    pressure_alert: Optional[Dict[str, Any]] = None
    alert_severity: Optional[str] = None
    personalization_score: Optional[int] = None
    personal_anecdote: Optional[str] = None
    behavior_prompt: Optional[str] = None


class FeedbackResponse(BaseModel):
    """Response model for feedback submission"""
    status: str = "success"
    feedback_id: str


# Admin models for free access management
class GrantFreeAccessRequest(BaseModel):
    """Request model for granting free access"""
    user_identifier: str = Field(description="User email or user_id")
    days: Optional[int] = Field(None, description="Number of days to grant access (None = never expires)")
    expires_at: Optional[str] = Field(None, description="ISO datetime string for expiration (overrides days if provided)")


class RevokeFreeAccessRequest(BaseModel):
    """Request model for revoking free access"""
    user_identifier: str = Field(description="User email or user_id")


class FreeAccessResponse(BaseModel):
    """Response model for free access operations"""
    success: bool
    message: str
    user_id: Optional[str] = None
    email: Optional[str] = None
    free_access_enabled: Optional[bool] = None
    free_access_expires_at: Optional[str] = None


class AccessStatusResponse(BaseModel):
    """Response model for access status check"""
    user_id: str
    email: Optional[str] = None
    has_access: bool
    access_type: str  # "subscription" | "free" | "none"
    expires_at: Optional[str] = None
    is_expired: bool
    logout_message: Optional[str] = None  # Message to show under logout button


class LinkSubscriptionRequest(BaseModel):
    """Request model for linking subscription to user"""
    original_transaction_id: str
    product_id: Optional[str] = None  # Optional: subscription product ID (e.g., "monthly", "yearly")


class PushTokenRequest(BaseModel):
    """Request model for registering push notification token"""
    push_token: str


class NotificationSettingsRequest(BaseModel):
    """Request model for updating notification settings"""
    enabled: bool


class LocationUpdateRequest(BaseModel):
    """Request model for updating user location"""
    latitude: float
    longitude: float
    location_name: Optional[str] = None


class DailyForecastResponse(BaseModel):
    """Response model for pre-primed daily forecast"""
    forecast_date: str
    daily_risk_level: Optional[str] = None
    daily_forecast_summary: Optional[str] = None
    daily_why_explanation: Optional[str] = None
    daily_comfort_tip: Optional[str] = None
    weekly_forecast_insight: Optional[str] = None
    current_weather: Optional[Dict[str, Any]] = None
    hourly_forecast: Optional[List[Dict[str, Any]]] = None
    daily_forecast: Optional[List[Dict[str, Any]]] = None
    available: bool = False
