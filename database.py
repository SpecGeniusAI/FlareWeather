"""
Database models and connection for FlareWeather API
"""
from sqlalchemy import create_engine, Column, String, DateTime, Text, Boolean, Float, Integer, Index, Date, JSON
from sqlalchemy.pool import NullPool
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from datetime import datetime
import os
import uuid
from dotenv import load_dotenv

load_dotenv()

DEFAULT_SQLITE_URL = "sqlite:///./flareweather.db"


def _sanitize_database_url(raw_url: str) -> str:
    """Return a valid DATABASE_URL or fallback to SQLite if placeholder values are present."""
    if not raw_url:
        return DEFAULT_SQLITE_URL
    normalized = raw_url.strip()
    placeholder_tokens = ["<user>", "<password>", "<host>", "<port>", "<database>", "<dbname>"]
    if any(token in normalized.lower() for token in placeholder_tokens):
        print("⚠️ DATABASE_URL contains placeholder values. Falling back to local SQLite.")
        return DEFAULT_SQLITE_URL
    return normalized


raw_database_url = os.getenv("DATABASE_URL")
DATABASE_URL = _sanitize_database_url(raw_database_url)


def _create_engine(url: str):
    """Create an engine with graceful fallback to SQLite if the URL is invalid."""
    try:
        if url.startswith(("postgresql://", "postgres://")):
            print("📊 Using PostgreSQL database (production)")
            # Public Railway URL - try prefer (use SSL if available, don't force)
            if ("proxy" in url or "rlwy" in url) and "sslmode=" not in url:
                url = url + ("&" if "?" in url else "?") + "sslmode=prefer"
            # NullPool: no connection reuse - Railway may kill idle pooled connections
            # 10s timeout - fail fast instead of hanging if DB unreachable
            return create_engine(url, poolclass=NullPool, connect_args={"connect_timeout": 10})
        print("📊 Using SQLite database (local development)")
        return create_engine(
            url,
            connect_args={"check_same_thread": False}
        )
    except ValueError as value_error:
        print(f"⚠️ Invalid DATABASE_URL '{url}' ({value_error}). Falling back to SQLite.")
        return create_engine(
            DEFAULT_SQLITE_URL,
            connect_args={"check_same_thread": False}
        )


engine = _create_engine(DATABASE_URL)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


class User(Base):
    """User model"""
    __tablename__ = "users"
    
    id = Column(String, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=True)  # Nullable for Apple Sign In
    hashed_password = Column(String, nullable=True)  # Nullable for Apple Sign In
    name = Column(String, nullable=True)
    apple_user_id = Column(String, unique=True, index=True, nullable=True)  # Apple Sign In identifier
    original_transaction_id = Column(String, unique=True, index=True, nullable=True)
    diagnoses = Column(Text, nullable=True)  # JSON array of user diagnoses
    stored_papers = Column(Text, nullable=True)  # JSON array of papers searched for user's diagnoses
    papers_updated_at = Column(DateTime, nullable=True)  # When papers were last updated
    free_access_enabled = Column(Boolean, default=False, nullable=False)  # Whether user has free access granted
    free_access_expires_at = Column(DateTime, nullable=True)  # When free access expires (None = never expires)
    subscription_status = Column(String, nullable=True)  # Subscription status: "active", "expired", "revoked", "none"
    subscription_plan = Column(String, nullable=True)  # Subscription plan/product_id (e.g., "monthly", "yearly")
    push_notification_token = Column(String, nullable=True)  # APNs device token
    push_notifications_enabled = Column(Boolean, default=True, nullable=False)  # Whether user has notifications enabled
    last_location_latitude = Column(Float, nullable=True)  # User's last known location
    last_location_longitude = Column(Float, nullable=True)
    last_location_name = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class InsightFeedback(Base):
    """Feedback entries for AI insights"""
    __tablename__ = "insight_feedback"

    id = Column(String, primary_key=True, index=True)
    analysis_id = Column(String, index=True, nullable=True)
    analysis_hash = Column(String, nullable=True)
    user_id = Column(String, index=True, nullable=True)
    was_helpful = Column(Boolean, nullable=False)
    risk = Column(String, nullable=True)
    forecast = Column(Text, nullable=True)
    why = Column(Text, nullable=True)
    support_note = Column(Text, nullable=True)
    citations = Column(Text, nullable=True)
    diagnoses = Column(Text, nullable=True)
    location = Column(String, nullable=True)
    app_version = Column(String, nullable=True)
    pressure_alert_level = Column(String, nullable=True)
    pressure_delta = Column(Float, nullable=True)
    pressure_trigger_time = Column(DateTime, nullable=True)
    alert_severity_tag = Column(String, nullable=True)
    personalization_score = Column(Integer, nullable=True)
    personal_anecdote = Column(Text, nullable=True)
    confidence_flag = Column(String, nullable=True)
    behavior_prompt = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class AppStoreNotificationRecord(Base):
    """Raw App Store server notifications for auditing and processing."""
    __tablename__ = "app_store_notifications"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    notification_uuid = Column(String, unique=True, index=True, nullable=False)
    notification_type = Column(String, index=True, nullable=True)
    subtype = Column(String, nullable=True)
    payload = Column(Text, nullable=False)
    signed_payload = Column(Text, nullable=False)
    received_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    processed = Column(Boolean, default=False, nullable=False)


