#!/bin/bash

# Test script to check a user's access status

RAILWAY_URL="https://flareweather-production.up.railway.app"
ADMIN_KEY="w41c0nDMj5yCynDfa8a5mEDZxV8T0sngmQqMDoun4XU"
USER_EMAIL="${1:-test@example.com}"

echo "🔍 Checking access status for: $USER_EMAIL"
echo ""

curl -X GET "$RAILWAY_URL/admin/access-status/$USER_EMAIL" \
  -H "X-Admin-Key: $ADMIN_KEY" | python3 -m json.tool
