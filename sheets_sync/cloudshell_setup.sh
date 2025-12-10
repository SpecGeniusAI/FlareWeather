#!/bin/bash
# Google Cloud Shell setup script for OAuth credentials
# Run this in Cloud Shell to set up Google Sheets API access

echo "🚀 Setting up Google Sheets OAuth for FlareWeather"
echo "=================================================="
echo ""

# Check if gcloud is available
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI not found. Please run this in Google Cloud Shell."
    exit 1
fi

# Set the project
PROJECT_ID=$(gcloud config get-value project)
echo "📋 Using project: $PROJECT_ID"
echo ""

# Enable Google Sheets API
echo "1️⃣ Enabling Google Sheets API..."
gcloud services enable sheets.googleapis.com
echo "✅ Google Sheets API enabled"
echo ""

# Create OAuth consent screen (if not already configured)
echo "2️⃣ Configuring OAuth consent screen..."
echo "   (This may prompt you for information)"
echo ""

# Check if consent screen exists
CONSENT_SCREEN=$(gcloud alpha iap oauth-clients list 2>/dev/null)

# Create OAuth client ID
echo "3️⃣ Creating OAuth client ID..."
echo "   Application type: Desktop app"
echo "   Name: FlareWeather Sheets Sync"
echo ""

# Create the OAuth client
CLIENT_OUTPUT=$(gcloud alpha iap oauth-clients create \
    --display_name="FlareWeather Sheets Sync" \
    --application_type=DESKTOP 2>&1)

if [ $? -eq 0 ]; then
    echo "✅ OAuth client created!"
    echo ""
    echo "$CLIENT_OUTPUT"
    echo ""
    echo "📋 Next steps:"
    echo "1. The OAuth client has been created"
    echo "2. You'll need to download the credentials from the web console:"
    echo "   https://console.cloud.google.com/apis/credentials?project=$PROJECT_ID"
    echo "3. Look for 'FlareWeather Sheets Sync' in the OAuth 2.0 Client IDs section"
    echo "4. Click the download icon to get the JSON file"
    echo "5. Save it as 'credentials.json'"
else
    echo "⚠️  Could not create via CLI. Please create manually:"
    echo "   https://console.cloud.google.com/apis/credentials?project=$PROJECT_ID"
    echo "   Click 'Create Credentials' > 'OAuth client ID' > 'Desktop app'"
fi

echo ""
echo "✅ Setup complete! Follow the next steps above."
