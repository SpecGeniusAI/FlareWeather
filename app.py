from fastapi import FastAPI, HTTPException, Depends, status, Header, Query, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime, timedelta
from typing import List, Tuple, Optional, Dict, Any
import logging
from sqlalchemy.orm import Session
from sqlalchemy import func
import uuid
import json
import random
import os

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
        ForgotPasswordRequest,
        ForgotPasswordResponse,
        ResetPasswordRequest,
        ResetPasswordResponse,
        AuthResponse,
        UserResponse,
        FeedbackRequest,
        FeedbackResponse,
        GrantFreeAccessRequest,
        RevokeFreeAccessRequest,
        FreeAccessResponse,
        AccessStatusResponse
    )
    from logic import calculate_correlations, generate_correlation_summary, get_upcoming_pressure_change
    from ai import generate_insight_with_papers, generate_flare_risk_assessment, generate_weekly_forecast_insight, _choose_forecast, _analyze_pressure_window
    from rag.query import query_rag
    from paper_search import search_papers, format_papers_for_prompt
    from database import get_db, init_db, User, InsightFeedback, PasswordReset
    from access_utils import has_active_access, get_access_status
    from mailgun_service import send_password_reset_email
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

logger = logging.getLogger("flareweather.app")

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


def generate_reset_code() -> str:
    """Generate a random 6-digit numeric code."""
    return f"{random.randint(0, 999999):06d}"


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


@app.post("/test-email")
async def test_email(email: str, auth_token: Optional[str] = None):
    """
    Test endpoint to verify Mailgun email sending (for debugging only).
    Should be secured with authentication in production or removed.
    """
    # Basic protection: only allow in development or with auth token
    # TODO: Remove this endpoint before production or add proper authentication
    import os
    if os.getenv("ENVIRONMENT") == "production" and not auth_token:
        raise HTTPException(status_code=403, detail="Test endpoint disabled in production")
    
    try:
        from mailgun_service import send_password_reset_email
        test_code = "123456"
        print(f"🧪 Testing email send to {email}")
        await send_password_reset_email(email, test_code)
        return {"status": "success", "message": f"Test email sent to {email}"}
    except Exception as e:
        print(f"❌ Test email failed: {e}")
        import traceback
        traceback.print_exc()
        return {"status": "error", "message": str(e)}


@app.post("/auth/signup", response_model=AuthResponse)
async def signup(request: SignupRequest, db: Session = Depends(get_db)):
    """
    Create a new user account
    """
    try:
        normalized_email = (request.email or "").strip().lower()
        if not normalized_email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email is required"
            )
        # Check if user already exists
        existing_user = (
            db.query(User)
            .filter(func.lower(User.email) == normalized_email)
            .first()
        )
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
            email=normalized_email,
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
            email=normalized_email,
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
        normalized_email = (request.email or "").strip().lower()
        if not normalized_email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email is required"
            )
        print(f"🔐 Login attempt for email: {normalized_email}")
        
        # Find user by email
        user = (
            db.query(User)
            .filter(func.lower(User.email) == normalized_email)
            .first()
        )
        if not user:
            print(f"❌ Login failed: User not found for email {normalized_email}")
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
            email=user.email or normalized_email,
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
    Get current user information including access status
    """
    user = db.query(User).filter(User.id == current_user["user_id"]).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Get access status
    access_status = get_access_status(db, user.id)
    
    # Set logout message if access is required
    logout_message = None
    if not access_status["has_access"]:
        logout_message = "Logout to see basic insights"
    
    # Determine if access expired (had free access but it's now expired)
    access_expired = access_status["access_type"] == "free" and not access_status["has_access"]
    
    return UserResponse(
        user_id=user.id,
        email=user.email or "",
        name=user.name,
        created_at=user.created_at,
        has_access=access_status["has_access"],
        access_type=access_status["access_type"],
        access_expires_at=access_status["expires_at"],
        access_required=not access_status["has_access"],  # True if access is required (user doesn't have it)
        access_expired=access_expired,
        logout_message=logout_message
    )


@app.delete("/auth/delete")
async def delete_account(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """
    Permanently delete the current user's account.
    """
    try:
        user = db.query(User).filter(User.id == current_user["user_id"]).first()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        db.delete(user)
        db.commit()
        return {"status": "deleted"}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error deleting account: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete account"
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


@app.get("/user/access-status", response_model=AccessStatusResponse)
async def get_user_access_status(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get current user's access status.
    Returns detailed access information for the iOS app to determine if popup should be shown.
    """
    user_id = current_user["user_id"]
    access_status = get_access_status(db, user_id)
    
    user = db.query(User).filter(User.id == user_id).first()
    email = user.email if user else None
    
    # Set logout message if access is required
    logout_message = None
    if not access_status["has_access"]:
        logout_message = "Logout to see basic insights"
    
    return AccessStatusResponse(
        user_id=user_id,
        email=email,
        has_access=access_status["has_access"],
        access_type=access_status["access_type"],
        expires_at=access_status["expires_at"],
        is_expired=access_status["is_expired"],
        logout_message=logout_message
    )


