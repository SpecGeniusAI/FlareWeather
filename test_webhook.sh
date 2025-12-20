#!/bin/bash
# Test if the App Store webhook endpoint is accessible

RAILWAY_URL="https://flareweather-production.up.railway.app"

echo "🔍 Testing App Store webhook endpoint..."
echo ""

# Test if endpoint exists (should return 202 or 400, not 404)
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$RAILWAY_URL/apple-notifications" \
  -H "Content-Type: application/json" \
  -d '{"signedPayload": "test"}')

echo "Response code: $response"

if [ "$response" = "400" ]; then
    echo "✅ Endpoint is accessible (400 = bad request, but endpoint exists)"
elif [ "$response" = "404" ]; then
    echo "❌ Endpoint not found (404) - webhook path might be wrong"
else
    echo "⚠️  Unexpected response: $response"
fi

echo ""
echo "💡 Apple only sends notifications for NEW subscriptions after webhook is configured."
echo "   Existing subscriptions won't trigger notifications."
echo "   We need to manually sync existing subscriptions."
