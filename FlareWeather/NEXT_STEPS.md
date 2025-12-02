# Next Steps to Fix TestFlight Issues

## Summary

Your app works on the emulator but not on TestFlight because:
1. **Weather API**: API key is in Xcode scheme (works on emulator) but not in Info.plist (needed for TestFlight)
2. **Backend API**: Bug fix is in code but backend hasn't been redeployed yet

## What Needs to Be Done

### 1. Add OpenWeatherMap API Key to Info.plist (5 minutes) ⭐ REQUIRED

**In Xcode:**
1. Open Xcode
2. Select **FlareWeather** project (blue icon at top)
3. Select **FlareWeather** target (under TARGETS)
4. Click **Info** tab
5. Scroll to "Custom iOS Target Properties" section
6. Click **+** button to add a new row
7. Set:
   - **Key**: `OpenWeatherAPIKey` (exactly this, case-sensitive)
   - **Type**: `String`
   - **Value**: `your_actual_api_key_here` (paste your OpenWeatherMap API key)
8. Save (Cmd+S)

**Get Your API Key:**
- Go to https://openweathermap.org/api
- Sign in or create account
- Go to API keys section
- Copy your API key

**Verify:**
- Build the app (Cmd+B)
- Check console for: `✅ WeatherService: API key found in Info.plist`
- If you see `⚠️ WeatherService: No API key found`, check the key name and value

### 2. Redeploy Backend (5 minutes) ⭐ REQUIRED

**The backend fix is already in your code (`app.py` line 547), but needs to be deployed:**

**Option A: Git Push (Recommended)**
```bash
cd /Users/kurtishurrie/Desktop/drive-download-20251021T153533Z-1-001
git add app.py
git commit -m "Fix pressure_alert initialization bug"
git push
```
Railway will auto-deploy.

**Option B: Manual Redeploy**
1. Go to https://railway.app
2. Select FlareWeather project
3. Select backend service
4. Click "Redeploy" or trigger new deployment
5. Wait for deployment to complete

**Verify Backend:**
```bash
# Check health
curl https://flareweather-production.up.railway.app/health
# Should return: {"status":"healthy"}

# Check analyze endpoint
curl -X POST https://flareweather-production.up.railway.app/analyze \
  -H "Content-Type: application/json" \
  -d '{"weather":[{"timestamp":"2024-01-01T00:00:00Z","temperature":20,"humidity":50,"pressure":1013,"wind":10}],"symptoms":[],"diagnoses":["migraine"]}'
# Should return JSON with AI insights, not error about pressure_alert
```

### 3. Rebuild and Upload to TestFlight (10 minutes)

1. **Clean build folder**: `Shift + Cmd + K`
2. **Build**: `Cmd + B` (verify no errors)
3. **Archive**: `Product → Archive`
4. **Upload**: `Distribute App → App Store Connect → TestFlight`

## Expected Results

### After Adding API Key
- ✅ Weather shows real temperature (e.g., 6°C for Victoria, BC)
- ✅ Weather updates correctly
- ✅ No more "Weather API key not configured" error

### After Backend Redeploy
- ✅ AI insights work correctly
- ✅ Shows risk, forecast, and explanations
- ✅ No more "We're having trouble connecting" error
- ✅ No backend errors

## Quick Checklist

- [ ] OpenWeatherMap API key added to Info.plist (Info tab)
- [ ] API key value is correct (not empty)
- [ ] Key name is exactly `OpenWeatherAPIKey` (case-sensitive)
- [ ] Backend redeployed (check Railway dashboard)
- [ ] Backend health check returns 200
- [ ] Backend analyze endpoint returns AI insights (not error)
- [ ] Clean build folder
- [ ] Archive and upload to TestFlight
- [ ] Test on TestFlight device

## Troubleshooting

### Still Seeing "Weather API key not configured"
- Check Info tab in Xcode (not just build settings)
- Verify key name is exactly `OpenWeatherAPIKey` (case-sensitive)
- Verify value is not empty
- Clean and rebuild (Shift+Cmd+K, then Cmd+B)
- Check console logs for API key detection

### Still Seeing "We're having trouble connecting"
- Backend not redeployed yet
- Check Railway dashboard for deployment status
- Verify backend is running
- Check backend logs for errors
- Test backend endpoint with curl (see above)

### API Key Works on Emulator But Not TestFlight
- **Cause**: Environment variables in Xcode scheme are NOT included in TestFlight builds
- **Solution**: You MUST add the API key to Info.plist (Info tab in Xcode)
- **Note**: Info.plist values ARE included in TestFlight builds

## Files Changed

1. **`app.py`**: Fixed `pressure_alert` initialization bug (line 547)
2. **`AIInsightsService.swift`**: Improved error handling and logging
3. **`WeatherService.swift`**: Removed mock data fallback, better error messages
4. **Project configuration**: Backend URL already configured in Info.plist

## Need Help?

1. Check console logs in Xcode for API key detection
2. Check Railway logs for backend errors
3. Verify API key is correct (test OpenWeatherMap API directly)
4. Verify backend URL is correct (test with curl)

