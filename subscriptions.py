import json
from datetime import datetime, timezone
from typing import Any, Dict, Optional

from sqlalchemy.orm import Session

from database import (
    SessionLocal,
    AppStoreNotificationRecord,
    SubscriptionEntitlement,
    User,
)


def _parse_iso_datetime(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def _find_user_by_original_transaction(
    db: Session, original_transaction_id: str
) -> Optional[User]:
    return (
        db.query(User)
        .filter(User.original_transaction_id == original_transaction_id)
        .one_or_none()
    )


def _get_or_create_entitlement(
    db: Session, original_transaction_id: str
) -> SubscriptionEntitlement:
    entitlement = (
        db.query(SubscriptionEntitlement)
        .filter(SubscriptionEntitlement.original_transaction_id == original_transaction_id)
        .one_or_none()
    )
    if entitlement:
        return entitlement

    entitlement = SubscriptionEntitlement(
        original_transaction_id=original_transaction_id,
        status="unknown",
        product_id=None,
    )
    db.add(entitlement)
    return entitlement


def update_entitlement(
    db: Session, notification: Dict[str, Any], transaction: Optional[Dict[str, Any]] = None
) -> None:
    notification_type = notification.get("notificationType", "")
    subtype = notification.get("subtype", "")
    data = notification.get("data", {})

    original_transaction_id = data.get("originalTransactionId")
    if transaction and not original_transaction_id:
        original_transaction_id = transaction.get("originalTransactionId")

    if not original_transaction_id:
        print("⚠️  Skipping notification: missing originalTransactionId")
        return

    entitlement = _get_or_create_entitlement(db, original_transaction_id)
    if transaction:
        entitlement.product_id = transaction.get("productId", entitlement.product_id)
        entitlement.expires_at = _parse_iso_datetime(transaction.get("expiresDate"))
        entitlement.signed_transaction_payload = json.dumps(transaction)

    # Update status based on notification type/subtype
    if notification_type in {"INITIAL_BUY", "DID_RENEW"}:
        entitlement.status = "active"
    elif notification_type in {"DID_FAIL_TO_RENEW", "BILLING_RETRY"}:
        entitlement.status = "grace_period"
    elif notification_type in {"EXPIRED", "REFUND", "REVOKE"}:
        entitlement.status = "expired"
        entitlement.revoked_at = datetime.now(timezone.utc)
    else:
        entitlement.status = "unknown"

    entitlement.updated_at = datetime.now(timezone.utc)
    
    # Also update User table if user exists with this original_transaction_id
    user = _find_user_by_original_transaction(db, original_transaction_id)
    if user:
        user.subscription_status = entitlement.status
        user.subscription_plan = entitlement.product_id
        # Also set original_transaction_id if not already set
        if not user.original_transaction_id:
            user.original_transaction_id = original_transaction_id
        print(f"✅ Updated user {user.email}: subscription_status={entitlement.status}, plan={entitlement.product_id}")
    else:
        print(f"⚠️  No user found with original_transaction_id={original_transaction_id}")


def handle_notification(
    notification: Dict[str, Any], transaction: Optional[Dict[str, Any]] = None
) -> None:
    db = SessionLocal()
    try:
        update_entitlement(db, notification, transaction)
        db.commit()
    except Exception as exc:
        db.rollback()
        print(f"❌ Failed to update entitlement: {exc}")
        raise
    finally:
        db.close()

