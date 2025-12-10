#!/usr/bin/env python3
"""
Google Sheets Sync Service
Syncs user data from PostgreSQL to Google Sheets every hour
"""
import os
import time
from datetime import datetime
from typing import List, Dict, Any
import json
from sqlalchemy.orm import Session
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from dotenv import load_dotenv

# Import database models
# Try to import from parent directory first (for local development)
try:
    import sys
    parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if parent_dir not in sys.path:
        sys.path.append(parent_dir)
    from database import SessionLocal, User, SubscriptionEntitlement
except ImportError:
    # If that fails, try importing directly (for Railway deployment)
    # Make sure database.py is in the same directory or accessible
    from database import SessionLocal, User, SubscriptionEntitlement

load_dotenv()

# Configuration
SHEET_ID = os.getenv("GOOGLE_SHEET_ID", "18f5nfH8YsM5vUv5ZUN_KSniGhQAggwRyf-57jOnXLuY")
WORKSHEET_NAME = os.getenv("GOOGLE_WORKSHEET_NAME", "Sheet1")  # Default to first sheet
SYNC_INTERVAL_HOURS = int(os.getenv("SYNC_INTERVAL_HOURS", "1"))  # Default: 1 hour

# Google Sheets API scope
SCOPES = ['https://www.googleapis.com/auth/spreadsheets']


def get_google_sheets_service():
    """Initialize Google Sheets API service using OAuth credentials"""
    # Try OAuth token first (preferred for organizations with key restrictions)
    oauth_token_json = os.getenv("GOOGLE_OAUTH_TOKEN_JSON")
    
    if oauth_token_json:
        try:
            creds_dict = json.loads(oauth_token_json)
            credentials = Credentials.from_authorized_user_info(creds_dict, SCOPES)
            
            # Refresh if needed
            if credentials.expired and credentials.refresh_token:
                credentials.refresh(Request())
            
            service = build('sheets', 'v4', credentials=credentials)
            return service
        except Exception as e:
            print(f"⚠️  OAuth token error: {e}, trying service account...")
    
    # Fallback to service account (if allowed)
    creds_json = os.getenv("GOOGLE_SERVICE_ACCOUNT_JSON")
    
    if not creds_json:
        raise ValueError(
            "Neither GOOGLE_OAUTH_TOKEN_JSON nor GOOGLE_SERVICE_ACCOUNT_JSON is set. "
            "Please set up OAuth credentials using oauth_setup.py"
        )
    
    # Parse JSON credentials
    try:
        creds_dict = json.loads(creds_json)
    except json.JSONDecodeError:
        raise ValueError("GOOGLE_SERVICE_ACCOUNT_JSON is not valid JSON")
    
    # Create credentials object
    from google.oauth2.service_account import Credentials as ServiceAccountCredentials
    credentials = ServiceAccountCredentials.from_service_account_info(
        creds_dict,
        scopes=SCOPES
    )
    
    # Build the service
    service = build('sheets', 'v4', credentials=credentials)
    return service


def get_all_users(db: Session) -> List[Dict[str, Any]]:
    """Fetch all users from database with subscription info"""
    users = db.query(User).all()
    
    user_data = []
    for user in users:
        # Get subscription info from SubscriptionEntitlement if available
        subscription_status = user.subscription_status
        subscription_plan = user.subscription_plan
        
        # If not set on user, try to get from SubscriptionEntitlement
        if not subscription_status and user.original_transaction_id:
            entitlement = db.query(SubscriptionEntitlement).filter(
                SubscriptionEntitlement.original_transaction_id == user.original_transaction_id
            ).first()
            
            if entitlement:
                subscription_status = entitlement.status
                subscription_plan = entitlement.product_id
        
        # Determine access type
        access_type = "none"
        if subscription_status == "active":
            access_type = "subscription"
        elif user.free_access_enabled:
            if user.free_access_expires_at:
                from datetime import timezone
                now = datetime.now(timezone.utc)
                if user.free_access_expires_at.replace(tzinfo=timezone.utc) > now:
                    access_type = "free"
                else:
                    access_type = "free_expired"
            else:
                access_type = "free_lifetime"
        
        user_data.append({
            "id": user.id,
            "email": user.email or "N/A",
            "name": user.name or "N/A",
            "created_at": user.created_at.strftime("%Y-%m-%d %H:%M:%S") if user.created_at else "N/A",
            "subscription_status": subscription_status or "none",
            "subscription_plan": subscription_plan or "N/A",
            "access_type": access_type,
            "free_access_enabled": "Yes" if user.free_access_enabled else "No",
            "free_access_expires_at": user.free_access_expires_at.strftime("%Y-%m-%d %H:%M:%S") if user.free_access_expires_at else "Never",
            "has_diagnoses": "Yes" if user.diagnoses else "No",
            "apple_user_id": user.apple_user_id or "N/A",
        })
    
    return user_data


