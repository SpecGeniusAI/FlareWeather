# Railway 502 Error Troubleshooting

## Current Status
- ✅ Build successful
- ✅ App appears to start (from previous logs)
- ❌ Getting 502 errors when accessing endpoints

## What to Check in Railway

### 1. Check Runtime Logs (NOT Build Logs)

1. **Go to Railway Dashboard**
2. **Open your service**
3. **Click on "Logs" tab** (or "View Logs")
4. **Look for**:
   - Does the app start? (should see "Application startup complete")
   - What port is it using? (should match Railway's PORT)
   - Are there any errors after startup?
   - When you make a request, do you see log entries?

### 2. Check if Requests Reach the App

Make a request and watch the logs. You should see:
```
INFO: 100.64.0.X:XXXXX - "GET /health HTTP/1.1" 200 OK
```

If you DON'T see request logs, Railway isn't routing requests to your app.

### 3. Verify Port Configuration

1. **In Railway**, go to your service
2. **Check "Variables" tab**
3. **Look for `PORT`** - what value does it have?
4. **Check logs** - what port is the app listening on?
5. **They should match!**

### 4. Check Service Settings

1. **In Railway**, go to your service
2. **Click "Settings" tab**
3. **Check "Port"** or "Expose Port" settings
4. **Verify** it matches what the app is using

## Common Fixes

### Fix 1: Ensure App Binds to 0.0.0.0

The app should bind to `0.0.0.0`, not `127.0.0.1` or `localhost`.

Your `railway.toml` has:
```
startCommand = "uvicorn app:app --host 0.0.0.0 --port $PORT"
```

This is correct! ✅

### Fix 2: Check Railway Service Type

Make sure your service is set up as a "Web Service", not a "Worker" or other type.

### Fix 3: Verify Health Check

Railway might be doing health checks. Check if:
- Health check endpoint exists: `/health` ✅
- Health check is configured in Railway settings
- Health check is passing

### Fix 4: Check for Crashing

If the app starts but then crashes:
- Check logs for errors after startup
- Look for Python tracebacks
- Check if database connection is working

## What to Share

Please share:
1. **Runtime logs** (the logs that appear after the container starts)
2. **Make a request** and share what logs appear (or don't appear)
3. **PORT variable value** from Railway
4. **Any error messages** in the logs

## Quick Test

1. **Watch Railway logs** in real-time
2. **Make a request**: `curl https://flareweather-production.up.railway.app/health`
3. **See if any logs appear** in Railway
4. **Share what you see** (or don't see)

If no logs appear when you make requests, Railway isn't routing to your app.
If logs appear but show errors, we can fix those errors.

