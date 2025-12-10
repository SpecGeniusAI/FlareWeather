#!/usr/bin/env python3
"""
Create credentials.json from OAuth Client ID and Secret
Run this and paste your Client ID and Secret when prompted
"""
import json

print("🔐 Create credentials.json from OAuth Client")
print("=" * 50)
print()

# Get client ID and secret
client_id = input("Enter your OAuth Client ID: ").strip()
client_secret = input("Enter your OAuth Client Secret: ").strip()

if not client_id or not client_secret:
    print("❌ Client ID and Secret are required!")
    exit(1)

# Create credentials.json structure
credentials = {
    "installed": {
        "client_id": client_id,
        "project_id": "flareweather-480723",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
        "client_secret": client_secret,
        "redirect_uris": ["http://localhost"]
    }
}

# Save to file
with open('credentials.json', 'w') as f:
    json.dump(credentials, f, indent=2)

print()
print("✅ credentials.json created successfully!")
print("   File saved in current directory")
print()
print("📋 Next step: Run 'python3 oauth_setup.py' to get your token")
