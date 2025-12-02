# Check Backend Status from Xcode

## Railway Logs (Backend) - Web Dashboard

Railway logs are **NOT in Xcode**. They're in the Railway web dashboard:

1. **Go to**: https://railway.app
2. **Login** to your account
3. **Open your project**: `flareweather-production`
4. **Click on your service** (the main app, not PostgreSQL)
5. **Click "Logs" tab** (or "View Logs")
6. **Watch in real-time** as you make requests

## Check from Xcode Console (iOS App Side)

You can check if the backend is responding from your iOS app:

### Step 1: Run the App in Xcode

1. **Open Xcode**
2. **Run your app** (⌘R)
3. **Open the Console** (View → Debug Area → Activate Console, or ⌘⇧C)

### Step 2: Watch for Backend Connection Messages

When the app tries to connect to the backend, you'll see:

**If backend is working:**
```
✅ AIInsightsService: Backend URL found in environment variable: https://flareweather-production.up.railway.app
📤 Sending request to: https://flareweather-production.up.railway.app/analyze
📥 Response status: 200
✅ Success! Received insight
```

**If backend is NOT working:**
```
✅ AIInsightsService: Backend URL found in environment variable: https://flareweather-production.up.railway.app
📤 Sending request to: https://flareweather-production.up.railway.app/analyze
❌ Error: The operation couldn't be completed. (NSURLErrorDomain error -1004.)
```

### Step 3: Test Login

1. **Go to login screen** in your app
2. **Try to login**
3. **Watch Xcode console** for:

**If backend is working:**
```
✅ AuthService: Backend URL found in environment variable: https://flareweather-production.up.railway.app
📤 Login request to: https://flareweather-production.up.railway.app/auth/login
📥 Login response status: 401  (or 200 if credentials are correct)
```

**If backend is NOT working:**
```
✅ AuthService: Backend URL found in environment variable: https://flareweather-production.up.railway.app
📤 Login request to: https://flareweather-production.up.railway.app/auth/login
❌ Error: The operation couldn't be completed. (NSURLErrorDomain error -1004.)
```

## Quick Test from Terminal (Mac)

You can also test from your Mac terminal:

```bash
# Test health endpoint
curl https://flareweather-production.up.railway.app/health

# Test login endpoint (should return 401, not 404)
curl -X POST https://flareweather-production.up.railway.app/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test"}'
```

## What the Errors Mean

### 502 Bad Gateway
- Railway can't reach your app
- App might be crashing
- Check Railway logs

### 404 Not Found
- Route doesn't exist
- App deployed but routes not registered
- Need to redeploy

### 401 Unauthorized
- Route exists! ✅
- Just authentication failed (expected for wrong credentials)

### Connection Error (iOS)
- Can't connect to backend
- Backend might be down
- Check Railway logs

## Summary

- **Railway Logs**: Check in Railway web dashboard (not Xcode)
- **Xcode Console**: Shows iOS app's view of backend (connection errors, responses)
- **Terminal**: Test backend directly from your Mac

