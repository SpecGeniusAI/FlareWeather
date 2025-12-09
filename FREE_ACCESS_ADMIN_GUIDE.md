# Free Access Admin Guide

This guide explains how to grant free access to users for a specified period of time.

## Setup

1. **Set Admin API Key** (recommended for production):
   ```bash
   export ADMIN_API_KEY="your-secret-admin-key-here"
   ```
   
   If `ADMIN_API_KEY` is not set, the admin endpoints will be accessible without authentication (development mode only).

2. **Database Migration**:
   The database will automatically migrate when the backend starts, adding:
   - `free_access_enabled` (boolean)
   - `free_access_expires_at` (datetime, nullable)

## API Endpoints

### 1. Grant Free Access

**Endpoint:** `POST /admin/grant-free-access`

**Headers:**
- `X-Admin-Key: your-admin-key` (or use `?admin_key=your-admin-key` query param)

**Request Body:**
```json
{
  "user_identifier": "user@example.com",  // or user_id
  "days": 30,  // Optional: number of days (None = never expires)
  "expires_at": "2024-12-31T23:59:59Z"  // Optional: ISO datetime (overrides days)
}
```

**Example with cURL:**
```bash
# Grant 30 days of free access
curl -X POST "http://localhost:8000/admin/grant-free-access" \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: your-admin-key" \
  -d '{
    "user_identifier": "user@example.com",
    "days": 30
  }'

# Grant access that never expires
curl -X POST "http://localhost:8000/admin/grant-free-access" \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: your-admin-key" \
  -d '{
    "user_identifier": "user@example.com"
  }'

# Grant access until specific date
curl -X POST "http://localhost:8000/admin/grant-free-access" \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: your-admin-key" \
  -d '{
    "user_identifier": "user@example.com",
    "expires_at": "2024-12-31T23:59:59Z"
  }'
```

**Response:**
```json
{
  "success": true,
  "message": "Free access granted successfully. Expires: 2024-12-31T23:59:59",
  "user_id": "abc123",
  "email": "user@example.com",
  "free_access_enabled": true,
  "free_access_expires_at": "2024-12-31T23:59:59"
}
```

### 2. Revoke Free Access

**Endpoint:** `POST /admin/revoke-free-access`

**Headers:**
- `X-Admin-Key: your-admin-key` (or use `?admin_key=your-admin-key` query param)

**Request Body:**
```json
{
  "user_identifier": "user@example.com"  // or user_id
}
```

**Example with cURL:**
```bash
curl -X POST "http://localhost:8000/admin/revoke-free-access" \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: your-admin-key" \
  -d '{
    "user_identifier": "user@example.com"
  }'
```

### 3. Check Access Status

**Endpoint:** `GET /admin/access-status/{user_identifier}`

**Headers:**
- `X-Admin-Key: your-admin-key` (or use `?admin_key=your-admin-key` query param)

**Example with cURL:**
```bash
curl -X GET "http://localhost:8000/admin/access-status/user@example.com" \
  -H "X-Admin-Key: your-admin-key"
```

**Response:**
```json
{
  "user_id": "abc123",
  "email": "user@example.com",
  "has_access": true,
  "access_type": "free",  // "subscription" | "free" | "none"
  "expires_at": "2024-12-31T23:59:59",
  "is_expired": false
}
```

## How It Works

1. **Free Access Priority**: Free access is checked first, then subscription access
2. **Expiration**: If `free_access_expires_at` is `None`, access never expires
3. **Access Check**: The `has_active_access()` function in `access_utils.py` checks:
   - Free access (if enabled and not expired)
   - Subscription access (if active and not expired)

## Using in Your Code

To check if a user has access in your endpoints:

```python
from access_utils import has_active_access

@app.get("/some-endpoint")
async def some_endpoint(user_id: str, db: Session = Depends(get_db)):
    if not has_active_access(db, user_id):
        raise HTTPException(status_code=403, detail="Access required")
    # ... rest of your code
```

## Security Notes

- **Always set `ADMIN_API_KEY` in production** - without it, anyone can grant/revoke access
- Use a strong, random key (e.g., `openssl rand -hex 32`)
- Consider rate limiting these endpoints
- Log all admin actions for audit purposes

## Examples

### Grant 7-day trial to a new user
```bash
curl -X POST "http://localhost:8000/admin/grant-free-access" \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: your-admin-key" \
  -d '{"user_identifier": "newuser@example.com", "days": 7}'
```

### Grant lifetime access to a beta tester
```bash
curl -X POST "http://localhost:8000/admin/grant-free-access" \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: your-admin-key" \
  -d '{"user_identifier": "beta@example.com"}'
```

### Check if user still has access
```bash
curl -X GET "http://localhost:8000/admin/access-status/beta@example.com" \
  -H "X-Admin-Key: your-admin-key"
```
