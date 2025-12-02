# Quick Fix for TestFlight Issues

## Two Issues to Fix

### Issue 1: Backend Error (AI Insights)
**Problem**: Backend returns error: "cannot access local variable 'pressure_alert'"
**Status**: Fix is ready in code, but backend needs to be redeployed
**Solution**: Redeploy backend to Railway

### Issue 2: Weather API Key Missing (Weather Data)
**Problem**: Weather shows 22°C (mock data) instead of real weather
**Status**: API key is in Xcode scheme (works on emulator) but not in Info.plist (needed for TestFlight)
**Solution**: Add API key to Info.plist in Xcode

---

## Fix 1: Redeploy Backend (5 minutes)

### Option A: Git Push (if using Git integration)
```bash
cd /Users/kurtishurrie/Desktop/drive-download-20251021T153533Z-1-001
git add app.py
git commit -m "Fix pressure_alert initialization bug"
git push
```
Railway will auto-deploy.

### Option B: Manual Redeploy in Railway
1. Go to https://railway.app
2. Select your FlareWeather project
3. Select the backend service
4. Click "Deployments" → "Redeploy"
5. Wait for deployment to complete

### Verify Backend is Fixed
```bash
curl -X POST https://flareweather-production.up.railway.app/analyze \
  -H "Content-Type: application/json" \
  -d '{"weather":[{"timestamp":"2024-01-01T00:00:00Z","temperature":20,"humidity":50,"pressure":1013,"wind":10}],"symptoms":[],"diagnoses":["migraine"]}'
```

Should return AI insights (JSON) instead of error.

---

## Fix 2: Add OpenWeatherMap API Key to Info.plist (5 minutes)

### Step 1: Get Your API Key
1. Go to https://openweathermap.org/api
2. Sign in (or create account)
3. Go to API keys section
4. Copy your API key

### Step 2: Add to Xcode Info.plist
1. Open Xcode
2. Select **FlareWeather** project (blue icon)
3. Select **FlareWeather** target (under TARGETS)
4. Click **Info** tab
5. Scroll to "Custom iOS Target Properties" section
6. Click the **+** button
7. Add new key:
   - **Key**: `OpenWeatherAPIKey` (exactly this, case-sensitive)
   - **Type**: `String`
   - **Value**: `your_api_key_here` (paste your actual API key)
8. Make sure it's visible for both Debug and Release
9. Save (Cmd+S)

### Step 3: Verify
1. Build the app (Cmd+B)
2. Check console logs for:
   - `✅ WeatherService: API key found in Info.plist`
3. If you see `⚠️ WeatherService: No API key found`, check:
   - Key name is exactly `OpenWeatherAPIKey`
   - Value is not empty
   - It's in the Info tab (not just build settings)

### Step 4: Archive and Upload
1. Clean build folder (Shift+Cmd+K)
2. Archive (Product → Archive)
3. Upload to TestFlight

---

## Expected Results After Fix

### Weather Data
- ✅ Shows real weather (e.g., 6°C for Victoria, BC)
- ✅ Updates correctly
- ✅ No more "Weather API key not configured" error

### AI Insights
- ✅ Returns real AI insights
- ✅ No more "We're having trouble connecting" error
- ✅ Shows risk, forecast, and explanations

---

## Troubleshooting

### Still Seeing "Weather API key not configured"
1. Verify key is in Info tab (not just build settings)
2. Verify key name is exactly `OpenWeatherAPIKey` (case-sensitive)
3. Verify value is not empty
4. Clean and rebuild (Shift+Cmd+K, then Cmd+B)
5. Check console logs for API key detection

### Still Seeing "We're having trouble connecting"
1. Check if backend is deployed:
   ```bash
   curl https://flareweather-production.up.railway.app/health
   ```
   Should return: `{"status":"healthy"}`
2. Check if backend fix is deployed:
   ```bash
   curl -X POST https://flareweather-production.up.railway.app/analyze \
     -H "Content-Type: application/json" \
     -d '{"weather":[{"timestamp":"2024-01-01T00:00:00Z","temperature":20,"humidity":50,"pressure":1013,"wind":10}],"symptoms":[]}'
   ```
   Should return JSON with AI insights, not error

### API Key Works in Emulator but Not TestFlight
- **Cause**: Environment variables in Xcode scheme are NOT included in TestFlight builds
- **Solution**: You MUST add the API key to Info.plist (Info tab in Xcode)
- **Note**: Info.plist values ARE included in TestFlight builds

---

## Quick Checklist

- [ ] Backend redeployed (check Railway dashboard)
- [ ] Backend health check returns 200
- [ ] OpenWeatherMap API key added to Info.plist (Info tab)
- [ ] API key value is not empty
- [ ] Key name is exactly `OpenWeatherAPIKey`
- [ ] Clean build folder (Shift+Cmd+K)
- [ ] Archive and upload to TestFlight
- [ ] Test on TestFlight device

---

## Need Help?

1. Check console logs in Xcode for API key detection
2. Check Railway logs for backend errors
3. Verify API key is correct (test with curl)
4. Verify backend URL is correct

