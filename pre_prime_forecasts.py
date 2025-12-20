"""
Pre-prime daily forecasts for push notifications.
Runs daily at 7:45 AM EST to fetch weather and generate insights.
"""
import os
import sys
from datetime import datetime, timedelta, date
from typing import Optional, Dict, Any, List
import json
import requests
from dotenv import load_dotenv

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from database import SessionLocal, User, DailyForecast, init_db
from ai import generate_flare_risk_assessment, generate_weekly_forecast_insight, _analyze_pressure_window
from access_utils import has_active_access
import pytz

load_dotenv()

# OpenWeatherMap API
OPENWEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY")
OPENWEATHER_BASE_URL = "https://api.openweathermap.org/data/3.0/onecall"

# Timezone
EST = pytz.timezone("America/New_York")


def get_user_location(user: User) -> Optional[Dict[str, float]]:
    """Get user's location from User table or return None."""
    if user.last_location_latitude and user.last_location_longitude:
        return {
            "latitude": user.last_location_latitude,
            "longitude": user.last_location_longitude,
            "name": user.last_location_name
        }
    return None


def fetch_weather_openweather(latitude: float, longitude: float) -> Optional[Dict[str, Any]]:
    """
    Fetch weather data from OpenWeatherMap API.
    Returns current weather, hourly forecast (24h), and daily forecast (7 days).
    """
    if not OPENWEATHER_API_KEY:
        print("❌ OPENWEATHER_API_KEY not set")
        return None
    
    try:
        url = f"{OPENWEATHER_BASE_URL}"
        params = {
            "lat": latitude,
            "lon": longitude,
            "appid": OPENWEATHER_API_KEY,
            "units": "metric",  # Celsius
            "exclude": "minutely,alerts"  # We don't need minutely or alerts
        }
        
        response = requests.get(url, params=params, timeout=10)
        response.raise_for_status()
        
        data = response.json()
        
        # Transform to match our expected format
        current = data.get("current", {})
        hourly = data.get("hourly", [])[:24]  # Next 24 hours
        daily = data.get("daily", [])[:7]  # Next 7 days
        
        # Convert to our format
        weather_data = {
            "current": {
                "temperature": current.get("temp", 0),
                "humidity": current.get("humidity", 0),
                "pressure": current.get("pressure", 1013.25),  # hPa
                "wind": current.get("wind_speed", 0) * 3.6,  # Convert m/s to km/h
                "timestamp": datetime.fromtimestamp(current.get("dt", 0), tz=pytz.UTC).isoformat()
            },
            "hourly": [
                {
                    "temperature": h.get("temp", 0),
                    "humidity": h.get("humidity", 0),
                    "pressure": h.get("pressure", 1013.25),
                    "wind": h.get("wind_speed", 0) * 3.6,
                    "timestamp": datetime.fromtimestamp(h.get("dt", 0), tz=pytz.UTC).isoformat()
                }
                for h in hourly
            ],
            "daily": [
                {
                    "temperature": d.get("temp", {}).get("day", 0),
                    "high_temp": d.get("temp", {}).get("max", 0),
                    "low_temp": d.get("temp", {}).get("min", 0),
                    "humidity": d.get("humidity", 0),
                    "pressure": d.get("pressure", 1013.25),
                    "wind": d.get("wind_speed", 0) * 3.6,
                    "timestamp": datetime.fromtimestamp(d.get("dt", 0), tz=pytz.UTC).isoformat(),
                    "condition": d.get("weather", [{}])[0].get("main", "Clear")
                }
                for d in daily
            ]
        }
        
        return weather_data
        
    except Exception as e:
        print(f"❌ Error fetching weather from OpenWeatherMap: {e}")
        return None


