# Railway Build Configuration

## Why You're Seeing Multiple Builds

Railway automatically builds and deploys on **every push** to your connected branch (usually `main`). This is normal behavior, but it means:

- Every `git push` = 1 new build
- If you push 5 times in quick succession = 5 builds

## Options to Reduce Builds

### Option 1: Deploy Manually (Recommended for Development)

1. **Go to Railway Dashboard**
   - Select your project
   - Go to **Settings** → **Service**
   - Find **"Source"** section
   - Click **"Configure"** next to your GitHub connection

2. **Disable Auto-Deploy**
   - Toggle **"Auto Deploy"** to **OFF**
   - Now deployments only happen when you click **"Deploy"** manually

3. **Manual Deployment**
   - When you want to deploy, go to **Deployments** tab
   - Click **"Redeploy"** or create a new deployment from a specific commit

### Option 2: Deploy Only on Specific Branches

1. **Configure Branch Protection**
   - In Railway Settings → Service → Source
   - Set **"Deploy Branch"** to `main` (or `production`)
   - Only pushes to this branch will trigger builds

2. **Use Different Branches**
   - Work on `develop` branch (no auto-deploy)
   - Merge to `main` when ready (triggers deploy)

### Option 3: Keep Auto-Deploy But Batch Commits

Instead of pushing after every small change:
- Make multiple commits locally
- Push once when you're ready
- This creates one build instead of many

**Example:**
```bash
# Instead of this:
git commit -m "Fix 1"
git push
git commit -m "Fix 2"  
git push
git commit -m "Fix 3"
git push  # = 3 builds

# Do this:
git commit -m "Fix 1"
git commit -m "Fix 2"
git commit -m "Fix 3"
git push  # = 1 build
```

## Check for Duplicate Services

If you're seeing an excessive number of builds, check:

1. **Railway Dashboard** → Your Project
2. Look for **multiple services** (you should only have one backend service)
3. If you see duplicates, you can delete the extra ones

## Recommended Setup

For development:
- **Auto-Deploy: OFF** (deploy manually when ready)

For production:
- **Auto-Deploy: ON** (but only on `main` branch)
- Use feature branches for development (they won't deploy)

## Current Railway Configuration

Your `railway.toml` is configured correctly:
- Uses `nixpacks` builder
- Health check on `/health`
- Restart on failure

The issue is just the auto-deploy frequency from multiple pushes, which is normal behavior.

## Quick Fix: Delete Old Builds

You can clean up old builds in Railway:
1. Go to **Deployments** tab
2. Old/failed builds can be left as-is (they don't affect anything)
3. Railway keeps them for logs/history

Or just ignore them - they don't hurt anything, just clutter the UI.

