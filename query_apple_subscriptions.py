#!/usr/bin/env python3
"""
Query Apple App Store Server API to get subscription status for all users
This requires App Store Connect API credentials.
"""
import os
import sys
from dotenv import load_dotenv

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import SessionLocal, User, SubscriptionEntitlement
from datetime import datetime, timezone
import json

load_dotenv()

# App Store Connect API credentials
APP_STORE_KEY_ID = os.getenv("APP_STORE_KEY_ID")
APP_STORE_ISSUER_ID = os.getenv("APP_STORE_ISSUER_ID")
APP_STORE_BUNDLE_ID = os.getenv("APP_STORE_BUNDLE_ID")  # e.g., "com.yourcompany.flareweather"
APP_STORE_PRIVATE_KEY = os.getenv("APP_STORE_PRIVATE_KEY")  # Private key content (PEM format)

def query_apple_subscriptions():
    """Query Apple's API to get subscription status for all users"""
    
    if not all([APP_STORE_KEY_ID, APP_STORE_ISSUER_ID, APP_STORE_BUNDLE_ID, APP_STORE_PRIVATE_KEY]):
        print("❌ Missing App Store Connect API credentials")
        print("\n📋 You need to set these environment variables:")
        print("   - APP_STORE_KEY_ID")
        print("   - APP_STORE_ISSUER_ID")
        print("   - APP_STORE_BUNDLE_ID (your app's bundle ID)")
        print("   - APP_STORE_PRIVATE_KEY (your private key in PEM format)")
        print("\n💡 To get these credentials:")
        print("   1. Go to App Store Connect → Users and Access → Keys")
        print("   2. Create a new key with 'App Manager' or 'Admin' role")
        print("   3. Download the private key (.p8 file)")
        print("   4. Copy the Key ID and Issuer ID")
        print("   5. Convert the .p8 key to PEM format (or use as-is)")
        return
    
        try:
            # Try to import the App Store Server Library
            try:
                from appstoreserverlibrary.api_client import APIClient
                from appstoreserverlibrary.models import Environment
            except ImportError:
                print("❌ app-store-server-library not installed")
                print("\n📦 Install it with:")
                print("   pip install app-store-server-library")
                return
        
        # Initialize API client
        print("🔐 Initializing App Store Server API client...")
        client = APIClient(
            key_id=APP_STORE_KEY_ID,
            issuer_id=APP_STORE_ISSUER_ID,
            private_key=APP_STORE_PRIVATE_KEY,
            bundle_id=APP_STORE_BUNDLE_ID,
            environment=Environment.PRODUCTION  # Use Environment.SANDBOX for testing
        )
        
        db = SessionLocal()
        
        try:
            # Get all users
            all_users = db.query(User).all()
            print(f"\n📊 Found {len(all_users)} total users")
            
            # Get users who already have original_transaction_id
            users_with_transaction_id = db.query(User).filter(
                User.original_transaction_id.isnot(None)
            ).all()
            print(f"✅ {len(users_with_transaction_id)} users already have original_transaction_id")
            
            # For users with transaction ID, query their subscription status
            updated_count = 0
            for user in users_with_transaction_id:
                try:
                    print(f"\n🔍 Querying subscription for user: {user.email} (transaction: {user.original_transaction_id})")
                    
                    # Query Apple's API
                    response = client.get_all_subscription_statuses(user.original_transaction_id)
                    
                    # Process the response
                    # Response.data is a list of SubscriptionGroupIdentifierItem objects
                    # Each contains subscriptions for a subscription group
                    if response.data and len(response.data) > 0:
                        found_active = False
                        
                        # Process each subscription group
                        for group_item in response.data:
                            # Each group has a list of subscriptions
                            subscriptions = group_item.last_transactions_item
                            
                            if subscriptions:
                                # Process each subscription in the group
                                for sub_item in subscriptions:
                                    # Get transaction info (contains product_id)
                                    transaction_info = sub_item.signed_transaction_info
                                    
                                    if transaction_info:
                                        # Parse the JWT to get product_id
                                        # The transaction info is a JWT - we need to decode it
                                        try:
                                            import base64
                                            # Extract payload from JWT
                                            parts = transaction_info.split('.')
                                            if len(parts) >= 2:
                                                # Decode payload (base64url)
                                                payload = parts[1]
                                                # Add padding if needed
                                                payload += '=' * (4 - len(payload) % 4)
                                                decoded = base64.urlsafe_b64decode(payload)
                                                import json
                                                transaction_data = json.loads(decoded)
                                                
                                                product_id = transaction_data.get('productId', '')
                                                
                                                # Get renewal info to determine status
                                                renewal_info = sub_item.signed_renewal_info
                                                status_value = "unknown"
                                                
                                                if renewal_info:
                                                    # Decode renewal info JWT
                                                    renewal_parts = renewal_info.split('.')
                                                    if len(renewal_parts) >= 2:
                                                        renewal_payload = renewal_parts[1]
                                                        renewal_payload += '=' * (4 - len(renewal_payload) % 4)
                                                        renewal_decoded = base64.urlsafe_b64decode(renewal_payload)
                                                        renewal_data = json.loads(renewal_decoded)
                                                        
                                                        # Check expiration date
                                                        expires_date = renewal_data.get('expiresDate', 0)
                                                        current_time = int(datetime.now(timezone.utc).timestamp() * 1000)
                                                        
                                                        if expires_date > current_time:
                                                            status_value = "active"
                                                            found_active = True
                                                        else:
                                                            status_value = "expired"
                                                
                                                # Find or create entitlement record
                                                entitlement = db.query(SubscriptionEntitlement).filter(
                                                    SubscriptionEntitlement.original_transaction_id == user.original_transaction_id,
                                                    SubscriptionEntitlement.product_id == product_id
                                                ).first()
                                                
                                                if not entitlement:
                                                    entitlement = SubscriptionEntitlement(
                                                        original_transaction_id=user.original_transaction_id,
                                                        product_id=product_id,
                                                        status=status_value
                                                    )
                                                    db.add(entitlement)
                                                    print(f"   ✅ Created entitlement: {product_id} - {status_value}")
                                                else:
                                                    entitlement.status = status_value
                                                    print(f"   ✅ Updated entitlement: {product_id} - {status_value}")
                                                
                                                # Update user record with the most recent/active subscription
                                                if status_value == "active":
                                                    user.subscription_status = "active"
                                                    user.subscription_plan = product_id
                                                
                                                updated_count += 1
                                        except Exception as parse_error:
                                            print(f"   ⚠️  Error parsing transaction: {parse_error}")
                                            continue
                        
                        if not found_active:
                            print(f"   ⚠️  No active subscription found")
                    else:
                        print(f"   ⚠️  No subscription found in Apple's response")
                        # Mark as not found if we have transaction ID but no subscription
                        if user.original_transaction_id and user.original_transaction_id != "0":
                            user.subscription_status = "not_found"
                        
                except Exception as e:
                    print(f"   ❌ Error querying for {user.email}: {e}")
                    continue
            
            db.commit()
            print(f"\n✅ Updated {updated_count} users' subscription status")
            
            # Show summary
            print("\n📊 Summary:")
            users_with_status = db.query(User).filter(User.subscription_status.isnot(None)).count()
            print(f"   Users with subscription status: {users_with_status}")
            print(f"   Users with transaction ID: {len(users_with_transaction_id)}")
            
        finally:
            db.close()
            
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    query_apple_subscriptions()