@app.put("/user/profile")
async def update_user_profile(
    user_id: str,
    diagnoses: Optional[List[str]] = None,
    sensitivities: Optional[List[str]] = None,
    db: Session = Depends(get_db)
):
    """
    Update user profile with diagnoses and sensitivities.
    When diagnoses are provided, search for and store relevant papers.
    This makes future insight generation much faster by avoiding paper search.
    """
    try:
        # Get user
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Update diagnoses if provided
        if diagnoses is not None:
            diagnoses_json = json.dumps(diagnoses) if diagnoses else None
            user.diagnoses = diagnoses_json
            
            # If diagnoses changed, search for and store papers
            if diagnoses and len(diagnoses) > 0:
                print(f"🔍 Searching papers for user {user_id} with diagnoses: {', '.join(diagnoses)}")
                
                # Build search query from diagnoses
                primary_diagnosis = diagnoses[0].lower()
                if len(diagnoses) > 1:
                    other_diagnoses = " OR ".join([d.lower() for d in diagnoses[1:]])
                    search_query = f"({primary_diagnosis} OR {other_diagnoses})"
                else:
                    search_query = primary_diagnosis
                
                # Search for papers (use pressure as default weather term since it's most relevant)
                try:
                    papers = search_papers(search_query, "barometric pressure", max_results=5)
                    print(f"📊 Found {len(papers)} papers for user {user_id}")
                    
                    # Store papers as JSON
                    if papers:
                        papers_json = json.dumps(papers)
                        user.stored_papers = papers_json
                        user.papers_updated_at = datetime.utcnow()
                        print(f"✅ Stored {len(papers)} papers for user {user_id}")
                    else:
                        # Store empty array if no papers found
                        user.stored_papers = json.dumps([])
                        user.papers_updated_at = datetime.utcnow()
                        print(f"⚠️  No papers found for user {user_id}, stored empty array")
                except Exception as e:
                    print(f"❌ Error searching papers for user {user_id}: {e}")
                    import traceback
                    traceback.print_exc()
                    # Don't fail the request - just log the error
                    # User can still use the app, papers will be searched on-demand
        
        # Update updated_at timestamp
        user.updated_at = datetime.utcnow()
        
        db.commit()
        
        return {"status": "success", "message": "User profile updated"}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error updating user profile: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Failed to update user profile: {str(e)}")


