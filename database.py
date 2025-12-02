"""
Database models and connection for FlareWeather API
"""
from sqlalchemy import create_engine, Column, String, DateTime, Text, Boolean, Float, Integer, Index
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
            return create_engine(url, pool_pre_ping=True)
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
        
        # Add diagnoses, stored_papers, and papers_updated_at columns if they don't exist
        if 'diagnoses' not in columns:
            print("🔄 Migrating database: Adding diagnoses column...")
            try:
                with engine.connect() as conn:
                    conn.execute(text("ALTER TABLE users ADD COLUMN diagnoses TEXT"))
                    conn.commit()
                print("✅ Migration complete: diagnoses column added")
            except Exception as e:
                print(f"⚠️  Migration note: {e}")
        
        if 'stored_papers' not in columns:
            print("🔄 Migrating database: Adding stored_papers column...")
            try:
                with engine.connect() as conn:
                    conn.execute(text("ALTER TABLE users ADD COLUMN stored_papers TEXT"))
                    conn.commit()
                print("✅ Migration complete: stored_papers column added")
            except Exception as e:
                print(f"⚠️  Migration note: {e}")
        
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
                
        print("📊 Database schema check complete")
    else:
        print("📊 Creating new database schema")

