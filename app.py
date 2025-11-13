from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime, timedelta
from typing import List, Tuple
from sqlalchemy.orm import Session
import uuid
import json

# Import with error handling to catch import errors early
try:
    from models import (
        CorrelationRequest, 
        SymptomEntryPayload, 
        WeatherSnapshotPayload,
        SymptomEntry,
        WeatherSnapshot,
        InsightResponse,
        SignupRequest,
        LoginRequest,
        AppleSignInRequest,
        AuthResponse,
        UserResponse,
        FeedbackRequest,
        FeedbackResponse
    )
    from logic import calculate_correlations, generate_correlation_summary, get_upcoming_pressure_change
    from ai import generate_insight_with_papers, generate_flare_risk_assessment, generate_weekly_forecast_insight, _choose_forecast, _analyze_pressure_window
    from rag.query import query_rag
    from paper_search import search_papers, format_papers_for_prompt
    from database import get_db, init_db, User, InsightFeedback
    from auth import (
        verify_password,
        get_password_hash,
        create_access_token,
        get_current_user,
        ACCESS_TOKEN_EXPIRE_MINUTES
    )
    # Try to import app store notifications (optional)
    try:
        from app_store_notifications import router as apple_notifications_router
        apple_notifications_router_available = True
    except ImportError as e:
        print(f"⚠️  App Store Notifications not available: {e}")
        apple_notifications_router = None
        apple_notifications_router_available = False
    print("✅ All imports successful")
except ImportError as e:
    print(f"❌ Critical import error: {e}")
    import traceback
    traceback.print_exc()
    raise

app = FastAPI(title="FlareWeather API")

# Include Apple App Store Notifications router (if available)
if apple_notifications_router_available and apple_notifications_router:
    try:
        app.include_router(apple_notifications_router)
        print("✅ App Store Notifications router included")
    except Exception as e:
        print(f"⚠️  App Store Notifications router error (non-fatal): {e}")
else:
    print("ℹ️  App Store Notifications router not available (skipping)")

# Initialize database on startup
@app.on_event("startup")
async def startup_event():
    print("🚀 Starting FlareWeather backend...")
    try:
        init_db()
        print("✅ Database initialized successfully")
    except Exception as e:
        print(f"⚠️  Database initialization error: {e}")
        import traceback
        traceback.print_exc()
        # Don't crash the app if database init fails - it will retry on first request
    print("✅ FastAPI app started successfully")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"]
)


def convert_payload_to_models(
    symptom_payloads: List[SymptomEntryPayload],
    weather_payloads: List[WeatherSnapshotPayload]
) -> Tuple[List[SymptomEntry], List[WeatherSnapshot]]:
    """Convert request payloads (with string timestamps) to internal models (with datetime objects)"""
    symptoms = []
    for payload in symptom_payloads:
        try:
            # Parse ISO format timestamp string
            timestamp = datetime.fromisoformat(payload.timestamp.replace('Z', '+00:00'))
            symptoms.append(SymptomEntry(
                id=str(uuid.uuid4()),
                timestamp=timestamp,
                symptom_type=payload.symptom_type,
                severity=payload.severity
            ))
        except (ValueError, AttributeError) as e:
            # Try alternative parsing if ISO format fails
            try:
                timestamp = datetime.strptime(payload.timestamp, "%Y-%m-%dT%H:%M:%S")
                symptoms.append(SymptomEntry(
                    id=str(uuid.uuid4()),
                    timestamp=timestamp,
                    symptom_type=payload.symptom_type,
                    severity=payload.severity
                ))
            except ValueError:
                raise HTTPException(status_code=400, detail=f"Invalid timestamp format: {payload.timestamp}")
    
    weather_snapshots = []
    for payload in weather_payloads:
        try:
            # Parse ISO format timestamp string
            timestamp = datetime.fromisoformat(payload.timestamp.replace('Z', '+00:00'))
            weather_snapshots.append(WeatherSnapshot(
                timestamp=timestamp,
                temperature=payload.temperature,
                humidity=payload.humidity,
                pressure=payload.pressure,
                wind=payload.wind
            ))
        except (ValueError, AttributeError):
            try:
                timestamp = datetime.strptime(payload.timestamp, "%Y-%m-%dT%H:%M:%S")
                weather_snapshots.append(WeatherSnapshot(
                    timestamp=timestamp,
                    temperature=payload.temperature,
                    humidity=payload.humidity,
                    pressure=payload.pressure,
                    wind=payload.wind
                ))
            except ValueError:
                raise HTTPException(status_code=400, detail=f"Invalid timestamp format: {payload.timestamp}")
    
    return symptoms, weather_snapshots


