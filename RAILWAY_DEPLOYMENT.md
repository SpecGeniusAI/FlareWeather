# Railway Deployment Guide

This guide walks you through deploying the FlareWeather backend to Railway.

**Note:** If you already have a Railway project deployed, see `RAILWAY_EXISTING_PROJECT.md` for configuration instructions.

## Prerequisites

- Railway account (sign up at https://railway.app)
- GitHub account (to connect your repository)
- OpenAI API key (for AI insights)

## Step 1: Create Railway Project

1. **Go to Railway**: https://railway.app
2. **Sign in** or create an account
3. **Click "New Project"**
4. **Select "Deploy from GitHub repo"**
   - Connect your GitHub account if prompted
   - Select the repository containing your FlareWeather backend code
   - Railway will automatically detect it's a Python project

## Step 2: Add PostgreSQL Database

1. **In your Railway project dashboard**, click **"New"**
2. **Select "Database"** → **"PostgreSQL"**
3. Railway will automatically:
   - Provision a PostgreSQL database
   - Set the `DATABASE_URL` environment variable
   - No additional configuration needed!

## Step 3: Configure Environment Variables

1. **In your Railway project**, click on your **service** (the main app, not the database)
2. **Go to the "Variables" tab**
3. **Add the following environment variables**:

### Required Variables

| Variable Name | Description | Example Value |
|--------------|-------------|---------------|
| `OPENAI_API_KEY` | Your OpenAI API key for AI insights | `sk-...` |
| `JWT_SECRET_KEY` | Secret key for JWT token signing (generate a secure random string) | `your-secure-random-string-here` |

### Optional Variables

| Variable Name | Description | Default |
|--------------|-------------|---------|
| `PORT` | Port to run the server on | `8000` (Railway sets this automatically) |
| `PYTHON_VERSION` | Python version to use | `3.11` |

### Generating JWT_SECRET_KEY

You can generate a secure secret key using Python:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

Or use an online generator: https://generate-secret.vercel.app/32

## Step 4: Deploy

1. Railway will automatically start deploying when you:
   - Connect the GitHub repository
   - Add environment variables
2. **Monitor the deployment** in the Railway dashboard
3. **Check the logs** to ensure everything starts correctly
4. You should see: `✅ Database initialized successfully`

## Step 5: Get Your Backend URL

1. **In Railway dashboard**, click on your service
2. **Go to the "Settings" tab**
3. **Scroll down to "Domains"**
4. **Click "Generate Domain"** (if not already generated)
5. **Copy the URL** (e.g., `https://flareweather-production.up.railway.app`)
6. **This is your backend URL** - use it in the iOS app!

## Step 6: Update iOS App Configuration

### Option 1: Info.plist (Recommended for Production)

1. **Open your Xcode project**
2. **Find `Info.plist`** (or add it to your project if it doesn't exist)
3. **Add a new key**:
   - Key: `BackendURL`
   - Type: `String`
   - Value: `https://your-railway-url.up.railway.app` (use the URL from Step 5)

### Option 2: Environment Variable (For Development)

1. **Open Xcode**
2. **Edit Scheme** (click scheme selector → Edit Scheme)
3. **Run → Arguments → Environment Variables**
4. **Add**:
   - Name: `BACKEND_URL`
   - Value: `https://your-railway-url.up.railway.app`

## Step 7: Test the Deployment

1. **Check health endpoint**:
   ```bash
   curl https://your-railway-url.up.railway.app/health
   ```
   Should return: `{"status": "healthy"}`

2. **Check root endpoint**:
   ```bash
   curl https://your-railway-url.up.railway.app/
   ```
   Should return: `{"message": "FlareWeather API is running"}`

3. **Test from iOS app**:
   - Run the app in Xcode
   - Check console logs for: `✅ AIInsightsService: Backend URL found in Info.plist: [URL]`
   - Try to fetch AI insights - it should work!

## Troubleshooting

### Deployment Fails

**Check logs in Railway dashboard:**
- Look for Python errors
- Verify all dependencies are in `requirements.txt`
- Ensure `app.py` is in the root directory

### Database Connection Issues

**Verify:**
- PostgreSQL service is running in Railway
- `DATABASE_URL` is automatically set (Railway does this)
- Check logs for database connection messages

### API Calls Fail from iOS

**Check:**
- Backend URL is correct (no trailing slash)
- CORS is enabled (already configured in `app.py`)
- Backend is running (check Railway logs)
- Network connectivity (try in browser first)

### Environment Variables Not Working

**Verify:**
- Variables are set in the correct service (main app, not database)
- Variable names are exact matches (case-sensitive)
- Variables are saved (click "Save" or they auto-save)
- Redeploy after adding variables (Railway auto-redeploys)

## Environment Variables Summary

```bash
# Required
OPENAI_API_KEY=sk-your-key-here
JWT_SECRET_KEY=your-secure-random-string

# Auto-set by Railway
DATABASE_URL=postgresql://... (auto-set when PostgreSQL is added)
PORT=8000 (auto-set by Railway)
```

## Cost Estimation

**Railway Free Tier:**
- $5/month credit
- Usually enough for development/testing
- PostgreSQL included

**Production:**
- Pay-as-you-go pricing
- Estimate: $10-20/month for small-scale production
- Check Railway pricing page for details

## Next Steps

1. ✅ Deploy backend to Railway
2. ✅ Set environment variables
3. ✅ Get backend URL
4. ✅ Update iOS app configuration
5. ✅ Test end-to-end
6. ✅ Monitor logs for errors

## Support

If you encounter issues:
1. Check Railway logs
2. Check Xcode console logs
3. Verify all environment variables are set
4. Test backend endpoints directly (curl or browser)

## Useful Links

- Railway Dashboard: https://railway.app/dashboard
- Railway Docs: https://docs.railway.app
- Railway Status: https://status.railway.app

