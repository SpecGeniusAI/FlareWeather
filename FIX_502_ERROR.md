# Fix 502 Error - Application Failed to Respond

## Problem
Railway shows "deployed" but the application is returning 502 errors. This means the app crashed on startup.

## Solution: Check Railway Logs

1. **Go to Railway Dashboard**: https://railway.app
2. **Open your project** (`flareweather-production`)
3. **Click on your service** (the main app, not database)
4. **Go to "Deployments" tab**
5. **Click on the latest deployment**
6. **Check the "Logs" tab**

## Common Issues and Fixes

### Issue 1: Missing Dependencies

**Symptoms:**
- Logs show: `ModuleNotFoundError: No module named 'X'`
- Logs show: `ImportError`

**Fix:**
- Check `requirements.txt` includes all dependencies
- Verify all imports in `app.py` are available

### Issue 2: Database Connection Error

**Symptoms:**
- Logs show: `Database initialization error`
- Logs show: `could not connect to server`

**Fix:**
- Verify PostgreSQL service is running in Railway
- Check `DATABASE_URL` environment variable is set
- Ensure database service is in the same project

### Issue 3: Missing Environment Variables

**Symptoms:**
- App starts but crashes on first request
- Logs show errors about missing variables

**Fix:**
- Verify these are set in Railway:
  - `OPENAI_API_KEY`
  - `JWT_SECRET_KEY`
  - `DATABASE_URL` (auto-set by Railway)

### Issue 4: Python Version Mismatch

**Symptoms:**
- Build succeeds but app crashes
- Syntax errors in logs

**Fix:**
- Check `railway.toml` has correct Python version
- Verify `runtime.txt` if present

### Issue 5: Port Configuration

**Symptoms:**
- App doesn't start
- Connection refused errors

**Fix:**
- Verify `railway.toml` uses `$PORT` variable
- Check `uvicorn` command uses correct port

## Quick Checklist

- [ ] Check Railway logs for errors
- [ ] Verify all environment variables are set
- [ ] Verify PostgreSQL service is running
- [ ] Check `requirements.txt` is complete
- [ ] Verify `railway.toml` configuration
- [ ] Check Python version compatibility

## What to Look For in Logs

### Good Signs:
```
✅ Database initialized successfully
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000
```

### Bad Signs:
```
❌ ModuleNotFoundError
❌ Database initialization error
❌ ImportError
❌ Connection refused
```

## Quick Fix: Redeploy

1. **In Railway dashboard**, go to your service
2. **Click "Redeploy"**
3. **Watch the logs** in real-time
4. **Look for startup errors**

## Need Help?

Share the Railway logs and I can help diagnose the specific issue!