@app.get("/")
async def root():
    return {"message": "FlareWeather API is running"}


@app.get("/health")
async def health_check():
    """Health check endpoint for Railway"""
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}


@app.post("/auth/signup", response_model=AuthResponse)
async def signup(request: SignupRequest, db: Session = Depends(get_db)):
    """
    Create a new user account
    """
    try:
        # Check if user already exists
        existing_user = db.query(User).filter(User.email == request.email).first()
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered"
            )
        
        # Create new user
        user_id = str(uuid.uuid4())
        hashed_password = get_password_hash(request.password)
        
        new_user = User(
            id=user_id,
            email=request.email,
            hashed_password=hashed_password,
            name=request.name,
            apple_user_id=None,  # Regular signup, not Apple Sign In
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
        
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        
        # Create access token
        access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_access_token(
            data={"sub": user_id, "email": request.email},
            expires_delta=access_token_expires
        )
        
        print(f"✅ User created: {request.email}")
        
        return AuthResponse(
            access_token=access_token,
            token_type="bearer",
            user_id=user_id,
            email=request.email,
            name=request.name
        )
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Signup error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create account: {str(e)}"
        )


@app.post("/auth/login", response_model=AuthResponse)
async def login(request: LoginRequest, db: Session = Depends(get_db)):
    """
    Login and get access token
    """
    try:
        print(f"🔐 Login attempt for email: {request.email}")
        
        # Find user by email
        user = db.query(User).filter(User.email == request.email).first()
        if not user:
            print(f"❌ Login failed: User not found for email {request.email}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect email or password"
            )
        
        print(f"✅ User found: {user.email}, has password: {bool(user.hashed_password)}")
        
        # Check if user has a password (Apple Sign In users don't have passwords)
        if not user.hashed_password:
            print(f"❌ Login failed: User account uses Apple Sign In")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="This account uses Apple Sign In. Please sign in with Apple."
            )
        
        # Verify password
        try:
            print(f"🔐 Verifying password...")
            password_valid = verify_password(request.password, user.hashed_password)
            print(f"🔐 Password valid: {password_valid}")
        except Exception as verify_error:
            print(f"❌ Password verification error: {verify_error}")
            import traceback
            traceback.print_exc()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Password verification failed: {str(verify_error)}"
            )
        
        if not password_valid:
            print(f"❌ Login failed: Invalid password for email {request.email}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect email or password"
            )
        
        # Create access token
        try:
            access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
            access_token = create_access_token(
                data={"sub": user.id, "email": user.email or ""},
                expires_delta=access_token_expires
            )
            print(f"✅ Access token created")
        except Exception as token_error:
            print(f"❌ Token creation error: {token_error}")
            import traceback
            traceback.print_exc()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Token creation failed: {str(token_error)}"
            )
        
        print(f"✅ User logged in: {user.email}")
        
        return AuthResponse(
            access_token=access_token,
            token_type="bearer",
            user_id=user.id,
            email=user.email or "",
            name=user.name
        )
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Login error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Login failed: {str(e)}"
        )


@app.post("/auth/apple", response_model=AuthResponse)
async def apple_signin(request: AppleSignInRequest, db: Session = Depends(get_db)):
    """
    Apple Sign In - create or authenticate user with Apple ID
    """
    try:
        # Verify identity token (basic verification - in production, verify with Apple's servers)
        # For now, we'll trust the token from the client
        # TODO: Add proper Apple identity token verification
        
        # Check if user already exists by apple_user_id
        existing_user = db.query(User).filter(User.apple_user_id == request.user_identifier).first()
        
        if existing_user:
            # User exists, update email/name if provided (Apple only provides these on first sign-in)
            if request.email and not existing_user.email:
                existing_user.email = request.email
            if request.name and not existing_user.name:
                existing_user.name = request.name
            existing_user.updated_at = datetime.utcnow()
            db.commit()
            db.refresh(existing_user)
            
            # Create access token
            access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
            access_token = create_access_token(
                data={"sub": existing_user.id, "email": existing_user.email or ""},
                expires_delta=access_token_expires
            )
            
            print(f"✅ Apple Sign In successful (existing user): {existing_user.id}")
            
            return AuthResponse(
                access_token=access_token,
                token_type="bearer",
                user_id=existing_user.id,
                email=existing_user.email or "",
                name=existing_user.name
            )
        else:
            # New user - create account
            user_id = str(uuid.uuid4())
            
            new_user = User(
                id=user_id,
                email=request.email,  # May be None if Apple didn't provide it
                hashed_password=None,  # Apple users don't have passwords
                name=request.name,
                apple_user_id=request.user_identifier,
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow()
            )
            
            db.add(new_user)
            db.commit()
            db.refresh(new_user)
            
            # Create access token
            access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
            access_token = create_access_token(
                data={"sub": user_id, "email": request.email or ""},
                expires_delta=access_token_expires
            )
            
            print(f"✅ Apple Sign In successful (new user): {user_id}")
            
            return AuthResponse(
                access_token=access_token,
                token_type="bearer",
                user_id=user_id,
                email=request.email or "",
                name=request.name
            )
    except Exception as e:
        print(f"❌ Apple Sign In error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Apple Sign In failed: {str(e)}"
        )


