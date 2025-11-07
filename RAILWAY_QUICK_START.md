# Railway Quick Start Guide

## TL;DR - Deploy in 5 Minutes

1. **Go to Railway**: https://railway.app
2. **Click "New Project"** → **"Deploy from GitHub repo"**
3. **Select your repository**
4. **Click "New"** → **"Database"** → **"PostgreSQL"**
5. **Go to your service** → **"Variables" tab**
6. **Add these variables**:
   - `OPENAI_API_KEY` = `sk-your-key-here`
   - `JWT_SECRET_KEY` = `your-secure-random-string` (generate one)
7. **Wait for deployment** (2-3 minutes)
8. **Get your URL**: Service → Settings → Domains → Copy URL
9. **Update iOS app**: Add `BackendURL` to Info.plist with your Railway URL
10. **Done!** ✅

## Generate JWT Secret Key

Run this command to generate a secure key:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

Or use: https://generate-secret.vercel.app/32

## Verify Deployment

```bash
# Test health endpoint
curl https://your-url.up.railway.app/health

# Should return: {"status": "healthy"}
```

## Environment Variables Checklist

- [ ] `OPENAI_API_KEY` (required)
- [ ] `JWT_SECRET_KEY` (required)
- [ ] `DATABASE_URL` (auto-set by Railway)
- [ ] `PORT` (auto-set by Railway)

## Need Help?

See `RAILWAY_DEPLOYMENT.md` for detailed instructions.

