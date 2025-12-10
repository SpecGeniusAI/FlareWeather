# Deploy Google Sheets Sync to Railway

## Step 1: Add Environment Variables to Railway

1. **Go to Railway Dashboard** → Your project
2. **Create a new service** (or add to existing):
   - Click "+ New" → "GitHub Repo" or "Empty Service"
   - If using GitHub, connect your repo
   - Set root directory to `sheets_sync/`

3. **Add these environment variables**:

   **Required:**
   - `GOOGLE_OAUTH_TOKEN_JSON`: Paste the entire token.json contents (from Cloud Shell)
   - `GOOGLE_SHEET_ID`: `18f5nfH8YsM5vUv5ZUN_KSniGhQAggwRyf-57jOnXLuY`
   - `DATABASE_URL`: Railway should auto-set this if you link your PostgreSQL service

   **Optional:**
   - `SYNC_INTERVAL_HOURS`: `1` (default: syncs every hour)
   - `GOOGLE_WORKSHEET_NAME`: `Sheet1` (default: first sheet)

## Step 2: Link PostgreSQL Service

1. In your new sync service, go to "Settings"
2. Under "Service Connections", add your PostgreSQL service
3. This automatically sets `DATABASE_URL`

## Step 3: Deploy

Railway will automatically:
- Install dependencies from `requirements.txt`
- Run `python sync_to_sheets.py`
- The service will sync every hour

## Step 4: Verify It's Working

1. Check the logs in Railway
2. You should see: "🚀 Google Sheets Sync Service Started"
3. After first sync: "✅ Successfully synced X users to Google Sheets"
4. Check your Google Sheet - it should have user data!

## Token JSON to Add

**Get your token from Cloud Shell:**

In Cloud Shell, run:
```bash
cat token.json
```

Copy the entire output (it's a single line of JSON) and paste it as the value for `GOOGLE_OAUTH_TOKEN_JSON` in Railway.

## Troubleshooting

- **"Invalid token"**: Make sure you copied the entire JSON (including all the quotes and brackets)
- **"Permission denied"**: Make sure you shared the Google Sheet with your Google account email
- **"Database connection failed"**: Make sure you linked the PostgreSQL service in Railway
