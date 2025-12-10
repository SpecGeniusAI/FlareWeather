# OAuth Setup Guide (For Organizations with Key Restrictions)

Since your organization blocks service account key creation, we'll use OAuth 2.0 instead. This is actually more secure!

## Step 1: Create OAuth Credentials (5 minutes)

1. **Go to Google Cloud Console**: https://console.cloud.google.com/
2. **Select your project** (the one you created earlier)
3. **Go to APIs & Services** → **Credentials** (left menu)
4. **Click "Create Credentials"** → **"OAuth client ID"**
5. **If prompted, configure OAuth consent screen first**:
   - User Type: "External" (unless you have Google Workspace)
   - App name: "FlareWeather Sheets Sync"
   - User support email: Your email
   - Developer contact: Your email
   - Click "Save and Continue"
   - Scopes: Click "Add or Remove Scopes"
     - Search for "spreadsheets"
     - Select "https://www.googleapis.com/auth/spreadsheets"
     - Click "Update" → "Save and Continue"
   - Test users: Add your email
   - Click "Save and Continue" → "Back to Dashboard"
6. **Now create OAuth client ID**:
   - Application type: **"Desktop app"**
   - Name: "FlareWeather Sheets Sync"
   - Click "Create"
7. **Download the JSON file**:
   - Click the download icon next to your new OAuth client
   - Save it as `credentials.json`

## Step 2: Run the OAuth Setup Script (2 minutes)

1. **Put `credentials.json` in the `sheets_sync/` folder**
2. **Run the setup script**:
   ```bash
   cd sheets_sync
   python oauth_setup.py
   ```
3. **A browser window will open**:
   - Sign in with your Google account
   - Click "Allow" to grant access
4. **A `token.json` file will be created**

## Step 3: Add Token to Railway

1. **Open `token.json`** (created in step 2)
2. **Copy the entire contents**
3. **Go to Railway** → Your sync service → Variables
4. **Add environment variable**:
   - Name: `GOOGLE_OAUTH_TOKEN_JSON`
   - Value: Paste the entire contents of `token.json`
5. **Also add**:
   - `GOOGLE_SHEET_ID`: `18f5nfH8YsM5vUv5ZUN_KSniGhQAggwRyf-57jOnXLuY`
   - `DATABASE_URL`: (Railway should auto-set this)

## Step 4: Deploy

The sync service will now use OAuth instead of service account keys!

## Benefits of OAuth

- ✅ Works with organization policies
- ✅ More secure (no long-lived keys)
- ✅ Can be revoked easily
- ✅ Better audit trail

## Troubleshooting

- **"Access blocked"**: Make sure you added your email as a test user in OAuth consent screen
- **"Invalid credentials"**: Make sure you copied the entire token.json contents
- **Token expires**: The refresh token should auto-refresh, but if it fails, re-run oauth_setup.py