class SubscriptionEntitlement(Base):
    """Entitlement state derived from App Store notifications."""
    __tablename__ = "subscription_entitlements"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    original_transaction_id = Column(String, unique=True, index=True, nullable=False)
    product_id = Column(String, nullable=True)
    status = Column(String, nullable=False, default="unknown")
    expires_at = Column(DateTime, nullable=True)
    revoked_at = Column(DateTime, nullable=True)
    signed_transaction_payload = Column(Text, nullable=True)
    updated_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class PasswordReset(Base):
    """Password reset codes stored for 6-digit flow."""
    __tablename__ = "password_resets"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, nullable=True, index=True)
    email = Column(String, nullable=False)
    code_hash = Column(String, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    used_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (
        Index("ix_password_resets_email", "email"),
        Index("ix_password_resets_code_hash", "code_hash"),
    )


class DailyForecast(Base):
    """Pre-primed daily forecasts for push notifications."""
    __tablename__ = "daily_forecasts"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, nullable=False, index=True)
    forecast_date = Column(Date, nullable=False)  # YYYY-MM-DD
    
    # Location
    location_latitude = Column(Float, nullable=False)
    location_longitude = Column(Float, nullable=False)
    location_name = Column(String, nullable=True)
    
    # Weather data (from WeatherKit - stored as JSON)
    current_weather = Column(JSON, nullable=True)  # Today's current conditions
    hourly_forecast = Column(JSON, nullable=True)  # Next 24 hours
    daily_forecast = Column(JSON, nullable=True)   # Next 7 days (all days)
    
    # Today's daily insight (from AI)
    daily_risk_level = Column(String, nullable=True)  # "LOW", "MODERATE", "HIGH"
    daily_forecast_summary = Column(Text, nullable=True)
    daily_why_explanation = Column(Text, nullable=True)
    daily_insight = Column(JSON, nullable=True)  # Full daily insight object
    daily_comfort_tip = Column(Text, nullable=True)
    
    # Weekly summary insight (from AI)
    weekly_forecast_insight = Column(Text, nullable=True)  # Weekly summary text
    weekly_insight_sources = Column(JSON, nullable=True)  # Sources/citations
    
    # Notification
    notification_sent = Column(Boolean, default=False, nullable=False)
    notification_sent_at = Column(DateTime, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    __table_args__ = (
        Index("ix_daily_forecasts_user_date", "user_id", "forecast_date"),
    )


def get_db():
    """Get database session"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    """Initialize database tables"""
    Base.metadata.create_all(bind=engine)
    
    # Migrate existing database: Add apple_user_id column if it doesn't exist
    from sqlalchemy import text, inspect
    inspector = inspect(engine)
    
    # Check if users table exists
    if 'users' in inspector.get_table_names():
        # Get existing columns
        columns = [col['name'] for col in inspector.get_columns('users')]

        # Add apple_user_id column if it doesn't exist
        if 'apple_user_id' not in columns:
            print("🔄 Migrating database: Adding apple_user_id column...")
            try:
                with engine.begin() as conn:
                    conn.execute(text("ALTER TABLE users ADD COLUMN apple_user_id VARCHAR"))
                print("✅ Migration complete: apple_user_id column added")
            except Exception as e:
                print(f"⚠️  Migration error: {e}")

        # Add original_transaction_id column if it doesn't exist
        if 'original_transaction_id' not in columns:
            print("🔄 Migrating database: Adding original_transaction_id column...")
            try:
                with engine.begin() as conn:
                    conn.execute(text("ALTER TABLE users ADD COLUMN original_transaction_id VARCHAR"))
                print("✅ Migration complete: original_transaction_id column added")
            except Exception as e:
                print(f"⚠️  Migration error: {e}")
        
        # Add diagnoses, stored_papers, and papers_updated_at columns if they don't exist
        if 'diagnoses' not in columns:
            print("🔄 Migrating database: Adding diagnoses column...")
            try:
                with engine.begin() as conn:
                    conn.execute(text("ALTER TABLE users ADD COLUMN diagnoses TEXT"))
                print("✅ Migration complete: diagnoses column added")
            except Exception as e:
                print(f"⚠️  Migration error: {e}")
        
        if 'stored_papers' not in columns:
            print("🔄 Migrating database: Adding stored_papers column...")
            try:
                with engine.begin() as conn:
                    conn.execute(text("ALTER TABLE users ADD COLUMN stored_papers TEXT"))
                print("✅ Migration complete: stored_papers column added")
            except Exception as e:
                print(f"⚠️  Migration error: {e}")
        
        if 'papers_updated_at' not in columns:
            print("🔄 Migrating database: Adding papers_updated_at column...")
            try:
                # Use TIMESTAMP for PostgreSQL, DATETIME for SQLite
                db_type = engine.dialect.name
                with engine.begin() as conn:  # Use begin() for proper transaction handling
                    if db_type == 'postgresql':
                        conn.execute(text("ALTER TABLE users ADD COLUMN papers_updated_at TIMESTAMP"))
                    else:
                        conn.execute(text("ALTER TABLE users ADD COLUMN papers_updated_at DATETIME"))
                print("✅ Migration complete: papers_updated_at column added")
            except Exception as e:
                print(f"⚠️  Migration error: {e}")
                import traceback
                traceback.print_exc()
        
        # Add free_access_enabled column if it doesn't exist
        if 'free_access_enabled' not in columns:
            print("🔄 Migrating database: Adding free_access_enabled column...")
            try:
                db_type = engine.dialect.name
                with engine.begin() as conn:
                    if db_type == 'postgresql':
                        conn.execute(text("ALTER TABLE users ADD COLUMN free_access_enabled BOOLEAN DEFAULT FALSE"))
                    else:
                        conn.execute(text("ALTER TABLE users ADD COLUMN free_access_enabled BOOLEAN DEFAULT 0"))
                print("✅ Migration complete: free_access_enabled column added")
            except Exception as e:
                print(f"⚠️  Migration error: {e}")
        
        # Add free_access_expires_at column if it doesn't exist
        if 'free_access_expires_at' not in columns:
            print("🔄 Migrating database: Adding free_access_expires_at column...")
            try:
                db_type = engine.dialect.name
                with engine.begin() as conn:
                    if db_type == 'postgresql':
                        conn.execute(text("ALTER TABLE users ADD COLUMN free_access_expires_at TIMESTAMP"))
                    else:
                        conn.execute(text("ALTER TABLE users ADD COLUMN free_access_expires_at DATETIME"))
                print("✅ Migration complete: free_access_expires_at column added")
            except Exception as e:
                print(f"⚠️  Migration error: {e}")
        
        # Add subscription_status column if it doesn't exist
        if 'subscription_status' not in columns:
            print("🔄 Migrating database: Adding subscription_status column...")
            try:
                with engine.begin() as conn:
                    conn.execute(text("ALTER TABLE users ADD COLUMN subscription_status VARCHAR"))
                print("✅ Migration complete: subscription_status column added")
            except Exception as e:
                print(f"⚠️  Migration error: {e}")
        
        # Add subscription_plan column if it doesn't exist
        if 'subscription_plan' not in columns:
            print("🔄 Migrating database: Adding subscription_plan column...")
            try:
                with engine.begin() as conn:
                    conn.execute(text("ALTER TABLE users ADD COLUMN subscription_plan VARCHAR"))
                print("✅ Migration complete: subscription_plan column added")
            except Exception as e:
                print(f"⚠️  Migration error: {e}")
        
        # Add push notification columns if they don't exist
        if 'push_notification_token' not in columns:
            print("🔄 Migrating database: Adding push_notification_token column...")
            try:
                with engine.begin() as conn:
                    conn.execute(text("ALTER TABLE users ADD COLUMN push_notification_token VARCHAR"))
                print("✅ Migration complete: push_notification_token column added")
            except Exception as e:
                print(f"⚠️  Migration error: {e}")
        
        if 'push_notifications_enabled' not in columns:
            print("🔄 Migrating database: Adding push_notifications_enabled column...")
            try:
                db_type = engine.dialect.name
                with engine.begin() as conn:
                    if db_type == 'postgresql':
                        conn.execute(text("ALTER TABLE users ADD COLUMN push_notifications_enabled BOOLEAN DEFAULT TRUE"))
                    else:
                        conn.execute(text("ALTER TABLE users ADD COLUMN push_notifications_enabled BOOLEAN DEFAULT 1"))
                print("✅ Migration complete: push_notifications_enabled column added")
            except Exception as e:
                print(f"⚠️  Migration error: {e}")
        
        # Add location columns if they don't exist
        if 'last_location_latitude' not in columns:
            print("🔄 Migrating database: Adding last_location_latitude column...")
            try:
                db_type = engine.dialect.name
                with engine.begin() as conn:
                    if db_type == 'postgresql':
                        conn.execute(text("ALTER TABLE users ADD COLUMN last_location_latitude FLOAT"))
                    else:
                        conn.execute(text("ALTER TABLE users ADD COLUMN last_location_latitude REAL"))
                print("✅ Migration complete: last_location_latitude column added")
            except Exception as e:
                print(f"⚠️  Migration error: {e}")
        
        if 'last_location_longitude' not in columns:
            print("🔄 Migrating database: Adding last_location_longitude column...")
            try:
                db_type = engine.dialect.name
                with engine.begin() as conn:
                    if db_type == 'postgresql':
                        conn.execute(text("ALTER TABLE users ADD COLUMN last_location_longitude FLOAT"))
                    else:
                        conn.execute(text("ALTER TABLE users ADD COLUMN last_location_longitude REAL"))
                print("✅ Migration complete: last_location_longitude column added")
            except Exception as e:
                print(f"⚠️  Migration error: {e}")
        
        if 'last_location_name' not in columns:
            print("🔄 Migrating database: Adding last_location_name column...")
            try:
                with engine.begin() as conn:
                    conn.execute(text("ALTER TABLE users ADD COLUMN last_location_name VARCHAR"))
                print("✅ Migration complete: last_location_name column added")
            except Exception as e:
                print(f"⚠️  Migration error: {e}")
                
        print("📊 Database schema check complete")
    else:
        print("📊 Creating new database schema")

