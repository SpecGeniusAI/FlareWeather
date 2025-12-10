# Manual Credentials Setup

Since you have the Client ID, here's how to create credentials.json:

## Option 1: Use the Script (Easiest)

1. **In Cloud Shell, create the script**:
   ```bash
   nano create_credentials.py
   ```
   (Then paste the contents of `create_credentials.py` and save with Ctrl+X, then Y, then Enter)

2. **Run it**:
   ```bash
   python3 create_credentials.py
   ```

3. **When prompted, paste**:
   - Your OAuth Client ID
   - Your OAuth Client Secret (click the eye icon 👁️ to reveal it)

4. **It will create `credentials.json` for you**

## Option 2: Create Manually

1. **Get your Client Secret**:
   - Go back to: https://console.cloud.google.com/apis/credentials?project=flareweather-480723
   - Find your OAuth client "FlareWeather Sheets Sync"
   - Click on it (or the edit icon)
   - You'll see the Client ID and Client Secret
   - Click the eye icon 👁️ to reveal the secret
   - Copy both

2. **Create credentials.json**:
   ```bash
   nano credentials.json
   ```

3. **Paste this** (replace YOUR_CLIENT_ID and YOUR_CLIENT_SECRET):
   ```json
   {
     "installed": {
       "client_id": "YOUR_CLIENT_ID",
       "project_id": "flareweather-480723",
       "auth_uri": "https://accounts.google.com/o/oauth2/auth",
       "token_uri": "https://oauth2.googleapis.com/token",
       "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
       "client_secret": "YOUR_CLIENT_SECRET",
       "redirect_uris": ["http://localhost"]
     }
   }
   ```

4. **Save**: Ctrl+X, then Y, then Enter

## Next Steps

Once you have `credentials.json`:

1. **Install packages**:
   ```bash
   pip3 install google-auth google-auth-oauthlib google-auth-httplib2 google-api-python-client
   ```

2. **Run OAuth setup**:
   ```bash
   python3 oauth_setup.py
   ```

3. **This will**:
   - Open a browser
   - Ask you to authorize
   - Create `token.json`

4. **Copy the contents of `token.json`** and send it to me for Railway!