def sync_to_sheets():
    """Sync user data to Google Sheets"""
    print(f"[{datetime.now()}] Starting sync to Google Sheets...")
    
    try:
        # Check DATABASE_URL
        db_url = os.getenv("DATABASE_URL")
        if not db_url:
            raise ValueError("DATABASE_URL environment variable not set! Add it in Railway Variables tab.")
        
        print(f"  Database: {db_url.split('@')[1] if '@' in db_url else 'configured'}")  # Show host without credentials
        
        # Get database session
        db = SessionLocal()
        
        try:
            # Fetch all users
            users = get_all_users(db)
            print(f"  Found {len(users)} users")
            
            # Prepare data for Google Sheets
            # Headers
            headers = [
                "ID",
                "Email",
                "Name",
                "Created At",
                "Subscription Status",
                "Subscription Plan",
                "Access Type",
                "Free Access Enabled",
                "Free Access Expires At",
                "Has Diagnoses",
                "Apple User ID"
            ]
            
            # Data rows
            rows = [headers]
            for user in users:
                rows.append([
                    user["id"],
                    user["email"],
                    user["name"],
                    user["created_at"],
                    user["subscription_status"],
                    user["subscription_plan"],
                    user["access_type"],
                    user["free_access_enabled"],
                    user["free_access_expires_at"],
                    user["has_diagnoses"],
                    user["apple_user_id"]
                ])
            
            # Get Google Sheets service
            service = get_google_sheets_service()
            
            # Clear existing data and write new data
            range_name = f"{WORKSHEET_NAME}!A1"
            
            # Clear the sheet first
            service.spreadsheets().values().clear(
                spreadsheetId=SHEET_ID,
                range=f"{WORKSHEET_NAME}!A:Z"
            ).execute()
            
            # Write new data
            body = {
                'values': rows
            }
            
            result = service.spreadsheets().values().update(
                spreadsheetId=SHEET_ID,
                range=range_name,
                valueInputOption='RAW',
                body=body
            ).execute()
            
            print(f"  ✅ Successfully synced {len(users)} users to Google Sheets")
            print(f"  Updated {result.get('updatedCells')} cells")
            
        finally:
            db.close()
            
    except HttpError as error:
        print(f"  ❌ Google Sheets API error: {error}")
        raise
    except Exception as error:
        print(f"  ❌ Error during sync: {error}")
        import traceback
        traceback.print_exc()
        raise


def main():
    """Main loop - sync every hour"""
    print("🚀 Google Sheets Sync Service Started")
    print(f"   Sheet ID: {SHEET_ID}")
    print(f"   Worksheet: {WORKSHEET_NAME}")
    print(f"   Sync interval: {SYNC_INTERVAL_HOURS} hour(s)")
    print()
    
    # Do initial sync
    try:
        sync_to_sheets()
    except Exception as e:
        print(f"❌ Initial sync failed: {e}")
        print("   Will retry on next interval...")
    
    # Sync every hour
    interval_seconds = SYNC_INTERVAL_HOURS * 3600
    
    while True:
        try:
            time.sleep(interval_seconds)
            sync_to_sheets()
        except KeyboardInterrupt:
            print("\n🛑 Sync service stopped")
            break
        except Exception as e:
            print(f"❌ Sync error: {e}")
            print("   Will retry on next interval...")
            time.sleep(60)  # Wait 1 minute before retrying on error


if __name__ == "__main__":
    main()