@app.post("/auth/forgot-password", response_model=ForgotPasswordResponse)
async def forgot_password(request: ForgotPasswordRequest, db: Session = Depends(get_db)):
    """
    Generate a reset code and send it via email. Always respond with a generic message.
    """
    normalized_email = request.email.lower()
    generic_message = "If an account exists, we’ve sent a reset code."
    try:
        user = (
            db.query(User)
            .filter(func.lower(User.email) == normalized_email)
            .first()
        )
        if not user:
            logger.info("Password reset requested for unknown email: %s", normalized_email)
            return ForgotPasswordResponse(message=generic_message)

        code = generate_reset_code()
        code_hash = get_password_hash(code)
        reset_entry = PasswordReset(
            user_id=user.id,
            email=normalized_email,
            code_hash=code_hash,
            expires_at=datetime.utcnow() + timedelta(minutes=30)
        )
        db.add(reset_entry)
        db.commit()

        try:
            print(f"📧 Sending password reset email to {normalized_email} with code: {code}")
            await send_password_reset_email(normalized_email, code)
            print(f"✅ Password reset email sent successfully to {normalized_email}")
        except Exception as email_error:
            # Log but do not leak to client
            logger.error("Password reset email failed for %s: %s", normalized_email, email_error)
            print(f"❌ Password reset email failed for {normalized_email}: {email_error}")
            import traceback
            traceback.print_exc()
            # TODO: Consider retry/backoff for transient email errors.

        logger.info("Password reset code created for %s", normalized_email)
        return ForgotPasswordResponse(message=generic_message)
    except Exception as e:
        db.rollback()
        logger.error("Password reset flow failed: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to process password reset request"
        )


@app.post("/auth/reset-password", response_model=ResetPasswordResponse)
async def reset_password(request: ResetPasswordRequest, db: Session = Depends(get_db)):
    """
    Validate a reset code and update the user's password.
    """
    normalized_email = request.email.lower()
    try:
        reset_entry = (
            db.query(PasswordReset)
            .filter(PasswordReset.email == normalized_email)
            .filter(PasswordReset.used_at.is_(None))
            .filter(PasswordReset.expires_at > datetime.utcnow())
            .order_by(PasswordReset.created_at.desc())
            .first()
        )
        if not reset_entry:
            raise HTTPException(status_code=400, detail="Invalid or expired code.")

        if not verify_password(request.code, reset_entry.code_hash):
            raise HTTPException(status_code=400, detail="Invalid or expired code.")

        user = (
            db.query(User)
            .filter(func.lower(User.email) == normalized_email)
            .first()
        )
        if not user:
            raise HTTPException(status_code=400, detail="Invalid or expired code.")

        user.hashed_password = get_password_hash(request.new_password)
        user.updated_at = datetime.utcnow()
        reset_entry.used_at = datetime.utcnow()

        # TODO: Revoke outstanding JWTs/session tokens once token store is implemented.

        db.commit()
        logger.info("Password reset completed for %s", normalized_email)
        return ResetPasswordResponse(success=True)
    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        logger.error("Reset password error for %s: %s", normalized_email, e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to reset password"
        )


