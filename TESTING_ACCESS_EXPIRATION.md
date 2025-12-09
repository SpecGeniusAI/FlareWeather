# Testing Access Expiration in iOS Simulator

This guide explains how to test the access expiration flow in the iOS simulator.

## Prerequisites

1. **Push backend changes to Railway** (if not already done)
2. **Have a test user account** (or use your own email)

## Method 1: Grant Expired Access (Recommended)

This simulates a user whose free access has already expired.

### Step 1: Grant access with past expiration date

Run the test script:

```bash
./test_expired_access.sh your-test-email@example.com
```

Or manually:

```bash
# Set expiration to 1 day ago
curl -X POST "https://flareweather-production.up.railway.app/admin/grant-free-access" \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: w41c0nDMj5yCynDfa8a5mEDZxV8T0sngmQqMDoun4XU" \
  -d '{
    "user_identifier": "your-test-email@example.com",
    "expires_at": "2024-01-01T00:00:00Z"
  }'
```

### Step 2: Verify access is expired

```bash
./test_access_status.sh your-test-email@example.com
```

You should see:
```json
{
  "has_access": false,
  "access_type": "none",
  "is_expired": true
}
```

### Step 3: Test in iOS Simulator

1. **Login** with the test email in the iOS app
2. **Check `/auth/me` endpoint** - should return:
   ```json
   {
     "has_access": false,
     "access_required": true,
     "access_expired": true,
     "logout_message": "Logout to see basic insights"
   }
   ```
3. **The popup should appear** when the app checks access status
4. **Verify the popup shows:**
   - "Free Access Has Ended" title
   - Message about expired access
   - "Subscribe" button
   - "Logout" button
   - "Logout to see basic insights" text under logout button

## Method 2: Grant Short-Term Access

Grant access that expires in 1 minute, then wait:

```bash
curl -X POST "https://flareweather-production.up.railway.app/admin/grant-free-access" \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: w41c0nDMj5yCynDfa8a5mEDZxV8T0sngmQqMDoun4XU" \
  -d '{
    "user_identifier": "your-test-email@example.com",
    "days": 0
  }'
```

Then set expiration to past:
```bash
# Calculate 1 minute ago
EXPIRES_AT=$(python3 -c "from datetime import datetime, timedelta; print((datetime.utcnow() - timedelta(minutes=1)).strftime('%Y-%m-%dT%H:%M:%SZ'))")

curl -X POST "https://flareweather-production.up.railway.app/admin/grant-free-access" \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: w41c0nDMj5yCynDfa8a5mEDZxV8T0sngmQqMDoun4XU" \
  -d "{
    \"user_identifier\": \"your-test-email@example.com\",
    \"expires_at\": \"$EXPIRES_AT\"
  }"
```

## Method 3: Test with Different Scenarios

### Scenario A: User with Active Free Access
```bash
curl -X POST "https://flareweather-production.up.railway.app/admin/grant-free-access" \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: w41c0nDMj5yCynDfa8a5mEDZxV8T0sngmQqMDoun4XU" \
  -d '{
    "user_identifier": "test-active@example.com",
    "days": 30
  }'
```
**Expected:** No popup, full access

### Scenario B: User with Expired Free Access
```bash
./test_expired_access.sh test-expired@example.com
```
**Expected:** Popup appears with "Free Access Has Ended"

### Scenario C: User with No Access
```bash
# Just login normally (don't grant access)
```
**Expected:** Popup appears with "Access Required"

## Testing Checklist

- [ ] User with expired access sees popup
- [ ] Popup shows correct title ("Free Access Has Ended" or "Access Required")
- [ ] Popup shows correct message
- [ ] "Logout to see basic insights" text appears under logout button
- [ ] Subscribe button navigates to subscription screen
- [ ] Logout button logs out user and shows basic insights
- [ ] `/auth/me` returns correct access status
- [ ] `/analyze` returns `access_required: true` and `access_expired: true`
- [ ] `/user/access-status` returns correct status

## Debugging

### Check API Response

Test the endpoints directly:

```bash
# Check /auth/me (requires authentication token)
curl -X GET "https://flareweather-production.up.railway.app/auth/me" \
  -H "Authorization: Bearer YOUR_TOKEN"

# Check /user/access-status (requires authentication token)
curl -X GET "https://flareweather-production.up.railway.app/user/access-status" \
  -H "Authorization: Bearer YOUR_TOKEN"

# Check /admin/access-status (admin only)
curl -X GET "https://flareweather-production.up.railway.app/admin/access-status/test@example.com" \
  -H "X-Admin-Key: w41c0nDMj5yCynDfa8a5mEDZxV8T0sngmQqMDoun4XU"
```

### Common Issues

1. **Popup doesn't appear:**
   - Check if iOS app is calling `/auth/me` on launch
   - Verify `access_required` flag is being checked
   - Check console logs for API responses

2. **Wrong message:**
   - Verify `access_expired` flag is set correctly
   - Check if user actually had free access before

3. **Access status incorrect:**
   - Use admin endpoint to verify database state
   - Check timezone issues (expiration dates are UTC)

## Reset Test User

To reset a test user's access:

```bash
# Revoke free access
curl -X POST "https://flareweather-production.up.railway.app/admin/revoke-free-access" \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: w41c0nDMj5yCynDfa8a5mEDZxV8T0sngmQqMDoun4XU" \
  -d '{
    "user_identifier": "test@example.com"
  }'
```

## Quick Test Commands

```bash
# 1. Grant expired access
./test_expired_access.sh your-email@example.com

# 2. Check status
./test_access_status.sh your-email@example.com

# 3. Test in iOS app (login with that email)

# 4. Reset when done
curl -X POST "https://flareweather-production.up.railway.app/admin/revoke-free-access" \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: w41c0nDMj5yCynDfa8a5mEDZxV8T0sngmQqMDoun4XU" \
  -d "{\"user_identifier\": \"your-email@example.com\"}"
```