@app.get("/auth/me", response_model=UserResponse)
async def get_current_user_info(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """
    Get current user information
    """
    user = db.query(User).filter(User.id == current_user["user_id"]).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    return UserResponse(
        user_id=user.id,
        email=user.email or "",
        name=user.name,
        created_at=user.created_at
    )


@app.post("/feedback", response_model=FeedbackResponse)
async def submit_feedback(request: FeedbackRequest, db: Session = Depends(get_db)):
    """Record user feedback about AI insights"""
    feedback_id = str(uuid.uuid4())
    try:
        citations_json = json.dumps(request.citations or [])
        diagnoses_json = json.dumps(request.diagnoses) if request.diagnoses else None
        pressure_alert = request.pressure_alert or {}
        pressure_trigger_time = None
        if pressure_alert and isinstance(pressure_alert, dict):
            trigger_time_str = pressure_alert.get("trigger_time")
            if trigger_time_str:
                try:
                    pressure_trigger_time = datetime.fromisoformat(trigger_time_str.replace('Z', '+00:00'))
                except ValueError:
                    pressure_trigger_time = None

        feedback_entry = InsightFeedback(
            id=feedback_id,
            analysis_id=request.analysis_id,
            analysis_hash=request.analysis_hash,
            user_id=request.user_id,
            was_helpful=request.was_helpful,
            risk=request.risk,
            forecast=request.forecast,
            why=request.why,
            support_note=request.support_note,
            citations=citations_json if citations_json != "[]" else None,
            diagnoses=diagnoses_json,
            location=request.location,
            app_version=request.app_version,
            pressure_alert_level=pressure_alert.get("alert_level") if isinstance(pressure_alert, dict) else None,
            pressure_delta=pressure_alert.get("pressure_delta") if isinstance(pressure_alert, dict) else None,
            pressure_trigger_time=pressure_trigger_time,
            alert_severity_tag=request.alert_severity,
            personalization_score=request.personalization_score,
            personal_anecdote=request.personal_anecdote,
            behavior_prompt=request.behavior_prompt,
            created_at=datetime.utcnow()
        )

        db.add(feedback_entry)
        db.commit()

        print(f"📝 Feedback recorded (helpful={request.was_helpful}, analysis_id={request.analysis_id})")
        return FeedbackResponse(status="success", feedback_id=feedback_id)
    except Exception as e:
        db.rollback()
        print(f"❌ Feedback error: {e}")
        raise HTTPException(status_code=500, detail="Failed to record feedback")


@app.post("/analyze", response_model=InsightResponse)
async def analyze_data(request: CorrelationRequest):
    """
    Analyze symptom and weather data to find correlations and generate AI insights.
    """
    # Initialize variables at the start to avoid "variable not assigned" errors
    pressure_alert = None
    hourly_forecast_data = None
    weekly_forecast_data = None
    weekly_forecast_insight = None
    weekly_insight_sources: List[str] = []
    
    try:
        # Validate input
        if not request.weather:
            raise HTTPException(status_code=400, detail="No weather data provided")
        
        # Convert payloads to internal models
        symptoms, weather_snapshots = convert_payload_to_models(
            request.symptoms or [],
            request.weather
        )
        
        # Calculate correlations (if symptoms provided, otherwise use empty dict)
        correlations = calculate_correlations(symptoms, weather_snapshots) if symptoms else {}
        
        # Generate correlation summary (if symptoms provided, otherwise generic)
        if symptoms:
            correlation_summary = generate_correlation_summary(correlations, symptoms)
        else:
            # For weather-only insights, create a generic summary
            if weather_snapshots:
                latest_weather = weather_snapshots[-1]
                correlation_summary = f"Current weather: {latest_weather.temperature:.1f}°C, {latest_weather.humidity:.0f}% humidity, {latest_weather.pressure:.0f} hPa pressure"
            else:
                correlation_summary = "Weather-based health insights"
        
        # Get user diagnoses if provided
        user_diagnoses = request.diagnoses or []
        if user_diagnoses:
            print(f"🏥 User diagnoses: {', '.join(user_diagnoses)}")
        
        # Determine search query - use diagnoses if available, otherwise use generic terms
        if user_diagnoses:
            # Use first diagnosis as primary search term, combine others
            primary_diagnosis = user_diagnoses[0].lower()
            search_query_symptom = primary_diagnosis
            if len(user_diagnoses) > 1:
                # Add other diagnoses to the query
                other_diagnoses = " OR ".join([d.lower() for d in user_diagnoses[1:]])
                search_query_symptom = f"({primary_diagnosis} OR {other_diagnoses})"
            print(f"🔍 Enhanced search query with diagnoses: '{search_query_symptom}'")
        else:
            # If no diagnoses, use generic health-related terms
            search_query_symptom = "health symptoms"
            print(f"🔍 Using generic search query: '{search_query_symptom}'")
        
        # Get strongest weather factor (use pressure as default if no correlations)
        if correlations:
            strongest_factor = max(correlations.items(), key=lambda x: abs(x[1]))[0]
        else:
            # Default to pressure if no symptoms/correlations
            strongest_factor = "pressure"
        
        # Map weather factor to search terms
        weather_search_terms = {
            "temperature": "temperature",
            "humidity": "humidity",
            "pressure": "barometric pressure",
            "wind": "wind speed"
        }
        weather_search_term = weather_search_terms.get(strongest_factor, strongest_factor)
        
        # Search for live papers (non-blocking)
        papers = []
        citations = []
        try:
            print(f"\n🔍 Searching papers for: '{search_query_symptom}' AND '{weather_search_term}'")
            papers = search_papers(search_query_symptom, weather_search_term, max_results=3)
            print(f"📊 Paper search returned: {len(papers)} papers")
            if papers:
                print(f"✅ Found {len(papers)} papers from EuropePMC:")
                for i, paper in enumerate(papers, 1):
                    title = paper.get("title", "No title")[:60]
                    source = paper.get("source", "Unknown")
                    print(f"   {i}. {title}... [Source: {source}]")
                citations = [paper.get("source", paper.get("title", "Unknown")) for paper in papers]
                # Filter out "Unknown" sources
                citations = [c for c in citations if c and c != "Unknown"]
                print(f"📚 Citations to return: {citations}")
            else:
                print("⚠️  No papers found from EuropePMC, will use fallback")
        except Exception as e:
            print(f"❌ Paper search failed: {e}")
            import traceback
            traceback.print_exc()
            papers = []
        
        # Calculate pressure trend from weather snapshots
        pressure_trend = None
        if len(weather_snapshots) >= 2:
            recent_pressures = [w.pressure for w in weather_snapshots[-3:]]  # Last 3 readings
            if len(recent_pressures) >= 2:
                pressure_change = recent_pressures[-1] - recent_pressures[0]
                if pressure_change < -5:
                    pressure_trend = "dropping quickly"
                elif pressure_change < -2:
                    pressure_trend = "dropping"
                elif pressure_change > 5:
                    pressure_trend = "rising quickly"
                elif pressure_change > 2:
                    pressure_trend = "rising"
                else:
                    pressure_trend = "stable"
        
        # Build current weather dict from latest snapshot
        latest_weather = weather_snapshots[-1] if weather_snapshots else None
        current_weather = {
            "pressure": latest_weather.pressure if latest_weather else 1013,
            "humidity": latest_weather.humidity if latest_weather else 50,
            "temperature": latest_weather.temperature if latest_weather else 20,
            "wind": latest_weather.wind if latest_weather else 0,
            "condition": "Unknown"  # Condition not stored in WeatherSnapshot
        }
        
        # Prepare hourly forecast data for AI
        if request.hourly_forecast and len(request.hourly_forecast) > 0:
            hourly_forecast_data = []
            for hour_payload in request.hourly_forecast:
                try:
                    hour_timestamp = datetime.fromisoformat(hour_payload.timestamp.replace('Z', '+00:00'))
                    hourly_forecast_data.append({
                        "timestamp": hour_payload.timestamp,
                        "temperature": hour_payload.temperature,
                        "humidity": hour_payload.humidity,
                        "pressure": hour_payload.pressure,
                        "wind": hour_payload.wind
                    })
                except (ValueError, AttributeError):
                    # Skip invalid timestamps
                    continue
            
            if hourly_forecast_data:
                print(f"📊 Prepared {len(hourly_forecast_data)} hourly forecast points for AI analysis")
                
                # Detect upcoming pressure changes for alerts
                try:
                    pressure_alert = get_upcoming_pressure_change(
                        forecast_entries=hourly_forecast_data,
                        current_time=datetime.utcnow(),
                        diagnoses=user_diagnoses
                    )
                    if pressure_alert:
                        print(f"⚠️  Pressure alert detected: {pressure_alert}")
                except Exception as e:
                    print(f"❌ Pressure alert detection failed: {e}")
                    pressure_alert = None

        # Generate flare risk assessment
        print(f"🤖 Generating flare risk assessment with {len(papers)} papers...")
        print(f"📄 Papers data: {[p.get('source', 'Unknown') for p in papers]}")
        
        try:
            risk, forecast, why, ai_message, paper_citations, support_note, alert_severity, personalization_score, personal_anecdote, behavior_prompt = generate_flare_risk_assessment(
                current_weather=current_weather,
                pressure_trend=pressure_trend,
                weather_factor=strongest_factor,
                papers=papers,
                user_diagnoses=user_diagnoses,
                location=None,  # Could extract from request if available
                hourly_forecast=hourly_forecast_data
            )
            
            print(f"📊 Flare Risk: {risk}")
            print(f"📝 Forecast: {forecast}")
            print(f"📚 Citations: {paper_citations}")
        except Exception as e:
            print(f"❌ Error generating flare risk assessment: {e}")
            import traceback
            traceback.print_exc()
            # Fallback to better pool forecasts instead of generic message
            # Use the helper functions (already imported at top of file)
            try:
                severity_label, signed_delta, direction = _analyze_pressure_window(hourly_forecast_data or [], current_weather)
                risk = "MODERATE"
                forecast = _choose_forecast("MODERATE", severity_label)
                why = "Weather patterns are being analyzed. Please check back in a moment for a detailed forecast."
                ai_message = f"{forecast} {why}"
                alert_severity = severity_label
            except Exception as fallback_error:
                print(f"❌ Fallback also failed: {fallback_error}")
                # Ultimate fallback
                risk = "MODERATE"
                forecast = "Conditions appear stable—today might offer you a little space."
                why = "Weather patterns are being analyzed. Please check back in a moment for a detailed forecast."
                ai_message = f"{forecast} {why}"
                alert_severity = "low"
            paper_citations = []
            support_note = None
            personalization_score = 1
            personal_anecdote = None
            behavior_prompt = None
        
        # Use citations from AI function (they're already formatted)
        citations = paper_citations if paper_citations else citations
        
        # Prepare weekly forecast data for AI
        if request.weekly_forecast and len(request.weekly_forecast) > 0:
            weekly_forecast_data = []
            for day_payload in request.weekly_forecast:
                try:
                    day_timestamp = datetime.fromisoformat(day_payload.timestamp.replace('Z', '+00:00'))
                    weekly_forecast_data.append({
                        "timestamp": day_payload.timestamp,
                        "temperature": day_payload.temperature,
                        "humidity": day_payload.humidity,
                        "pressure": day_payload.pressure,
                        "wind": day_payload.wind
                    })
                except (ValueError, AttributeError):
                    # Skip invalid timestamps
                    continue
            
            if weekly_forecast_data:
                print(f"📊 Prepared {len(weekly_forecast_data)} daily forecast points for weekly insight")
                # Generate weekly forecast insight
                try:
                    weekly_forecast_insight_text, weekly_insight_sources = generate_weekly_forecast_insight(
                        weekly_forecast=weekly_forecast_data,
                        user_diagnoses=user_diagnoses,
                        location=None  # Could extract from request if available
                    )
                    weekly_forecast_insight = weekly_forecast_insight_text
                    print(f"✅ Generated weekly forecast insight")
                except Exception as e:
                    print(f"❌ Error generating weekly forecast insight: {e}")
                    import traceback
                    traceback.print_exc()
                    weekly_forecast_insight = None
                    weekly_insight_sources = []
        
        # Prepare response
        response = InsightResponse(
            correlation_summary=correlation_summary,
            strongest_factors=correlations,
            ai_message=ai_message,
            citations=citations,
            risk=risk,
            forecast=forecast,
            why=why,
            weekly_forecast_insight=weekly_forecast_insight,
            weekly_insight_sources=weekly_insight_sources,
            support_note=support_note,
            pressure_alert=pressure_alert,
            alert_severity=alert_severity,
            personalization_score=personalization_score,
            personal_anecdote=personal_anecdote,
            behavior_prompt=behavior_prompt
        )
        
        return response
        
    except HTTPException:
        raise
    except Exception as e:
        # Log the error for debugging
        print(f"Error in analyze endpoint: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")
