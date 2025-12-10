# Google Sheets Sync Service

This service syncs user data from your PostgreSQL database to Google Sheets every hour.

## Setup Instructions

### Step 1: Get Google Service Account Credentials

1. **Go to Google Cloud Console**: https://console.cloud.google.com/

2. **Create or Select a Project**:
   - Click the project dropdown at the top
   - Click "New Project"
   - Name it "FlareWeather" (or any name)
   - Click "Create"

3. **Enable Google Sheets API**:
   - In the search bar, type "Google Sheets API"
   - Click on "Google Sheets API"
   - Click "Enable"

4. **Create Service Account**:
   - In the left menu, go to "IAM & Admin" → "Service Accounts"
   - Click "Create Service Account"
   - Name: `sheets-sync`
   - Click "Create and Continue"
   - Skip the role assignment (click "Continue")
   - Click "Done"

5. **Create Key**:
   - Click on the service account you just created
   - Go to the "Keys" tab
   - Click "Add Key" → "Create new key"
   - Choose "JSON"
   - Click "Create"
   - A JSON file will download - **keep this file safe!**

6. **Share Google Sheet with Service Account**:
   - Open your Google Sheet: https://docs.google.com/spreadsheets/d/18f5nfH8YsM5vUv5ZUN_KSniGhQAggwRyf-57jOnXLuY
   - Click the "Share" button (top right)
   - In the JSON file you downloaded, find the `client_email` field (looks like `xxx@xxx.iam.gserviceaccount.com`)
   - Copy that email address
   - Paste it in the "Share" dialog
   - Give it "Editor" access
   - Click "Send"

### Step 2: Add Environment Variables to Railway

1. **Go to Railway Dashboard** → Your project → New Service (or add to existing)

2. **Add these environment variables**:

   - `GOOGLE_SHEET_ID`: `18f5nfH8YsM5vUv5ZUN_KSniGhQAggwRyf-57jOnXLuY`
   - `GOOGLE_SERVICE_ACCOUNT_JSON`: Paste the entire contents of the JSON file you downloaded
   - `DATABASE_URL`: (Railway should auto-set this if you link the PostgreSQL service)
   - `SYNC_INTERVAL_HOURS`: `1` (optional, defaults to 1 hour)

### Step 3: Deploy to Railway

1. **Create a new service in Railway**:
   - Click "+ New" → "GitHub Repo" (or "Empty Service")
   - Connect your repo
   - Set the root directory to `sheets_sync/` (if deploying separately)
   - Or add this as a worker in your existing backend service

2. **Set the start command**:
   ```
   python sync_to_sheets.py
   ```

3. **Deploy**

## What Gets Synced

The following user data is synced to Google Sheets:

- User ID
- Email
- Name
- Created At
- Subscription Status
- Subscription Plan
- Access Type (subscription/free/none)
- Free Access Enabled
- Free Access Expires At
- Has Diagnoses
- Apple User ID

## How It Works

- Runs continuously
- Syncs every hour (configurable)
- Clears the sheet and writes fresh data each time
- Updates the same sheet (doesn't create new ones)

## Troubleshooting

- **"Permission denied"**: Make sure you shared the sheet with the service account email
- **"API not enabled"**: Make sure Google Sheets API is enabled in Google Cloud Console
- **"Invalid credentials"**: Check that GOOGLE_SERVICE_ACCOUNT_JSON is set correctly (entire JSON as a string)
