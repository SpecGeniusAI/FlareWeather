import json
import uuid
from datetime import datetime
from typing import Any, Dict

from fastapi import APIRouter, Request, BackgroundTasks, HTTPException, status

from apple_notifications_utils import AppleSignatureError, verify_signed_payload
from database import SessionLocal, AppStoreNotificationRecord
from subscriptions import handle_notification
router = APIRouter(prefix="/apple-notifications", tags=["apple"])


def process_notification_async(notification: Dict[str, Any], signed_payload: str) -> None:
    """
    Placeholder processor. Replace with your subscription handling logic.
    Runs off the request thread so we can acknowledge Apple quickly.
    """
    session = SessionLocal()
    try:
        notification_uuid = notification.get("notificationUUID") or str(uuid.uuid4())
        record = session.query(AppStoreNotificationRecord).filter_by(
            notification_uuid=notification_uuid
        ).one_or_none()

        data_json = json.dumps(notification, default=str)

        if record:
            record.notification_type = notification.get("notificationType")
            record.subtype = notification.get("subtype")
            record.payload = data_json
            record.signed_payload = signed_payload
            record.received_at = datetime.utcnow()
            record.processed = False
        else:
            record = AppStoreNotificationRecord(
                id=str(uuid.uuid4()),
                notification_uuid=notification_uuid,
                notification_type=notification.get("notificationType"),
                subtype=notification.get("subtype"),
                payload=data_json,
                signed_payload=signed_payload,
                received_at=datetime.utcnow(),
                processed=False,
            )
            session.add(record)

        session.commit()
        print(f"📨 Stored App Store notification {notification_uuid} ({record.notification_type})")
    except Exception as exc:
        session.rollback()
        print(f"❌ Failed to store App Store notification: {exc}")
    finally:
        session.close()

    transaction_payload = None
    data = notification.get("data") or {}
    signed_transaction_info = data.get("signedTransactionInfo")
    if signed_transaction_info:
        try:
            transaction_payload = verify_signed_payload(signed_transaction_info)
        except AppleSignatureError as exc:
            print(f"⚠️  Unable to verify signedTransactionInfo: {exc}")

    try:
        handle_notification(notification, transaction_payload)
        _mark_notification_processed(notification_uuid)
    except Exception as exc:
        print(f"❌ Error handling App Store notification {notification_uuid}: {exc}")


@router.post(
    "",
    status_code=status.HTTP_202_ACCEPTED,
    summary="Receive App Store Server Notifications",
)
async def receive_app_store_notification(
    request: Request,
    background_tasks: BackgroundTasks,
) -> Dict[str, str]:
    """
    Initial webhook stub for App Store Server Notifications.

    Apple posts JSON containing a `signedPayload`. We verify the signature,
    decode the payload, hand it off for async processing, and return 202.
    """
    payload = await request.json()
    signed_payload = payload.get("signedPayload")
    if not signed_payload:
        raise HTTPException(status_code=400, detail="Missing signedPayload field.")

    try:
        decoded_payload = verify_signed_payload(signed_payload)
    except AppleSignatureError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    background_tasks.add_task(process_notification_async, decoded_payload, signed_payload)
    return {"status": "received"}


def _mark_notification_processed(notification_uuid: str) -> None:
    session = SessionLocal()
    try:
        record = (
            session.query(AppStoreNotificationRecord)
            .filter_by(notification_uuid=notification_uuid)
            .one_or_none()
        )
        if record:
            record.processed = True
            session.commit()
    except Exception as exc:
        session.rollback()
        print(f"⚠️  Failed to mark notification {notification_uuid} as processed: {exc}")
    finally:
        session.close()