def generate_daily_insight_for_user(
    weather_data: Dict[str, Any],
    user: User,
    db_session=None
) -> Optional[Dict[str, Any]]:
    """Generate daily insight using existing AI functions."""
    try:
        # Parse user diagnoses and sensitivities
        diagnoses = []
        sensitivities = []
        
        if user.diagnoses:
            try:
                diagnoses = json.loads(user.diagnoses) if isinstance(user.diagnoses, str) else user.diagnoses
            except:
                diagnoses = []
        
        # Get current weather
        current = weather_data.get("current", {})
        current_weather = {
            "temperature": current.get("temperature", 0),
            "humidity": current.get("humidity", 0),
            "pressure": current.get("pressure", 1013.25),
            "wind": current.get("wind", 0)
        }
        
        # Prepare hourly forecast (for pressure analysis)
        hourly_forecast = weather_data.get("hourly", [])
        
        # Analyze pressure trend
        severity_label, signed_delta, direction = _analyze_pressure_window(hourly_forecast, current_weather)
        pressure_trend = direction
        
        # Determine strongest weather factor (default to pressure)
        strongest_factor = "pressure"
        
        # Generate insight using generate_flare_risk_assessment
        risk, forecast, why, ai_message, paper_citations, support_note, alert_severity, personalization_score, personal_anecdote, behavior_prompt = generate_flare_risk_assessment(
            current_weather=current_weather,
            pressure_trend=pressure_trend,
            weather_factor=strongest_factor,
            papers=[],  # Skip papers for pre-priming (faster)
            user_diagnoses=diagnoses,
            user_sensitivities=sensitivities,
            location=None,
            hourly_forecast=hourly_forecast,
            db_session=db_session  # Pass database session for tip history tracking
        )
        
        # Build insight result dict
        insight_result = {
            "risk": risk or "MODERATE",
            "forecast": forecast or "Weather patterns are being analyzed.",
            "why": why or "Analyzing current conditions...",
            "ai_message": ai_message,
            "citations": paper_citations or [],
            "support_note": support_note,
            "alert_severity": alert_severity,
            "personalization_score": personalization_score,
            "personal_anecdote": personal_anecdote,
            "behavior_prompt": behavior_prompt
        }
        
        return insight_result
        
    except Exception as e:
        print(f"❌ Error generating daily insight: {e}")
        import traceback
        traceback.print_exc()
        return None


def generate_weekly_insight_for_user(
    weather_data: Dict[str, Any],
    user: User,
    daily_insight: Optional[Dict[str, Any]] = None
) -> Optional[tuple]:
    """Generate weekly forecast insight using existing AI function."""
    try:
        # Parse user diagnoses and sensitivities
        diagnoses = []
        sensitivities = []
        
        if user.diagnoses:
            try:
                diagnoses = json.loads(user.diagnoses) if isinstance(user.diagnoses, str) else user.diagnoses
            except:
                diagnoses = []
        
        # Get daily forecast (7 days)
        daily_forecast = weather_data.get("daily", [])
        
        # Convert to format expected by generate_weekly_forecast_insight
        weekly_forecast_data = [
            {
                "timestamp": d.get("timestamp", ""),
                "temperature": d.get("temperature", 0),
                "high_temp": d.get("high_temp", 0),
                "low_temp": d.get("low_temp", 0),
                "humidity": d.get("humidity", 0),
                "pressure": d.get("pressure", 1013.25),
                "wind": d.get("wind", 0)
            }
            for d in daily_forecast
        ]
        
        # Get today's context from daily insight
        today_risk_context = None
        today_pressure = None
        today_temp = None
        today_humidity = None
        
        if daily_insight:
            today_risk_context = f"Today's flare risk is {daily_insight.get('risk', 'MODERATE')}."
            current = weather_data.get("current", {})
            today_pressure = current.get("pressure")
            today_temp = current.get("temperature")
            today_humidity = current.get("humidity")
        
        # Generate weekly insight
        weekly_insight_text, weekly_insight_sources = generate_weekly_forecast_insight(
            weekly_forecast=weekly_forecast_data,
            user_diagnoses=diagnoses,
            user_sensitivities=sensitivities,
            location=None,
            today_risk_context=today_risk_context,
            today_pressure=today_pressure,
            today_temp=today_temp,
            today_humidity=today_humidity,
            pressure_trend=None,
            tomorrow_expected_pressure=weekly_forecast_data[1].get("pressure") if len(weekly_forecast_data) > 1 else None
        )
        
        return (weekly_insight_text, weekly_insight_sources)
        
    except Exception as e:
        print(f"❌ Error generating weekly insight: {e}")
        import traceback
        traceback.print_exc()
        return None


