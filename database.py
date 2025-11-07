"""
Database models and connection for FlareWeather API
"""
from sqlalchemy import create_engine, Column, String, DateTime, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from datetime import datetime
import os
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
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


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
                    # SQLite doesn't support ALTER TABLE ADD COLUMN IF NOT EXISTS directly
                    # So we check and add it
                    conn.execute(text("ALTER TABLE users ADD COLUMN apple_user_id VARCHAR"))
                    conn.commit()
                print("✅ Migration complete: apple_user_id column added")
            except Exception as e:
                # Column might already exist or other error
                print(f"⚠️  Migration note: {e}")
                # Try to continue anyway
                
        # Make email and hashed_password nullable (SQLite doesn't support MODIFY COLUMN easily)
        # This is handled at the ORM level, but we should note it
        print("📊 Database schema check complete")
    else:
        print("📊 Creating new database schema")

