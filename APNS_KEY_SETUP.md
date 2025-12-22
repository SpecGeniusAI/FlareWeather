# APNs Key Setup Guide

## Step 1: Create APNs Key in Apple Developer Portal

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/authkeys/list)
2. Click the **"+"** button to create a new key
3. Enter a name (e.g., "FlareWeather Push Notifications")
4. Check the box for **"Apple Push Notifications service (APNs)"**
5. Click **"Continue"** then **"Register"**
6. **IMPORTANT**: Download the `.p8` key file immediately (you can only download it once!)
7. Note the **Key ID** (shown on the page, looks like: `ABC123DEF4`)
8. Note your **Team ID** (shown at top of page, looks like: `ABCD1234EF`)

## Step 2: Get the Key Content

You have two options:

### Option A: Use Key Content (Recommended for Railway)
1. Open the downloaded `.p8` file in a text editor
2. Copy the entire contents (including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`)
3. You'll add this to Railway as `APNS_KEY_CONTENT`

### Option B: Use Key Path (If storing file in repo)
1. Add the `.p8` file to your repository (be careful with security!)
2. Set `APNS_KEY_PATH` to the path of the file

## Step 3: Add to Railway Environment Variables

Go to your Railway project → Variables tab and add:

- **`APNS_KEY_ID`** = Your Key ID (e.g., `ABC123DEF4`)
- **`APNS_TEAM_ID`** = Your Team ID (e.g., `ABCD1234EF`)
- **`APNS_KEY_CONTENT`** = The full contents of your `.p8` file (all lines, including BEGIN/END markers)
- **`APNS_BUNDLE_ID`** = `KHUR.FlareWeather` (your app's bundle ID)
- **`APNS_USE_SANDBOX`** = `false` (for production, use `true` only for TestFlight/development)

## Step 4: Verify Setup

After adding the variables, wait for Railway to redeploy, then test:

```bash
curl -X POST "https://flareweather-production.up.railway.app/admin/send-test-notification?email=YOUR_EMAIL" \
  -H "X-Admin-Key: flare_admin_aca6cc196ec637410eb9cd159e7a997b"
```

The response should show `"apns_configured": true` if everything is set up correctly.

## Important Notes

- The `.p8` file can only be downloaded once - save it securely!
- For production apps, use `APNS_USE_SANDBOX=false`
- For TestFlight/development, you might need `APNS_USE_SANDBOX=true`
- The bundle ID must match your app's bundle ID exactly: `KHUR.FlareWeather`

## Troubleshooting

If notifications still fail after setup:
1. Check Railway logs for APNs error messages
2. Verify the bundle ID matches exactly
3. Ensure you're using production APNs (not sandbox) for App Store builds
4. Check that the key has "Apple Push Notifications service (APNs)" enabled
