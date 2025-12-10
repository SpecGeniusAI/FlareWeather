# Deploy Google Sheets Sync to Railway - Quick Guide

## Your Token

**IMPORTANT**: You need to add your OAuth token from Cloud Shell.

In Cloud Shell, run:
```bash
cat token.json
```

Copy the entire output and add it as `GOOGLE_OAUTH_TOKEN_JSON` in Railway (see Step 2 below).

## Steps to Deploy

### 1. Create New Service in Railway

1. Go to Railway Dashboard → Your project
2. Click "+ New" → "GitHub Repo"
3. Select your FlareWeather repo
4. **Important**: Set the **Root Directory** to `sheets_sync`
5. Click "Deploy"

### 2. Add Environment Variables

Go to your new service → "Variables" tab → Add these:

**Required:**
- `GOOGLE_OAUTH_TOKEN_JSON`: Paste the entire JSON block above (as one line)
- `GOOGLE_SHEET_ID`: `18f5nfH8YsM5vUv5ZUN_KSniGhQAggwRyf-57jOnXLuY`

**Optional:**
- `SYNC_INTERVAL_HOURS`: `1` (default: syncs every hour)
- `GOOGLE_WORKSHEET_NAME`: `Sheet1` (default: first sheet)

### 3. Link PostgreSQL Service

1. In your sync service → "Settings"
2. Under "Service Connections" → "Add Service Connection"
3. Select your PostgreSQL service
4. This automatically sets `DATABASE_URL`

### 4. Deploy

Railway will automatically:
- Install dependencies
- Run the sync service
- It will sync every hour automatically

## Verify It's Working

1. **Check logs**: You should see "🚀 Google Sheets Sync Service Started"
2. **Wait ~1 minute**: First sync happens immediately
3. **Check your Google Sheet**: Should have user data with headers:
   - ID, Email, Name, Created At, Subscription Status, Subscription Plan, Access Type, etc.

## What Gets Synced

Every hour, the service will:
- Fetch all users from your database
- Clear the Google Sheet
- Write fresh data with these columns:
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

## Troubleshooting

- **"Invalid token"**: Make sure you copied the ENTIRE JSON (all on one line, no line breaks)
- **"Permission denied"**: Make sure your Google account has access to the sheet
- **"Database connection failed"**: Make sure you linked the PostgreSQL service
