import os
import logging
import httpx

logger = logging.getLogger("mailgun")

MAILGUN_API_KEY = os.getenv("MAILGUN_API_KEY")
MAILGUN_DOMAIN = os.getenv("MAILGUN_DOMAIN")
MAILGUN_FROM_EMAIL = os.getenv("MAILGUN_FROM_EMAIL", "FlareWeather <reset@flareweather.app>")
MAILGUN_API_BASE_URL = os.getenv("MAILGUN_API_BASE_URL", "https://api.mailgun.net/v3").rstrip("/")
MAILGUN_DEBUG_EMAILS = os.getenv("MAILGUN_DEBUG_EMAILS") == "1"


async def send_password_reset_email(email: str, code: str) -> None:
    """
    Send a password reset code via Mailgun.

    Set MAILGUN_DEBUG_EMAILS=1 locally to log successful sends in development
    without printing codes in production logs.
    """
    if not MAILGUN_API_KEY or not MAILGUN_DOMAIN or not MAILGUN_FROM_EMAIL:
        error_msg = f"Mailgun environment variables not fully configured. API_KEY: {'SET' if MAILGUN_API_KEY else 'NOT SET'}, DOMAIN: {MAILGUN_DOMAIN or 'NOT SET'}, FROM_EMAIL: {MAILGUN_FROM_EMAIL or 'NOT SET'}"
        print(f"❌ {error_msg}")
        raise RuntimeError(error_msg)

    subject = "Your FlareWeather Password Reset Code"
    text_body = (
        f"Hi there,\n\n"
        f"Use this code to reset your FlareWeather password: {code}\n"
        "It expires in 30 minutes. If you didn’t request this, feel free to ignore it.\n\n"
        "— The FlareWeather Team"
    )
    html_body = (
        "<p>Hi there,</p>"
        f"<p>Use this code to reset your FlareWeather password:</p>"
        f"<p style='font-size:20px;font-weight:bold;letter-spacing:4px;'>{code}</p>"
        "<p>This code expires in 30 minutes. If you didn’t request it, you can safely ignore this email.</p>"
        "<p>— The FlareWeather Team</p>"
    )

    url = f"{MAILGUN_API_BASE_URL}/{MAILGUN_DOMAIN}/messages"
    data = {
        "from": MAILGUN_FROM_EMAIL,
        "to": email,
        "subject": subject,
        "text": text_body,
        "html": html_body,
    }

    try:
        print(f"📧 Mailgun: Preparing to send email to {email}")
        print(f"📧 Mailgun: URL: {url}, Domain: {MAILGUN_DOMAIN}, From: {MAILGUN_FROM_EMAIL}")
        
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                url,
                data=data,
                auth=("api", MAILGUN_API_KEY)
            )

        print(f"📧 Mailgun: Response status: {response.status_code}")
        print(f"📧 Mailgun: Response text: {response.text[:200]}")  # First 200 chars

        if response.status_code >= 400:
            error_msg = f"Mailgun error {response.status_code} when sending reset email to {email}: {response.text}"
            logger.error(error_msg)
            print(f"❌ {error_msg}")
            raise RuntimeError(f"Failed to send password reset email: {response.status_code}")

        print(f"✅ Mailgun: Email sent successfully to {email}")
        if MAILGUN_DEBUG_EMAILS:
            logger.debug("Password reset email sent to %s", email)

    except Exception as exc:
        # TODO: Consider retry/backoff for email sending errors
        raise exc

