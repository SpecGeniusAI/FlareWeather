# Configure Existing Railway Project

Your Railway project is already deployed at: **`flareweather-production.up.railway.app`**

## Step 1: Add PostgreSQL Database (if not already added)

1. **Go to Railway Dashboard**: https://railway.app
2. **Open your project** (`flareweather-production`)
3. **Check if PostgreSQL service exists**:
   - Look for a service named "PostgreSQL" or "Database"
   - If it exists, skip to Step 2
4. **If not, add it**:
   - Click **"New"** → **"Database"** → **"PostgreSQL"**
   - Railway will automatically set `DATABASE_URL` environment variable

## Step 2: Configure Environment Variables

1. **In Railway dashboard**, click on your **main service** (not the database)
2. **Go to the "Variables" tab**
3. **Add/Verify these environment variables**:

### Required Variables

| Variable Name | Status | Action |
|--------------|--------|--------|
| `OPENAI_API_KEY` | ⚠️ Add if missing | Your OpenAI API key (`sk-...`) |
| `JWT_SECRET_KEY` | ⚠️ Add if missing | Generate a secure random string |
| `DATABASE_URL` | ✅ Auto-set | Automatically set when PostgreSQL is added |

### Generate JWT_SECRET_KEY

Run this command to generate a secure key:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

Or use: https://generate-secret.vercel.app/32

Copy the generated string and add it as `JWT_SECRET_KEY` in Railway.

## Step 3: Verify Deployment

1. **Check Railway logs**:
   - Go to your service → "Deployments" tab
   - Click on the latest deployment
   - Look for: `✅ Database initialized successfully`

2. **Test the API**:
   ```bash
   # Test health endpoint
   curl https://flareweather-production.up.railway.app/health
   
   # Should return: {"status": "healthy"}
   ```

3. **Test root endpoint**:
   ```bash
   curl https://flareweather-production.up.railway.app/
   
   # Should return: {"message": "FlareWeather API is running"}
   ```

## Step 4: Update iOS App Configuration

### Option 1: Info.plist (Recommended for Production)

1. **Open your Xcode project**
2. **Find or create `Info.plist`** in your project
3. **Add this key**:
   - Key: `BackendURL`
   - Type: `String`
   - Value: `https://flareweather-production.up.railway.app`

### Option 2: Environment Variable (For Development)

1. **Open Xcode**
2. **Edit Scheme** (click scheme selector → Edit Scheme)
3. **Run → Arguments → Environment Variables**
4. **Add**:
   - Name: `BACKEND_URL`
   - Value: `https://flareweather-production.up.railway.app`

## Step 5: Verify iOS App Connection

1. **Run the app in Xcode**
2. **Check console logs** for one of these messages:
   - `✅ AIInsightsService: Backend URL found in Info.plist: https://flareweather-production.up.railway.app`
   - `✅ AuthService: Backend URL found in Info.plist: https://flareweather-production.up.railway.app`
3. **Test features**:
   - Try signing up/logging in
   - Try fetching AI insights
   - Check that API calls succeed

## Environment Variables Checklist

- [ ] `OPENAI_API_KEY` - Your OpenAI API key
- [ ] `JWT_SECRET_KEY` - Secure random string (generate one)
- [ ] `DATABASE_URL` - Auto-set by Railway (verify it exists)
- [ ] `PORT` - Auto-set by Railway (no action needed)

## Troubleshooting

### Backend Not Responding

1. **Check Railway logs** for errors
2. **Verify environment variables** are set correctly
3. **Check deployment status** - ensure it's "Active"
4. **Test endpoints directly** using curl or browser

### Database Connection Issues

1. **Verify PostgreSQL service** is running in Railway
2. **Check `DATABASE_URL`** is set (should start with `postgresql://`)
3. **Check logs** for database connection errors

### iOS App Can't Connect

1. **Verify `BackendURL`** in Info.plist matches exactly: `https://flareweather-production.up.railway.app`
2. **Check console logs** to see which URL is being used
3. **Test backend directly** using curl to ensure it's accessible
4. **Check CORS settings** (already configured in `app.py`)

## Quick Test Commands

```bash
# Test health
curl https://flareweather-production.up.railway.app/health

# Test root
curl https://flareweather-production.up.railway.app/

# Test analyze endpoint (requires auth token)
curl -X POST https://flareweather-production.up.railway.app/analyze \
  -H "Content-Type: application/json" \
  -d '{"symptoms": [], "weather": []}'
```

## Next Steps

1. ✅ Add environment variables to Railway
2. ✅ Verify backend is running
3. ✅ Update iOS app Info.plist
4. ✅ Test end-to-end connection
5. ✅ Monitor logs for any issues

Your backend URL: **`https://flareweather-production.up.railway.app`**

