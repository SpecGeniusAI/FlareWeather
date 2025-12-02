# TestFlight Setup - Quick Reference

## Why It Works on Emulator But Not TestFlight

**Emulator (Development)**:
- Uses environment variables from Xcode scheme
- Variables set in: Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables

**TestFlight (Production)**:
- Does NOT use environment variables from Xcode scheme
- Uses Info.plist values only
- Variables set in: Target → Info tab → Custom iOS Target Properties

## Fix Required

### 1. Add OpenWeatherMap API Key to Info.plist (REQUIRED)

**In Xcode:**
1. Project navigator → Select **FlareWeather** (blue icon)
2. Select **FlareWeather** target (under TARGETS)
3. Click **Info** tab
4. Scroll to "Custom iOS Target Properties"
5. Click **+** button
6. Add:
   - Key: `OpenWeatherAPIKey`
   - Type: `String`
   - Value: `your_api_key_here` (get from https://openweathermap.org/api)
7. Save (Cmd+S)

**Verify:**
- Build the app
- Check console for: `✅ WeatherService: API key found in Info.plist`
- If you see: `⚠️ WeatherService: No API key found` → key is not configured correctly

### 2. Redeploy Backend (REQUIRED)

**Backend has a bug that's already fixed in code but needs deployment:**

**Option A: Git Push (Auto-deploy)**
```bash
cd /Users/kurtishurrie/Desktop/drive-download-20251021T153533Z-1-001
git add app.py
git commit -m "Fix pressure_alert bug"
git push
```

**Option B: Manual Redeploy in Railway**
1. Go to https://railway.app
2. Select FlareWeather project
3. Select backend service
4. Click "Redeploy"

**Verify Backend:**
```bash
curl https://flareweather-production.up.railway.app/health
# Should return: {"status":"healthy"}

curl -X POST https://flareweather-production.up.railway.app/analyze \
  -H "Content-Type: application/json" \
  -d '{"weather":[{"timestamp":"2024-01-01T00:00:00Z","temperature":20,"humidity":50,"pressure":1013,"wind":10}],"symptoms":[],"diagnoses":["migraine"]}'
# Should return JSON with AI insights, not error
```

### 3. Rebuild and Upload to TestFlight

1. Clean build folder: `Shift + Cmd + K`
2. Build: `Cmd + B`
3. Archive: `Product → Archive`
4. Upload to TestFlight: `Distribute App → App Store Connect`

## Checklist

- [ ] OpenWeatherMap API key added to Info.plist (Info tab)
- [ ] API key value is correct (not empty)
- [ ] Backend redeployed (check Railway dashboard)
- [ ] Backend health check returns 200
- [ ] Clean build folder
- [ ] Archive and upload to TestFlight
- [ ] Test on TestFlight device

## Expected Results

**After adding API key:**
- Weather shows real data (not 22°C mock data)
- Location shows correct temperature
- No "Weather API key not configured" error

**After backend redeploy:**
- AI insights work (not "We're having trouble connecting")
- Shows risk, forecast, and explanations
- No backend errors

## Troubleshooting

### "Weather API key not configured"
- API key is not in Info.plist
- Check Info tab in Xcode
- Verify key name is exactly `OpenWeatherAPIKey`
- Verify value is not empty
- Clean and rebuild

### "We're having trouble connecting"
- Backend not redeployed
- Check Railway dashboard
- Verify backend is running
- Check backend logs

### Still seeing mock data (22°C)
- API key not configured correctly
- Check console logs for API key detection
- Verify API key is valid (test with curl)
- Clean and rebuild