@app.post("/analyze", response_model=InsightResponse)
async def analyze_data(request: CorrelationRequest, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
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
        
        # Get user sensitivities/triggers if provided
        user_sensitivities = request.sensitivities or []
        if user_sensitivities:
            print(f"🎯 User sensitivities: {', '.join(user_sensitivities)}")
        
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
        # OPTIMIZATION: Skip paper loading entirely when skip_weekly=True for fastest daily insight
        papers = []
        citations = []
        
        # Skip paper loading if skip_weekly=True (daily insights don't need papers for speed)
        if not request.skip_weekly:
            # First, try to get stored papers from user profile (if user_id provided)
            stored_papers = None
            if request.user_id:
                try:
                    user = db.query(User).filter(User.id == request.user_id).first()
                    if user and user.stored_papers:
                        stored_papers = json.loads(user.stored_papers)
                        print(f"📦 Using {len(stored_papers)} stored papers from user profile")
                except Exception as e:
                    print(f"⚠️  Error loading stored papers: {e}")
                    stored_papers = None
            
            # Only do live paper search if:
            # 1. No stored papers available AND
            # 2. (Weekly forecast is provided OR user has diagnoses)
            should_search_papers = (
                stored_papers is None and
                ((request.weekly_forecast and len(request.weekly_forecast) > 0) or (user_diagnoses and len(user_diagnoses) > 0))
            )
            
            if stored_papers:
            # Use stored papers - this is FAST!
            papers = stored_papers
            # Format citations from stored papers
            enhanced_citations = []
            for paper in papers:
                title = paper.get("title", "").strip()
                journal = paper.get("journal", "").strip()
                year = paper.get("year", "").strip()
                source_id = paper.get("source", "").strip()
                
                if not title:
                    if source_id:
                        enhanced_citations.append(source_id)
                    continue
                
                citation_parts = [title]
                if journal and journal != "Unknown journal":
                    if year and year != "Unknown":
                        citation_parts.append(f"({journal}, {year})")
                    else:
                        citation_parts.append(f"({journal})")
                elif year and year != "Unknown":
                    citation_parts.append(f"({year})")
                
                enhanced_citation = " ".join(citation_parts)
                enhanced_citations.append(enhanced_citation)
            
            citations = enhanced_citations if enhanced_citations else [
                paper.get("source", paper.get("title", "Unknown")) 
                for paper in papers 
                if paper.get("source") or paper.get("title")
            ]
                citations = [c for c in citations if c and c != "Unknown"]
                print(f"📚 Using stored citations: {citations}")
            elif should_search_papers:
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
                    
                    # Enhanced citation formatting: "Title (Journal, Year)" for better credibility
                    enhanced_citations = []
                    for paper in papers:
                        title = paper.get("title", "").strip()
                        journal = paper.get("journal", "").strip()
                        year = paper.get("year", "").strip()
                        source_id = paper.get("source", "").strip()
                        
                        if not title:
                            if source_id:
                                enhanced_citations.append(source_id)
                            continue
                        
                        # Build enhanced citation
                        citation_parts = [title]
                        
                        # Add journal and year if available
                        if journal and journal != "Unknown journal":
                            if year and year != "Unknown":
                                citation_parts.append(f"({journal}, {year})")
                            else:
                                citation_parts.append(f"({journal})")
                        elif year and year != "Unknown":
                            citation_parts.append(f"({year})")
                        
                        # Join parts with space
                        enhanced_citation = " ".join(citation_parts)
                        enhanced_citations.append(enhanced_citation)
                    
                    citations = enhanced_citations if enhanced_citations else [
                        paper.get("source", paper.get("title", "Unknown")) 
                        for paper in papers 
                        if paper.get("source") or paper.get("title")
                    ]
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
            else:
                print("⏭️  Skipping paper search for faster daily insight generation (no weekly forecast or diagnoses)")
        else:
            print("⚡ Skipping paper loading entirely for fastest daily insight (skip_weekly=True)")
        
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

        # OPTIMIZATION: Two-phase response - calculate quick risk/forecast first, then full insight
        # Phase 1: Quick risk/forecast from weather patterns (instant)
        # Phase 2: Full AI insight (8-12 seconds)
        quick_risk = None
        quick_forecast = None
        quick_why = None
        
        # Calculate quick risk/forecast from weather patterns (no AI needed)
        try:
            from logic import get_upcoming_pressure_change
            from ai import _analyze_pressure_window, _choose_forecast
            
            # Quick risk assessment from pressure patterns
            if hourly_forecast_data:
                severity_label, signed_delta, direction = _analyze_pressure_window(hourly_forecast_data, current_weather)
                if severity_label == "sharp":
                    quick_risk = "HIGH"
                elif severity_label == "moderate":
                    quick_risk = "MODERATE"
                else:
                    quick_risk = "LOW"
                
                quick_forecast = _choose_forecast(quick_risk, severity_label)
                if direction == "drops":
                    quick_why = "Pressure is dropping, which may affect sensitive bodies."
                elif direction == "rises":
                    quick_why = "Pressure is rising, which may feel more settled."
                else:
                    quick_why = "Pressure stays steady, which often feels gentler."
            else:
                # Fallback based on current pressure
                pressure = current_weather.get("pressure", 1013)
                if pressure < 1005:
                    quick_risk = "MODERATE"
                    quick_forecast = "Lower pressure today may feel noticeable."
                    quick_why = "Lower pressure can affect sensitive bodies."
                elif pressure > 1020:
                    quick_risk = "LOW"
                    quick_forecast = "Higher pressure today may feel steadier."
                    quick_why = "Higher pressure often feels more stable."
                else:
                    quick_risk = "LOW"
                    quick_forecast = "Pressure looks steady today."
                    quick_why = "Stable pressure often feels gentler."
            
            print(f"⚡ Quick risk assessment: {quick_risk} - {quick_forecast}")
        except Exception as e:
            print(f"⚠️  Quick risk assessment failed: {e}")
            quick_risk = "MODERATE"
            quick_forecast = "Weather patterns are being analyzed."
            quick_why = "Analyzing current conditions..."
        
        # Generate full flare risk assessment with AI
        if not request.skip_weekly:
            print(f"🤖 Generating full AI insight with {len(papers)} papers...")
            print(f"📄 Papers data: {[p.get('source', 'Unknown') for p in papers]}")
        else:
            print(f"⚡ Generating fast daily insight (papers skipped for speed)...")
        
        try:
            risk, forecast, why, ai_message, paper_citations, support_note, alert_severity, personalization_score, personal_anecdote, behavior_prompt = generate_flare_risk_assessment(
                current_weather=current_weather,
                pressure_trend=pressure_trend,
                weather_factor=strongest_factor,
                papers=papers,
                user_diagnoses=user_diagnoses,
                user_sensitivities=user_sensitivities,
                location=None,  # Could extract from request if available
                hourly_forecast=hourly_forecast_data
            )
            
            # Use quick values as fallback if AI didn't return them
            if not risk:
                risk = quick_risk or "MODERATE"
            if not forecast:
                forecast = quick_forecast or "Weather patterns are being analyzed."
            if not why:
                why = quick_why or "Analyzing current conditions..."
            
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
        
        # Prepare weekly forecast data for AI (skip if skip_weekly=True for faster response)
        if not request.skip_weekly and request.weekly_forecast and len(request.weekly_forecast) > 0:
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
                    # Pass today's risk level, current weather, and pressure trend to weekly forecast
                    today_risk_context = f"Today's flare risk is {risk}." if risk else None
                    today_pressure = current_weather.get("pressure") if current_weather else None
                    today_temp = current_weather.get("temperature") if current_weather else None
                    today_humidity = current_weather.get("humidity") if current_weather else None
                    
                    # Calculate tomorrow's expected pressure based on hourly forecast (pressure drops later today affect tomorrow)
                    tomorrow_expected_pressure = None
                    if hourly_forecast_data and len(hourly_forecast_data) > 0:
                        # Get pressure from the last few hours of today / first hours of tomorrow
                        # This accounts for pressure drops happening later today
                        future_pressures = [h.get("pressure") for h in hourly_forecast_data[-12:] if h.get("pressure")]
                        if future_pressures:
                            # Use the pressure at the end of today/start of tomorrow
                            tomorrow_expected_pressure = future_pressures[-1]
                            print(f"📊 Weekly forecast: Tomorrow's expected pressure from hourly forecast: {tomorrow_expected_pressure:.1f}hPa")
                    
                    weekly_forecast_insight_text, weekly_insight_sources = generate_weekly_forecast_insight(
                        weekly_forecast=weekly_forecast_data,
                        user_diagnoses=user_diagnoses,
                        user_sensitivities=user_sensitivities,
                        location=None,  # Could extract from request if available
                        today_risk_context=today_risk_context,
                        today_pressure=today_pressure,
                        today_temp=today_temp,
                        today_humidity=today_humidity,
                        pressure_trend=pressure_trend,
                        tomorrow_expected_pressure=tomorrow_expected_pressure
                    )
                    weekly_forecast_insight = weekly_forecast_insight_text
                    print(f"✅ Generated weekly forecast insight")
                except Exception as e:
                    print(f"❌ Error generating weekly forecast insight: {e}")
                    import traceback
                    traceback.print_exc()
                    weekly_forecast_insight = None
                    weekly_insight_sources = []
        else:
            if request.skip_weekly:
                print("⏭️  Skipping weekly forecast generation for faster daily insight response")
            else:
                print("⏭️  No weekly forecast data provided, skipping weekly insight generation")
        
        # Check user access status if user_id is provided
        access_required = None
        access_expired = None
        logout_message = None
        if request.user_id:
            access_status = get_access_status(db, request.user_id)
            access_required = not access_status["has_access"]
            # Set logout message if access is required
            if not access_status["has_access"]:
                logout_message = "Logout to see basic insights"
            # Check if free access expired (user had free access but it's now expired)
            if access_status["access_type"] == "free" and access_status["is_expired"]:
                access_expired = True
            elif access_status["access_type"] == "none" and not access_status["has_access"]:
                # Check if user had free access that expired
                user = db.query(User).filter(User.id == request.user_id).first()
                if user and user.free_access_enabled and user.free_access_expires_at:
                    from datetime import timezone as tz
                    now = datetime.now(tz.utc)
                    expires_at = user.free_access_expires_at
                    if isinstance(expires_at, datetime):
                        expires_at = expires_at.replace(tzinfo=tz.utc)
                        if expires_at <= now:
                            access_expired = True
        
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
            behavior_prompt=behavior_prompt,
            access_required=access_required,
            access_expired=access_expired,
            logout_message=logout_message
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


# ============================================================================
# Admin endpoints for free access management
# ============================================================================

def verify_admin_key(admin_key: Optional[str] = None) -> bool:
    """
    Verify admin API key from environment variable.
    Set ADMIN_API_KEY environment variable to secure these endpoints.
    If not set, these endpoints will be accessible (for development only).
    """
    expected_key = os.getenv("ADMIN_API_KEY")
    if not expected_key:
        print("⚠️  WARNING: ADMIN_API_KEY not set - admin endpoints are open!")
        return True  # Allow access if no key is set (development mode)
    return admin_key == expected_key


@app.post("/admin/grant-free-access", response_model=FreeAccessResponse)
async def grant_free_access(
    request: GrantFreeAccessRequest,
    admin_key_header: Optional[str] = Header(None, alias="X-Admin-Key"),
    admin_key: Optional[str] = Query(None, description="Admin API key (alternative to header)"),
    db: Session = Depends(get_db)
):
    """
    Grant free access to a user by email or user_id.
    Requires ADMIN_API_KEY header (X-Admin-Key) or query parameter.
    
    Args:
        request: GrantFreeAccessRequest with user_identifier and expiration
        admin_key_header: Admin API key from header
        admin_key: Admin API key from query parameter (alternative)
        db: Database session
    """
    # Use header key if provided, otherwise use query param
    key = admin_key_header or admin_key
    
    # Verify admin key
    if not verify_admin_key(key):
        raise HTTPException(status_code=401, detail="Invalid admin API key")
    
    try:
        # Find user by email or user_id
        user = None
        if "@" in request.user_identifier:
            # Assume it's an email
            user = db.query(User).filter(User.email == request.user_identifier).first()
        else:
            # Assume it's a user_id
            user = db.query(User).filter(User.id == request.user_identifier).first()
        
        if not user:
            raise HTTPException(status_code=404, detail=f"User not found: {request.user_identifier}")
        
        # Calculate expiration date
        expires_at = None
        if request.expires_at:
            try:
                expires_at = datetime.fromisoformat(request.expires_at.replace("Z", "+00:00"))
            except ValueError:
                raise HTTPException(status_code=400, detail="Invalid expires_at format. Use ISO format.")
        elif request.days:
            expires_at = datetime.utcnow() + timedelta(days=request.days)
        # If neither expires_at nor days provided, access never expires (None)
        
        # Grant free access
        user.free_access_enabled = True
        user.free_access_expires_at = expires_at
        user.updated_at = datetime.utcnow()
        
        db.commit()
        db.refresh(user)
        
        expires_at_str = expires_at.isoformat() if expires_at else None
        
        print(f"✅ Granted free access to user {user.id} ({user.email}) - expires: {expires_at_str or 'never'}")
        
        return FreeAccessResponse(
            success=True,
            message=f"Free access granted successfully. Expires: {expires_at_str or 'never'}",
            user_id=user.id,
            email=user.email,
            free_access_enabled=True,
            free_access_expires_at=expires_at_str
        )
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error granting free access: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Failed to grant free access: {str(e)}")


@app.post("/admin/revoke-free-access", response_model=FreeAccessResponse)
async def revoke_free_access(
    request: RevokeFreeAccessRequest,
    admin_key_header: Optional[str] = Header(None, alias="X-Admin-Key"),
    admin_key: Optional[str] = Query(None, description="Admin API key (alternative to header)"),
    db: Session = Depends(get_db)
):
    """
    Revoke free access from a user by email or user_id.
    Requires ADMIN_API_KEY header (X-Admin-Key) or query parameter.
    
    Args:
        request: RevokeFreeAccessRequest with user_identifier
        admin_key_header: Admin API key from header
        admin_key: Admin API key from query parameter (alternative)
        db: Database session
    """
    # Use header key if provided, otherwise use query param
    key = admin_key_header or admin_key
    
    # Verify admin key
    if not verify_admin_key(key):
        raise HTTPException(status_code=401, detail="Invalid admin API key")
    
    try:
        # Find user by email or user_id
        user = None
        if "@" in request.user_identifier:
            # Assume it's an email
            user = db.query(User).filter(User.email == request.user_identifier).first()
        else:
            # Assume it's a user_id
            user = db.query(User).filter(User.id == request.user_identifier).first()
        
        if not user:
            raise HTTPException(status_code=404, detail=f"User not found: {request.user_identifier}")
        
        # Revoke free access
        user.free_access_enabled = False
        user.free_access_expires_at = None
        user.updated_at = datetime.utcnow()
        
        db.commit()
        db.refresh(user)
        
        print(f"✅ Revoked free access from user {user.id} ({user.email})")
        
        return FreeAccessResponse(
            success=True,
            message="Free access revoked successfully",
            user_id=user.id,
            email=user.email,
            free_access_enabled=False,
            free_access_expires_at=None
        )
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error revoking free access: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Failed to revoke free access: {str(e)}")


@app.get("/admin/access-status/{user_identifier}", response_model=AccessStatusResponse)
async def get_access_status_endpoint(
    user_identifier: str,
    admin_key_header: Optional[str] = Header(None, alias="X-Admin-Key"),
    admin_key: Optional[str] = Query(None, description="Admin API key (alternative to header)"),
    db: Session = Depends(get_db)
):
    """
    Get access status for a user by email or user_id.
    Requires ADMIN_API_KEY header (X-Admin-Key) or query parameter.
    
    Args:
        user_identifier: User email or user_id
        admin_key_header: Admin API key from header
        admin_key: Admin API key from query parameter (alternative)
        db: Database session
    """
    # Use header key if provided, otherwise use query param
    key = admin_key_header or admin_key
    
    # Verify admin key
    if not verify_admin_key(key):
        raise HTTPException(status_code=401, detail="Invalid admin API key")
    
    try:
        # Find user by email or user_id
        user = None
        if "@" in user_identifier:
            # Assume it's an email
            user = db.query(User).filter(User.email == user_identifier).first()
        else:
            # Assume it's a user_id
            user = db.query(User).filter(User.id == user_identifier).first()
        
        if not user:
            raise HTTPException(status_code=404, detail=f"User not found: {user_identifier}")
        
        # Get access status
        status = get_access_status(db, user.id)
        
        # Set logout message if access is required
        logout_message = None
        if not status["has_access"]:
            logout_message = "Logout to see basic insights"
        
        return AccessStatusResponse(
            user_id=user.id,
            email=user.email,
            has_access=status["has_access"],
            access_type=status["access_type"],
            expires_at=status["expires_at"],
            is_expired=status["is_expired"],
            logout_message=logout_message
        )
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error getting access status: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Failed to get access status: {str(e)}")
