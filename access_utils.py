"""
Utilities for checking user access (subscription or free access)
"""
from datetime import datetime, timezone
from typing import Optional
from sqlalchemy.orm import Session

from database import User, SubscriptionEntitlement


def has_active_access(db: Session, user_id: str) -> bool:
    """
    Check if a user has active access (either through subscription or free access).
    
    Args:
        db: Database session
        user_id: User ID to check
        
    Returns:
        True if user has active access, False otherwise
    """
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        return False
    
    # Check free access first
    if user.free_access_enabled:
        # If expires_at is None, access never expires
        if user.free_access_expires_at is None:
            return True
        # Check if free access hasn't expired
        now = datetime.now(timezone.utc)
        if user.free_access_expires_at.replace(tzinfo=timezone.utc) > now:
            return True
    
    # Check subscription access
    if user.original_transaction_id:
        entitlement = (
            db.query(SubscriptionEntitlement)
            .filter(SubscriptionEntitlement.original_transaction_id == user.original_transaction_id)
            .first()
        )
        if entitlement:
            # Check if subscription is active
            if entitlement.status == "active":
                # Also check expiration date if present
                if entitlement.expires_at:
                    now = datetime.now(timezone.utc)
                    if entitlement.expires_at.replace(tzinfo=timezone.utc) > now:
                        return True
                else:
                    # Active status without expiration date is considered active
                    return True
    
    return False


def get_access_status(db: Session, user_id: str) -> dict:
    """
    Get detailed access status for a user.
    
    Args:
        db: Database session
        user_id: User ID to check
        
    Returns:
        Dictionary with access information:
        {
            "has_access": bool,
            "access_type": "subscription" | "free" | "none",
            "expires_at": datetime | None,
            "is_expired": bool
        }
    """
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        return {
            "has_access": False,
            "access_type": "none",
            "expires_at": None,
            "is_expired": False
        }
    
    now = datetime.now(timezone.utc)
    
    # Check free access first
    if user.free_access_enabled:
        expires_at = user.free_access_expires_at
        if expires_at:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
            is_expired = expires_at <= now
        else:
            is_expired = False
        
        if not is_expired:
            # Active free access
            return {
                "has_access": True,
                "access_type": "free",
                "expires_at": expires_at.isoformat() if expires_at else None,
                "is_expired": False
            }
        else:
            # Expired free access - return this so iOS knows it was free access that expired
            return {
                "has_access": False,
                "access_type": "free",  # Still "free" to indicate they had free access
                "expires_at": expires_at.isoformat() if expires_at else None,
                "is_expired": True
            }
    
    # Check subscription access
    if user.original_transaction_id:
        entitlement = (
            db.query(SubscriptionEntitlement)
            .filter(SubscriptionEntitlement.original_transaction_id == user.original_transaction_id)
            .first()
        )
        if entitlement and entitlement.status == "active":
            expires_at = entitlement.expires_at
            if expires_at:
                expires_at = expires_at.replace(tzinfo=timezone.utc)
                is_expired = expires_at <= now
            else:
                is_expired = False
            
            if not is_expired:
                return {
                    "has_access": True,
                    "access_type": "subscription",
                    "expires_at": expires_at.isoformat() if expires_at else None,
                    "is_expired": False
                }
    
    # No access at all
    return {
        "has_access": False,
        "access_type": "none",
        "expires_at": None,
        "is_expired": True
    }
