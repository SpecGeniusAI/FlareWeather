# Simple Google Sheets Setup - Step by Step

## What You Need to Do

### 1. Get the Service Account Email (5 minutes)

1. Go to: https://console.cloud.google.com/
2. Click "Select a project" → "New Project"
   - Name: `FlareWeather`
   - Click "Create"
3. Wait for project to be created, then:
   - In the search bar (top), type: `Google Sheets API`
   - Click "Google Sheets API" → Click "Enable"
4. Left menu: "IAM & Admin" → "Service Accounts"
5. Click "Create Service Account"
   - Name: `sheets-sync`
   - Click "Create and Continue"
   - Click "Continue" (skip role)
   - Click "Done"
6. Click on the service account you just created
7. Go to "Keys" tab → "Add Key" → "Create new key"
   - Choose "JSON" → Click "Create"
   - **A file downloads - open it!**
8. In the JSON file, find `"client_email"` - copy that email address
   - It looks like: `sheets-sync@flareweather-123456.iam.gserviceaccount.com`

### 2. Share Your Google Sheet (1 minute)

1. Open your sheet: https://docs.google.com/spreadsheets/d/18f5nfH8YsM5vUv5ZUN_KSniGhQAggwRyf-57jOnXLuY
2. Click "Share" (top right)
3. Paste the email from step 1
4. Make sure it says "Editor" (not Viewer)
5. Click "Send"

### 3. Give Me the JSON File

1. Open the JSON file you downloaded in step 1
2. Copy the entire contents
3. Send it to me (I'll help you add it to Railway securely)

**That's it!** Once I have the JSON, I'll set up the sync service.
