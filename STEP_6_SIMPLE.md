# Step 6: Add Backend URL - Simple Guide

## ✅ Your Backend is Running!
Tested: `https://flareweather-production.up.railway.app/health` ✅

## Quick Method: Environment Variable (2 minutes)

### Steps:

1. **Open Xcode**

2. **Edit Scheme**:
   - At the top, click the scheme selector (next to ▶️ Stop button)
   - Choose **"Edit Scheme..."**

3. **Go to "Run" → "Arguments" tab**

4. **Find "Environment Variables" section**

5. **Click the "+" button**

6. **Add this**:
   ```
   Name:  BACKEND_URL
   Value: https://flareweather-production.up.railway.app
   ```
   ☑️ Make sure the checkbox is checked

7. **Click "Close"**

8. **Run your app** (⌘R)

9. **Check the console** - you should see:
   ```
   ✅ AIInsightsService: Backend URL found in environment variable: https://flareweather-production.up.railway.app
   ```

## That's It! 🎉

Your app will now connect to Railway instead of localhost.

## Test It

1. Run the app
2. Go to Home screen
3. Check if AI insights load
4. Check console for connection messages

## Alternative: Info.plist (For Production)

If you want a permanent configuration:

1. **Select your project** in Xcode (blue icon)
2. **Select "FlareWeather" target**
3. **Go to "Info" tab**
4. **Click "+" in "Custom iOS Target Properties"**
5. **Add**:
   - Key: `BackendURL`
   - Value: `https://flareweather-production.up.railway.app`

## Troubleshooting

**Still seeing localhost?**
- Clean build: Product → Clean Build Folder (Shift+⌘+K)
- Quit and restart Xcode
- Make sure the environment variable checkbox is checked

**Backend not connecting?**
- Verify backend is running: `curl https://flareweather-production.up.railway.app/health`
- Check Railway logs for errors
- Verify environment variables are set in Railway

