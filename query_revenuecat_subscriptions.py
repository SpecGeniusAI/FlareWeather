#!/usr/bin/env python3
"""
Query RevenueCat API to get subscription info for all users
This is easier than Apple's API if you're using RevenueCat.
"""
import os
import sys
import requests
from dotenv import load_dotenv

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import SessionLocal, User, SubscriptionEntitlement
from datetime import datetime

load_dotenv()

# RevenueCat API credentials
REVENUECAT_API_KEY = os.getenv("REVENUECAT_API_KEY")  # Your RevenueCat API key
REVENUECAT_APP_ID = os.getenv("REVENUECAT_APP_ID")  # Your RevenueCat App ID

def query_revenuecat_subscriptions():
    """Query RevenueCat API to get subscription info for all users"""
    
    if not REVENUECAT_API_KEY:
        print("❌ REVENUECAT_API_KEY not set")
        print("\n📋 To get your RevenueCat API key:")
        print("   1. Go to RevenueCat Dashboard → Project Settings → API Keys")
        print("   2. Copy your Public API Key or Secret API Key")
        print("   3. Add it as REVENUECAT_API_KEY in Railway")
        return
    
    db = SessionLocal()
    
    try:
        # Get all users
        all_users = db.query(User).all()
        print(f"📊 Found {len(all_users)} total users")
        
        # RevenueCat API base URL
        base_url = "https://api.revenuecat.com/v1"
        headers = {
            "Authorization": f"Bearer {REVENUECAT_API_KEY}",
            "Content-Type": "application/json"
        }
        
        updated_count = 0
        not_found_count = 0
        
        for user in all_users:
            try:
                # Try to find customer by email or user ID
                # RevenueCat uses app_user_id which might be the user's email or a custom ID
                
                # Option 1: Search by email
                search_url = f"{base_url}/subscribers/{user.email}"
                
                # Option 2: If you use custom app_user_id, use that instead
                # search_url = f"{base_url}/subscribers/{user.id}"
                
                response = requests.get(search_url, headers=headers, timeout=10)
                
                if response.status_code == 200:
                    customer_data = response.json()
                    
                    # Extract subscription info
                    subscriber = customer_data.get("subscriber", {})
                    entitlements = subscriber.get("entitlements", {})
                    
                    # Check for active entitlements
                    for entitlement_id, entitlement_data in entitlements.items():
                        if entitlement_data.get("is_active", False):
                            # Get product identifier
                            product_id = entitlement_data.get("product_identifier", "")
                            
                            # Get original transaction ID from latest transaction
                            latest_transaction = entitlement_data.get("latest_purchase_date", "")
                            
                            # Try to get original transaction ID from purchase dates
                            # RevenueCat stores this in the purchase history
                            purchase_dates = entitlement_data.get("purchase_dates", {})
                            
                            # Get original transaction ID (might be in first purchase)
                            original_transaction_id = None
                            
                            # Check if user already has transaction ID
                            if not user.original_transaction_id:
                                # Try to get from RevenueCat's transaction history
                                # Note: RevenueCat API structure may vary
                                transactions = entitlement_data.get("transactions", [])
                                if transactions:
                                    # Get the first (original) transaction
                                    original_transaction_id = transactions[0].get("transaction_id") if transactions else None
                            
                            # Update user record
                            if not user.original_transaction_id and original_transaction_id:
                                user.original_transaction_id = original_transaction_id
                                print(f"✅ Found transaction ID for {user.email}: {original_transaction_id}")
                            
                            # Update subscription status
                            user.subscription_status = "active"
                            user.subscription_plan = product_id
                            
                            # Create or update entitlement
                            if user.original_transaction_id:
                                entitlement = db.query(SubscriptionEntitlement).filter(
                                    SubscriptionEntitlement.original_transaction_id == user.original_transaction_id
                                ).first()
                                
                                if not entitlement:
                                    entitlement = SubscriptionEntitlement(
                                        original_transaction_id=user.original_transaction_id,
                                        product_id=product_id,
                                        status="active"
                                    )
                                    db.add(entitlement)
                                else:
                                    entitlement.status = "active"
                                    entitlement.product_id = product_id
                            
                            updated_count += 1
                            print(f"✅ Updated {user.email}: {product_id}")
                            break  # Found active subscription, move to next user
                    
                    if not any(ent.get("is_active", False) for ent in entitlements.values()):
                        print(f"⚠️  {user.email}: No active subscription")
                        not_found_count += 1
                
                elif response.status_code == 404:
                    # Customer not found in RevenueCat
                    not_found_count += 1
                    print(f"⚠️  {user.email}: Not found in RevenueCat")
                else:
                    print(f"❌ Error querying {user.email}: {response.status_code} - {response.text}")
                    
            except Exception as e:
                print(f"❌ Error processing {user.email}: {e}")
                continue
        
        db.commit()
        
        print(f"\n✅ Summary:")
        print(f"   Updated: {updated_count} users")
        print(f"   Not found: {not_found_count} users")
        
    finally:
        db.close()

if __name__ == "__main__":
    query_revenuecat_subscriptions()
