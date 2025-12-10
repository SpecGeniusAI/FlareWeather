# Cloud Shell Setup Guide

Since you have Cloud Shell open, here's the easiest way to set up OAuth:

## Quick Setup (Copy & Paste into Cloud Shell)

### Step 1: Enable Google Sheets API

```bash
gcloud services enable sheets.googleapis.com
```

### Step 2: Create OAuth Credentials via Web Console

The easiest way is still through the web console:

1. **Click this link** (opens in new tab):
   https://console.cloud.google.com/apis/credentials?project=flareweather-480723

2. **Click "Create Credentials"** → **"OAuth client ID"**

3. **If it asks to configure consent screen**:
   - Click "Configure Consent Screen"
   - User Type: "External"
   - App name: "FlareWeather Sheets Sync"
   - Your email for support
   - Click through the steps
   - Add your email as a test user
   - Click "Save and Continue"

4. **Create OAuth client**:
   - Application type: **"Desktop app"**
   - Name: "FlareWeather Sheets Sync"
   - Click "Create"

5. **Download the JSON**:
   - Click the download icon (⬇️) next to your new OAuth client
   - The file downloads as something like `client_secret_xxxxx.json`
   - Rename it to `credentials.json`

### Step 3: Upload credentials.json to Cloud Shell

1. In Cloud Shell, click the **three dots menu** (⋮) → **Upload file**
2. Select your `credentials.json` file
3. It will upload to your Cloud Shell home directory

### Step 4: Run OAuth Setup

```bash
# Install required packages
pip3 install google-auth google-auth-oauthlib google-auth-httplib2 google-api-python-client

# Download the sync script (or I can provide it)
# Then run:
python3 oauth_setup.py
```

This will:
- Open a browser for you to authorize
- Create a `token.json` file
- You can then copy that token to Railway

## Alternative: I can create a simpler script

If you want, I can create a Python script that you can run directly in Cloud Shell that does everything. Just let me know!
