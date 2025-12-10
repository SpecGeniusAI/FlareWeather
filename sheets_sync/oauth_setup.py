#!/usr/bin/env python3
"""
One-time OAuth setup script for Google Sheets API
Run this once to get a refresh token, then use it for automated syncing
"""
import os
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
import json

# Scopes needed for Google Sheets
SCOPES = ['https://www.googleapis.com/auth/spreadsheets']

def setup_oauth():
    """Interactive OAuth setup - run this once"""
    creds = None
    
    # Check if we already have credentials
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
    
    # If there are no (valid) credentials available, let the user log in
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            # You'll need to create OAuth 2.0 credentials in Google Cloud Console
            # Go to: APIs & Services > Credentials > Create Credentials > OAuth client ID
            # Application type: Desktop app
            # Download the JSON file and save it as 'credentials.json'
            
            if not os.path.exists('credentials.json'):
                print("❌ credentials.json not found!")
                print("\n📋 To create it:")
                print("1. Go to: https://console.cloud.google.com/apis/credentials")
                print("2. Click 'Create Credentials' > 'OAuth client ID'")
                print("3. Application type: 'Desktop app'")
                print("4. Name it: 'FlareWeather Sheets Sync'")
                print("5. Click 'Create'")
                print("6. Download the JSON file")
                print("7. Save it as 'credentials.json' in this directory")
                return None
            
            flow = InstalledAppFlow.from_client_secrets_file(
                'credentials.json', SCOPES)
            creds = flow.run_local_server(port=0)
        
        # Save the credentials for the next run
        with open('token.json', 'w') as token:
            token.write(creds.to_json())
    
    return creds

if __name__ == '__main__':
    print("🔐 Google Sheets OAuth Setup")
    print("=" * 50)
    creds = setup_oauth()
    
    if creds:
        print("\n✅ OAuth setup complete!")
        print("\n📋 Next steps:")
        print("1. Copy the contents of 'token.json'")
        print("2. Add it to Railway as environment variable: GOOGLE_OAUTH_TOKEN_JSON")
        print("\nThe token.json file contains your refresh token for automated access.")
    else:
        print("\n❌ Setup failed. Please follow the instructions above.")
