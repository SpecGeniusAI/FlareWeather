"""
Database models and connection for FlareWeather API
"""
from sqlalchemy import create_engine, Column, String, DateTime, Text, Boolean, Float, Integer
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from datetime import datetime
import os
import uuid
from dotenv import load_dotenv

load_dotenv()

# Database URL - PostgreSQL for production (Railway), SQLite for local development
# Railway automatically provides DATABASE_URL when you add a PostgreSQL service
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./flareweather.db")

# Handle both PostgreSQL and SQLite connection strings
# Railway provides DATABASE_URL in format: postgresql://user:pass@host:port/dbname
# Local SQLite: sqlite:///./flareweather.db
if DATABASE_URL.startswith("postgresql://") or DATABASE_URL.startswith("postgres://"):
    # PostgreSQL connection
    engine = create_engine(DATABASE_URL, pool_pre_ping=True)
    print("📊 Using PostgreSQL database (production)")
else:
    # SQLite connection (local development)
    engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False}
    )
    print("📊 Using SQLite database (local development)")

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
                with engine.connect() as conn:
                    conn.execute(text("ALTER TABLE users ADD COLUMN apple_user_id VARCHAR"))
                    conn.commit()
                print("✅ Migration complete: apple_user_id column added")
            except Exception as e:
                print(f"⚠️  Migration note: {e}")

        # Add original_transaction_id column if it doesn't exist
        if 'original_transaction_id' not in columns:
            print("🔄 Migrating database: Adding original_transaction_id column...")
            try:
                with engine.connect() as conn:
                    conn.execute(text("ALTER TABLE users ADD COLUMN original_transaction_id VARCHAR"))
                    conn.commit()
                print("✅ Migration complete: original_transaction_id column added")
            except Exception as e:
                print(f"⚠️  Migration note: {e}")
                
        print("📊 Database schema check complete")
    else:
        print("📊 Creating new database schema")

