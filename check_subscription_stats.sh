#!/bin/bash
# Check subscription statistics

RAILWAY_URL="https://flareweather-production.up.railway.app"
ADMIN_KEY="w41c0nDMj5yCynDfa8a5mEDZxV8T0sngmQqMDoun4XU"

echo "🔍 Checking subscription statistics..."
echo ""

curl -X GET "$RAILWAY_URL/admin/subscription-stats" \
  -H "X-Admin-Key: $ADMIN_KEY" \
  -H "Content-Type: application/json" | python3 -m json.tool

echo ""
echo "✅ Done!"
