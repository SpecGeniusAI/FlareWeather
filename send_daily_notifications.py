"""
Send daily forecast push notifications.
Runs daily at 8:00 AM EST to prompt users to check their daily forecast.
Simple approach: just sends a notification to open the app (no pre-priming needed).
"""
import os
import sys
from datetime import datetime, date
from typing import Optional
import json
from dotenv import load_dotenv

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from database import SessionLocal, User, init_db
import pytz
import requests

load_dotenv()

# APNs configuration
APNS_KEY_ID = os.getenv("APNS_KEY_ID")
APNS_TEAM_ID = os.getenv("APNS_TEAM_ID")
APNS_BUNDLE_ID = os.getenv("APNS_BUNDLE_ID", "KHUR.FlareWeather")
APNS_KEY_PATH = os.getenv("APNS_KEY_PATH")  # Path to .p8 key file
APNS_KEY_CONTENT = os.getenv("APNS_KEY_CONTENT")  # Or base64-encoded key content
APNS_USE_SANDBOX = os.getenv("APNS_USE_SANDBOX", "false").lower() == "true"

# Timezone
EST = pytz.timezone("America/New_York")

# APNs endpoints
APNS_PRODUCTION_URL = "https://api.push.apple.com"
APNS_SANDBOX_URL = "https://api.sandbox.push.apple.com"
APNS_BASE_URL = APNS_SANDBOX_URL if APNS_USE_SANDBOX else APNS_PRODUCTION_URL


def get_apns_token() -> Optional[str]:
    """
    Generate JWT token for APNs authentication.
    Uses PyJWT to sign the token with the APNs key.
    """
    try:
        import jwt
        import time
        
        if not APNS_KEY_ID or not APNS_TEAM_ID:
            print("❌ APNS_KEY_ID or APNS_TEAM_ID not set")
            return None
        
        # Load key content
        key_content = None
        if APNS_KEY_CONTENT:
            # Decode base64 if needed, or use directly
            import base64
            try:
                key_content = base64.b64decode(APNS_KEY_CONTENT).decode('utf-8')
            except:
                key_content = APNS_KEY_CONTENT
        elif APNS_KEY_PATH and os.path.exists(APNS_KEY_PATH):
            with open(APNS_KEY_PATH, 'r') as f:
                key_content = f.read()
        else:
            print("❌ APNS key not found (set APNS_KEY_PATH or APNS_KEY_CONTENT)")
            return None
        
        # Ensure key has proper PEM headers
        if not key_content.startswith("-----BEGIN"):
            key_content = f"-----BEGIN PRIVATE KEY-----\n{key_content}\n-----END PRIVATE KEY-----"
        
        # Create JWT token
        headers = {
            "alg": "ES256",
            "kid": APNS_KEY_ID
        }
        
        payload = {
            "iss": APNS_TEAM_ID,
            "iat": int(time.time())
        }
        
        token = jwt.encode(payload, key_content, algorithm="ES256", headers=headers)
        return token
        
    except Exception as e:
        print(f"❌ Error generating APNs token: {e}")
        import traceback
        traceback.print_exc()
        return None


def send_push_notification(
    device_token: str,
    title: str,
    body: str,
    data: Optional[dict] = None
) -> bool:
    """
    Send push notification via APNs.
    
    Returns:
        True if successful, False otherwise
    """
    try:
        # Get APNs token
        apns_token = get_apns_token()
        if not apns_token:
            return False
        
        # Build notification payload
        payload = {
            "aps": {
                "alert": {
                    "title": title,
                    "body": body
                },
                "sound": "default",
                "badge": 1
            }
        }
        
        # Add custom data
        if data:
            for key, value in data.items():
                payload[key] = value
        
        # Send to APNs
        url = f"{APNS_BASE_URL}/3/device/{device_token}"
        headers = {
            "Authorization": f"Bearer {apns_token}",
            "apns-topic": APNS_BUNDLE_ID,
            "apns-priority": "10",
            "apns-push-type": "alert",
            "Content-Type": "application/json"
        }
        
        response = requests.post(url, json=payload, headers=headers, timeout=10)
        
        if response.status_code == 200:
            return True
        else:
            error_details = response.text
            try:
                error_json = response.json()
                if "reason" in error_json:
                    error_details = f"{response.status_code} - Reason: {error_json['reason']}"
            except:
                pass
            
            print(f"❌ APNs error: {response.status_code} - {error_details}")
            print(f"   Device token: {device_token[:20]}...")
            print(f"   APNs URL: {url}")
            print(f"   Bundle ID: {APNS_BUNDLE_ID}")
            print(f"   Using sandbox: {APNS_USE_SANDBOX}")
            return False
            
    except Exception as e:
        print(f"❌ Error sending push notification: {e}")
        import traceback
        traceback.print_exc()
        return False


def send_daily_notifications():
    """
    Main function to send daily forecast notifications.
    Simple approach: sends notification to all users with notifications enabled.
    No pre-priming needed - app generates forecast when user opens it.
    """
    print("📱 Starting daily notification sending...")
    print(f"⏰ Time: {datetime.now(EST).strftime('%Y-%m-%d %H:%M:%S %Z')}")
    
    # Initialize database
    init_db()
    
    db = SessionLocal()
    today = date.today()
    
    try:
        # Get all users with notifications enabled and push tokens
        eligible_users = db.query(User).filter(
            User.push_notifications_enabled == True,
            User.push_notification_token.isnot(None)
        ).all()
        
        print(f"📊 Found {len(eligible_users)} users with notifications enabled and push tokens")
        
        success_count = 0
        error_count = 0
        skipped_count = 0
        
        # Simple notification message
        title = "FlareWeather"
        body = "Good morning! Your personalized weather forecast is waiting for you."
        
        # Custom data to open app
        data = {
            "type": "daily_forecast_reminder",
            "date": str(today)
        }
        
        for user in eligible_users:
            try:
                # Send notification
                success = send_push_notification(
                    device_token=user.push_notification_token,
                    title=title,
                    body=body,
                    data=data
                )
                
                if success:
                    print(f"✅ Sent notification to {user.email or user.id}")
                    success_count += 1
                else:
                    print(f"❌ Failed to send notification to {user.email or user.id}")
                    error_count += 1
                
            except Exception as e:
                print(f"❌ Error processing user {user.email or user.id}: {e}")
                error_count += 1
                import traceback
                traceback.print_exc()
                continue
        
        print(f"\n📊 Notification sending complete:")
        print(f"   ✅ Success: {success_count}")
        print(f"   ❌ Errors: {error_count}")
        print(f"   📅 Date: {today}")
        
    finally:
        db.close()


if __name__ == "__main__":
    send_daily_notifications()
