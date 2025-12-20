#!/bin/bash

# Test script to grant expired free access to a user
# This simulates a user whose free access has expired

RAILWAY_URL="https://flareweather-production.up.railway.app"
ADMIN_KEY="w41c0nDMj5yCynDfa8a5mEDZxV8T0sngmQqMDoun4XU"
USER_EMAIL="${1:-test@example.com}"

# Set expiration to 1 day ago (simulates expired access)
EXPIRES_AT=$(date -u -v-1d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "1 day ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || python3 -c "from datetime import datetime, timedelta; print((datetime.utcnow() - timedelta(days=1)).strftime('%Y-%m-%dT%H:%M:%SZ'))")

echo "🔧 Granting expired free access to: $USER_EMAIL"
echo "   Expiration date (1 day ago): $EXPIRES_AT"
echo ""

curl -X POST "$RAILWAY_URL/admin/grant-free-access" \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: $ADMIN_KEY" \
  -d "{
    \"user_identifier\": \"$USER_EMAIL\",
    \"expires_at\": \"$EXPIRES_AT\"
  }"

echo ""
echo ""
echo "✅ Done! User $USER_EMAIL now has expired free access."
echo "   Check access status:"
echo "   curl -X GET \"$RAILWAY_URL/admin/access-status/$USER_EMAIL\" -H \"X-Admin-Key: $ADMIN_KEY\""
