# Fix Railway Crash Loop and Duplicate Services

## Problem
You're seeing:
- Tons of deployment restarts (crash loop)
- Two service names: "FlareWeather" and "balanced-luck" (duplicate services?)

## Immediate Fix

### Step 1: Delete Duplicate Service
1. **Go to Railway Dashboard**
   - https://railway.app/dashboard
   - You should see your project

2. **Check for Duplicate Services**
   - Look for TWO services (one called "FlareWeather", one called "balanced-luck")
   - You should only have ONE backend service

3. **Delete the Extra Service**
   - Click on the extra service (probably "balanced-luck")
   - Go to **Settings** → **Danger Zone** → **Delete Service**
   - Confirm deletion

### Step 2: Check Current Service Status
1. **Select your main service** (probably "FlareWeather")
2. **Go to Deployments tab**
3. **Look at the latest deployment logs**
4. **Check for error messages** - the app is crashing on startup

### Step 3: Stop Auto-Deploy (Temporary)
While fixing the crash, disable auto-deploy:

1. **Railway Dashboard** → Your Service → **Settings**
2. **Find "Source"** section
3. **Toggle "Auto Deploy" to OFF**
4. This stops new builds from triggering automatically

### Step 4: Fix the Crash
The app is failing health checks. Common causes:

1. **Missing environment variables**
   - Check Railway Settings → Variables
   - Make sure these are set:
     - `OPENAI_API_KEY`
     - `JWT_SECRET_KEY`
     - `DATABASE_URL` (should be auto-set if PostgreSQL is connected)

2. **Import errors**
   - I just fixed an import issue in `app.py`
   - The latest code should work now

3. **Database connection issues**
   - Check if PostgreSQL service is connected
   - Check if `DATABASE_URL` is set correctly

### Step 5: Test Deployment
1. **With auto-deploy OFF**, manually deploy:
   - Go to **Deployments** tab
   - Click **"Redeploy"** on the latest deployment
   - OR create a new deployment from the latest commit

2. **Watch the logs**
   - Check if it builds successfully
   - Check if health check passes
   - Look for error messages

### Step 6: Re-enable Auto-Deploy (Optional)
Once it's working:
1. **Settings** → **Source**
2. **Toggle "Auto Deploy" to ON**
3. Now it will auto-deploy on pushes again (but only one service)

## Why You Saw So Many Builds

Every `git push` = 1 new build/deployment in Railway. In our session:
- We pushed 10+ commits
- Each created a new build
- Railway auto-deployed each one

This is normal, but you can reduce it by:
- **Batching commits** (commit multiple times, push once)
- **Manual deployment** (disable auto-deploy, deploy when ready)
- **Feature branches** (work on `develop`, only deploy `main`)

## Current Status

The latest code should work - I fixed the import issue. But you need to:
1. Delete the duplicate service
2. Check environment variables are set
3. Manually redeploy and watch logs

Let me know what errors you see in the logs!

