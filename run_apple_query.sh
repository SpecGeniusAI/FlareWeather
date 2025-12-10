#!/bin/bash
# Script to run the Apple subscription query on Railway
# This can be run as a one-time task or scheduled job

echo "🔍 Querying Apple App Store Server API for subscription status..."
echo ""

# Make sure we're in the right directory
cd "$(dirname "$0")"

# Run the Python script
python3 query_apple_subscriptions.py

echo ""
echo "✅ Query complete!"
