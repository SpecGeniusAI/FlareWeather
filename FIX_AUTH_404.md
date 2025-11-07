# Fix Auth Endpoints 404 Error

## Problem
Your Railway deployment is missing the authentication routes. The routes exist in your code but Railway is running an older version.

## Solution: Deploy Latest Code to Railway

### Option 1: GitHub Auto-Deploy (Recommended)

If your Railway project is connected to GitHub:

1. **Commit your latest code**:
   ```bash
   git add .
   git commit -m "Add authentication endpoints"
   git push origin main
   ```

2. **Railway will automatically deploy** when you push to GitHub

3. **Wait for deployment** (check Railway dashboard)

4. **Test the endpoints**:
   ```bash
   curl https://flareweather-production.up.railway.app/auth/login
   ```

### Option 2: Manual Redeploy in Railway

1. **Go to Railway Dashboard**: https://railway.app
2. **Open your project** (`flareweather-production`)
3. **Click on your service**
4. **Go to "Deployments" tab**
5. **Click "Redeploy"** or **"Deploy Latest"**
6. **Wait for deployment to complete**
7. **Check logs** to ensure no errors

### Option 3: Force Redeploy via Railway CLI

1. **Install Railway CLI** (if not installed):
   ```bash
   npm i -g @railway/cli
   ```

2. **Login**:
   ```bash
   railway login
   ```

3. **Link your project**:
   ```bash
   railway link
   ```

4. **Deploy**:
   ```bash
   railway up
   ```

## Verify Routes Are Deployed

After redeploy, test these endpoints:

```bash
# Test health (should work)
curl https://flareweather-production.up.railway.app/health

# Test root (should work)
curl https://flareweather-production.up.railway.app/

# Test auth endpoints (should work after redeploy)
curl -X POST https://flareweather-production.up.railway.app/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test"}'

# Should return 401 (Unauthorized) NOT 404 (Not Found)
# 404 = route doesn't exist
# 401 = route exists but authentication failed (expected)
```

## Check Railway Logs

After redeploy, check Railway logs for:

1. **Database initialization**:
   ```
   ✅ Database initialized successfully
   ```

2. **No import errors**:
   - Should not see: `ModuleNotFoundError: No module named 'auth'`
   - Should not see: `ImportError`

3. **Routes registered**:
   - Check if auth routes are being logged (they should be)

## Quick Checklist

- [ ] Code is committed to Git
- [ ] Code is pushed to GitHub (if using GitHub integration)
- [ ] Railway is connected to GitHub (if using auto-deploy)
- [ ] Triggered redeploy in Railway
- [ ] Waited for deployment to complete
- [ ] Checked Railway logs for errors
- [ ] Tested `/auth/login` endpoint (should return 401, not 404)

## Expected Behavior

### Before Fix:
- `/auth/login` → 404 Not Found ❌
- `/auth/signup` → 404 Not Found ❌

### After Fix:
- `/auth/login` → 401 Unauthorized (if invalid credentials) ✅
- `/auth/signup` → 200 OK or 400 Bad Request (if email exists) ✅

## If Still Getting 404

1. **Check Railway logs** for import errors
2. **Verify `auth.py` is in the repository**
3. **Verify `database.py` is in the repository**
4. **Check if Railway is using the correct branch** (should be `main` or `master`)
5. **Verify environment variables** are set:
   - `JWT_SECRET_KEY`
   - `OPENAI_API_KEY`
   - `DATABASE_URL` (auto-set)

## Next Steps After Fix

Once auth endpoints work:
1. Test login from iOS app
2. Test signup from iOS app
3. Verify tokens are being generated correctly
4. Test protected routes (if any)

