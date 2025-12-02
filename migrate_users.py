"""
Migration script to transfer users from SQLite to PostgreSQL
Run this ONCE after setting up PostgreSQL on Railway

Usage:
1. Set DATABASE_URL environment variable to your PostgreSQL connection string
2. Make sure the SQLite database file exists locally
3. Run: python migrate_users.py
"""
import os
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from database import User, Base

load_dotenv()

# Source: Local SQLite database
SQLITE_URL = "sqlite:///./flareweather.db"

# Destination: PostgreSQL (from environment variable)
POSTGRES_URL = os.getenv("DATABASE_URL")

if not POSTGRES_URL or not POSTGRES_URL.startswith("postgres"):
    print("❌ Error: DATABASE_URL not set or not a PostgreSQL URL")
    print("   Set DATABASE_URL to your PostgreSQL connection string")
    print("   Example: postgresql://user:pass@host:port/dbname")
    exit(1)

print("🔄 Starting user migration...")
print(f"📤 Source: SQLite ({SQLITE_URL})")
print(f"📥 Destination: PostgreSQL")

# Create connections
sqlite_engine = create_engine(SQLITE_URL, connect_args={"check_same_thread": False})
postgres_engine = create_engine(POSTGRES_URL, pool_pre_ping=True)

SqliteSession = sessionmaker(bind=sqlite_engine)
PostgresSession = sessionmaker(bind=postgres_engine)

# Create tables in PostgreSQL if they don't exist
print("\n📊 Creating tables in PostgreSQL...")
Base.metadata.create_all(bind=postgres_engine)

# Get all users from SQLite
sqlite_session = SqliteSession()
postgres_session = PostgresSession()

try:
    users = sqlite_session.query(User).all()
    print(f"\n👥 Found {len(users)} user(s) to migrate")
    
    if len(users) == 0:
        print("✅ No users to migrate")
        exit(0)
    
    migrated = 0
    skipped = 0
    
    for user in users:
        # Check if user already exists in PostgreSQL
        existing = postgres_session.query(User).filter(User.email == user.email).first()
        
        if existing:
            print(f"⚠️  Skipping {user.email} (already exists in PostgreSQL)")
            skipped += 1
        else:
            # Create new user in PostgreSQL
            new_user = User(
                id=user.id,
                email=user.email,
                hashed_password=user.hashed_password,
                name=user.name,
                created_at=user.created_at,
                updated_at=user.updated_at
            )
            postgres_session.add(new_user)
            print(f"✅ Migrating {user.email}")
            migrated += 1
    
    # Commit all changes
    postgres_session.commit()
    
    print(f"\n✨ Migration complete!")
    print(f"   ✅ Migrated: {migrated} user(s)")
    print(f"   ⚠️  Skipped: {skipped} user(s) (already exist)")
    
except Exception as e:
    postgres_session.rollback()
    print(f"\n❌ Error during migration: {e}")
    import traceback
    traceback.print_exc()
    exit(1)
finally:
    sqlite_session.close()
    postgres_session.close()