def store_daily_forecast(
    db: SessionLocal,
    user: User,
    forecast_date: date,
    weather_data: Dict[str, Any],
    daily_insight: Dict[str, Any],
    weekly_insight: Optional[tuple]
):
    """Store pre-primed forecast in database."""
    try:
        # Check if forecast already exists
        existing = db.query(DailyForecast).filter(
            DailyForecast.user_id == user.id,
            DailyForecast.forecast_date == forecast_date
        ).first()
        
        if existing:
            # Update existing
            forecast = existing
        else:
            # Create new
            forecast = DailyForecast(
                user_id=user.id,
                forecast_date=forecast_date
            )
            db.add(forecast)
        
        # Update location
        location = get_user_location(user)
        if location:
            forecast.location_latitude = location["latitude"]
            forecast.location_longitude = location["longitude"]
            forecast.location_name = location.get("name")
        
        # Store weather data
        forecast.current_weather = weather_data.get("current")
        forecast.hourly_forecast = weather_data.get("hourly")
        forecast.daily_forecast = weather_data.get("daily")
        
        # Store daily insight
        if daily_insight:
            forecast.daily_risk_level = daily_insight.get("risk", "MODERATE")
            forecast.daily_forecast_summary = daily_insight.get("forecast")
            forecast.daily_why_explanation = daily_insight.get("why")
            forecast.daily_insight = daily_insight
            forecast.daily_comfort_tip = daily_insight.get("support_note")
        
        # Store weekly insight
        if weekly_insight:
            weekly_text, weekly_sources = weekly_insight
            forecast.weekly_forecast_insight = weekly_text
            forecast.weekly_insight_sources = weekly_sources
        
        # Mark as not sent yet (will be sent at 8:00 AM)
        forecast.notification_sent = False
        forecast.notification_sent_at = None
        
        forecast.updated_at = datetime.utcnow()
        
        db.commit()
        
        return forecast
        
    except Exception as e:
        db.rollback()
        print(f"❌ Error storing forecast: {e}")
        import traceback
        traceback.print_exc()
        raise


def pre_prime_forecasts():
    """Main function to pre-prime forecasts for all active users."""
    print("🌅 Starting daily forecast pre-priming...")
    print(f"⏰ Time: {datetime.now(EST).strftime('%Y-%m-%d %H:%M:%S %Z')}")
    
    # Initialize database
    init_db()
    
    db = SessionLocal()
    today = date.today()
    
    try:
        # Get active users (logged in within last 7 days)
        cutoff_date = datetime.utcnow() - timedelta(days=7)
        active_users = db.query(User).filter(
            User.updated_at >= cutoff_date
        ).all()
        
        print(f"📊 Found {len(active_users)} active users")
        
        success_count = 0
        error_count = 0
        
        for user in active_users:
            try:
                # Only pre-prime for users with active access (subscribers or lifetime users)
                if not has_active_access(db, user.id):
                    print(f"⏭️  Skipping {user.email or user.id}: No active access (not subscribed or lifetime)")
                    continue
                
                # Get user location
                location = get_user_location(user)
                if not location:
                    print(f"⏭️  Skipping {user.email or user.id}: No location stored")
                    continue
                
                print(f"🌤️  Pre-priming for {user.email or user.id}...")
                
                # Fetch weather
                weather_data = fetch_weather_openweather(
                    location["latitude"],
                    location["longitude"]
                )
                
                if not weather_data:
                    print(f"❌ Failed to fetch weather for {user.email or user.id}")
                    error_count += 1
                    continue
                
                # Generate daily insight (pass db session for tip history tracking)
                daily_insight = generate_daily_insight_for_user(weather_data, user, db_session=db)
                if not daily_insight:
                    print(f"❌ Failed to generate daily insight for {user.email or user.id}")
                    error_count += 1
                    continue
                
                # Generate weekly insight
                weekly_insight = generate_weekly_insight_for_user(weather_data, user, daily_insight)
                
                # Store in database
                store_daily_forecast(
                    db=db,
                    user=user,
                    forecast_date=today,
                    weather_data=weather_data,
                    daily_insight=daily_insight,
                    weekly_insight=weekly_insight
                )
                
                print(f"✅ Pre-primed forecast for {user.email or user.id}")
                success_count += 1
                
            except Exception as e:
                print(f"❌ Error processing {user.email or user.id}: {e}")
                error_count += 1
                import traceback
                traceback.print_exc()
                continue
        
        print(f"\n📊 Pre-priming complete:")
        print(f"   ✅ Success: {success_count}")
        print(f"   ❌ Errors: {error_count}")
        print(f"   📅 Date: {today}")
        
    finally:
        db.close()


if __name__ == "__main__":
    pre_prime_forecasts()
