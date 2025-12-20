#!/usr/bin/env python3
"""
Grant lifetime access to a specific user
"""
import os
from dotenv import load_dotenv

load_dotenv()

from database import SessionLocal, User

def grant_lifetime_access(email: str):
    """Grant lifetime free access to a user by email"""
    db = SessionLocal()
    
    try:
        user = db.query(User).filter(User.email == email).first()
        
        if not user:
            print(f"❌ User not found: {email}")
            return False
        
        # Grant lifetime access
        user.free_access_enabled = True
        user.free_access_expires_at = None  # None = never expires (lifetime)
        
        db.commit()
        
        print(f"✅ Granted lifetime access to: {email}")
        print(f"   User ID: {user.id}")
        print(f"   Name: {user.name}")
        print(f"   free_access_enabled: {user.free_access_enabled}")
        print(f"   free_access_expires_at: {user.free_access_expires_at} (None = lifetime)")
        return True
        
    except Exception as e:
        db.rollback()
        print(f"❌ Error: {e}")
        return False
    finally:
        db.close()

if __name__ == "__main__":
    grant_lifetime_access("kylegritchie@gmail.com")

