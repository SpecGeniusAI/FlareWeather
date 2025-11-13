import time
from typing import Any, Dict

import requests
from jose import jwt
from jose.exceptions import JOSEError


APPLE_KEYS_URL = "https://api.storekit.itunes.apple.com/inApps/v1/notifications/publicKeys"
KEY_CACHE_TTL_SECONDS = 60 * 60  # 1 hour

_cached_keys: Dict[str, str] = {}
_cache_expiry: float = 0.0


class AppleSignatureError(ValueError):
    """Raised when the signed payload from Apple fails verification."""


def _refresh_key_cache() -> None:
    """Fetch and cache Apple's JWK set."""
    global _cached_keys, _cache_expiry

    response = requests.get(APPLE_KEYS_URL, timeout=10)
    response.raise_for_status()

    data = response.json()
    keys = data.get("keys", [])

    updated: Dict[str, str] = {}
    for key in keys:
        kid = key.get("keyId")
        public_key = key.get("publicKey")
        if kid and public_key:
            updated[kid] = public_key

    if not updated:
        raise AppleSignatureError("Apple public key set did not contain usable keys.")

    _cached_keys = updated
    _cache_expiry = time.time() + KEY_CACHE_TTL_SECONDS


def _get_public_key_for_kid(kid: str) -> str:
    """Return the PEM public key matching the provided key ID."""
    current_time = time.time()
    if current_time >= _cache_expiry or kid not in _cached_keys:
        _refresh_key_cache()

    public_key = _cached_keys.get(kid)
    if not public_key:
        # Attempt one more refresh in case Apple rotated keys just now
        _refresh_key_cache()
        public_key = _cached_keys.get(kid)

    if not public_key:
        raise AppleSignatureError(f"No Apple public key found for key id {kid}")

    return public_key


def verify_signed_payload(signed_payload: str) -> Dict[str, Any]:
    """
    Verify Apple's signedPayload from a server notification.

    Returns the decoded JSON claims if the signature is valid.
    Raises AppleSignatureError on any verification issue.
    """
    if not signed_payload:
        raise AppleSignatureError("Signed payload was empty.")

    try:
        header = jwt.get_unverified_header(signed_payload)
    except JOSEError as exc:
        raise AppleSignatureError(f"Invalid JWS header: {exc}") from exc

    kid = header.get("kid")
    if not kid:
        raise AppleSignatureError("JWS header missing key id (kid).")

    public_key = _get_public_key_for_kid(kid)

    try:
        # Apple's keys are EC P-256; python-jose can consume the PEM directly
        return jwt.decode(
            signed_payload,
            key=public_key,
            algorithms=["ES256"],
            options={"verify_aud": False},
        )
    except JOSEError as exc:
        raise AppleSignatureError(f"Apple signature verification failed: {exc}") from exc


