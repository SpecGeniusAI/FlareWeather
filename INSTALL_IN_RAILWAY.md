# Installing Package in Railway

The package needs to be installed during Railway's build process. Since it's already in `requirements.txt`, Railway should install it automatically when it redeploys.

## Check Deployment Status

1. Go to Railway dashboard
2. Click on **FlareWeather** service
3. Check **Deployments** tab
4. Look for the latest deployment - it should show "Building" or "Deployed"

## If Deployment Finished But Package Still Missing

The package might not be installing correctly. Try:

1. **Check Railway logs** - Look for errors during the build
2. **Manual install via Railway Shell:**
   - In Railway dashboard, go to FlareWeather service
   - Look for "Shell" or "Console" option
   - Run: `pip install app-store-server-library`

## Alternative: Add to Railway's Build Command

If the package still won't install, we can modify the build process, but this shouldn't be necessary since it's in requirements.txt.
