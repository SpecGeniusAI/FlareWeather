#!/usr/bin/env python3
"""
Sync subscription status from App Store Server API
This queries Apple's API to get subscription status for users who have original_transaction_id
"""
import os
import sys
from dotenv import load_dotenv

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import SessionLocal, User, SubscriptionEntitlement
from datetime import datetime, timezone

load_dotenv()

# App Store Connect API credentials (needed to query subscription status)
APP_STORE_KEY_ID = os.getenv("APP_STORE_KEY_ID")
APP_STORE_ISSUER_ID = os.getenv("APP_STORE_ISSUER_ID")
APP_STORE_BUNDLE_ID = os.getenv("APP_STORE_BUNDLE_ID")  # Your app's bundle ID
APP_STORE_PRIVATE_KEY = os.getenv("APP_STORE_PRIVATE_KEY")  # Private key content

def sync_user_subscriptions():
    """Sync subscription status for all users who have original_transaction_id"""
    db = SessionLocal()
    
    try:
        # Get users with original_transaction_id
        users_with_transaction_id = db.query(User).filter(
            User.original_transaction_id.isnot(None)
        ).all()
        
        print(f"Found {len(users_with_transaction_id)} users with original_transaction_id")
        
        if not APP_STORE_KEY_ID or not APP_STORE_ISSUER_ID or not APP_STORE_PRIVATE_KEY:
            print("⚠️  App Store Connect API credentials not configured")
            print("   Need: APP_STORE_KEY_ID, APP_STORE_ISSUER_ID, APP_STORE_PRIVATE_KEY")
            print("   Without these, we can't query Apple's API")
            print()
            print("💡 Alternative: Have iOS app send original_transaction_id when user subscribes")
            return
        
        # TODO: Implement App Store Server API query
        # This requires the app-store-server-library-python package
        print("📋 To query Apple's API, we need to:")
        print("   1. Install: pip install app-store-server-library-python")
        print("   2. Query each user's subscription status")
        print("   3. Create/update SubscriptionEntitlement records")
        print("   4. Update User.subscription_status and User.subscription_plan")
        
    finally:
        db.close()

if __name__ == "__main__":
    sync_user_subscriptions()
