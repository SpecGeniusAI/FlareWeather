#!/usr/bin/env python3
"""
Quick script to check subscription data in the database
Run this to see what subscription entitlements exist and if they're linked to users
"""
import os
from dotenv import load_dotenv
from database import SessionLocal, User, SubscriptionEntitlement

load_dotenv()

db = SessionLocal()

try:
    # Count users
    total_users = db.query(User).count()
    users_with_subscription_status = db.query(User).filter(User.subscription_status.isnot(None)).count()
    users_with_original_transaction_id = db.query(User).filter(User.original_transaction_id.isnot(None)).count()
    
    print("=" * 60)
    print("📊 USER STATISTICS")
    print("=" * 60)
    print(f"Total users: {total_users}")
    print(f"Users with subscription_status set: {users_with_subscription_status}")
    print(f"Users with original_transaction_id: {users_with_original_transaction_id}")
    print()
    
    # Count entitlements
    total_entitlements = db.query(SubscriptionEntitlement).count()
    active_entitlements = db.query(SubscriptionEntitlement).filter(SubscriptionEntitlement.status == "active").count()
    
    print("=" * 60)
    print("📊 SUBSCRIPTION ENTITLEMENT STATISTICS")
    print("=" * 60)
    print(f"Total entitlements: {total_entitlements}")
    print(f"Active entitlements: {active_entitlements}")
    print()
    
    # Show active entitlements
    if active_entitlements > 0:
        print("=" * 60)
        print("✅ ACTIVE SUBSCRIPTIONS")
        print("=" * 60)
        active = db.query(SubscriptionEntitlement).filter(SubscriptionEntitlement.status == "active").all()
        for ent in active:
            # Check if linked to a user
            user = db.query(User).filter(User.original_transaction_id == ent.original_transaction_id).first()
            if user:
                print(f"  ✅ Linked: {user.email} - {ent.product_id} (transaction: {ent.original_transaction_id[:20]}...)")
            else:
                print(f"  ⚠️  Unlinked: {ent.product_id} (transaction: {ent.original_transaction_id[:20]}...) - No user found")
        print()
    
    # Show unlinked entitlements
    all_entitlements = db.query(SubscriptionEntitlement).all()
    unlinked = []
    for ent in all_entitlements:
        user = db.query(User).filter(User.original_transaction_id == ent.original_transaction_id).first()
        if not user:
            unlinked.append(ent)
    
    if unlinked:
        print("=" * 60)
        print("⚠️  UNLINKED ENTITLEMENTS (subscriptions without user accounts)")
        print("=" * 60)
        for ent in unlinked:
            print(f"  Transaction: {ent.original_transaction_id}")
            print(f"    Status: {ent.status}")
            print(f"    Plan: {ent.product_id}")
            print(f"    Updated: {ent.updated_at}")
            print()
    
    # Show users who might have subscriptions but aren't linked
    users_without_subscription_data = db.query(User).filter(
        (User.subscription_status.is_(None)) | (User.subscription_status == "none")
    ).count()
    
    print("=" * 60)
    print("📋 SUMMARY")
    print("=" * 60)
    print(f"Users without subscription data: {users_without_subscription_data}")
    print(f"Active subscriptions in database: {active_entitlements}")
    print(f"Unlinked subscriptions: {len(unlinked)}")
    print()
    
    if active_entitlements > 0 and len(unlinked) > 0:
        print("💡 ISSUE: You have active subscriptions but they're not linked to users!")
        print("   This means users subscribed but their User record doesn't have original_transaction_id set.")
        print("   We need to link them manually or add code to link on first subscription.")
    
finally:
    db.close()
