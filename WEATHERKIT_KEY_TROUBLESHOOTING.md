# WeatherKit Key Configuration Troubleshooting

## Issue: Can't Add Key Manually in Xcode

If you can't add the key manually, try these steps:

## Step 1: Refresh Xcode Account

1. **Open Xcode Settings**
   - **Xcode → Settings** (or **Preferences** on older versions)
   - Click **Accounts** tab

2. **Select Your Apple Developer Account**
   - Click on your account in the left sidebar

3. **Download Manual Profiles**
   - Click **Download Manual Profiles** button
   - Wait for it to complete (this can take a minute)
   - This refreshes Xcode's knowledge of your keys and capabilities

4. **Close Settings**

## Step 2: Verify Key in Apple Developer Portal

1. **Go to Apple Developer Portal**
   - https://developer.apple.com/account/
   - **Certificates, Identifiers & Profiles → Keys**

2. **Find Your Key**
   - Look for key with ID: `B88652888V`
   - Verify it shows **WeatherKit** as enabled
   - If WeatherKit is not checked, you need to create a new key with WeatherKit enabled

3. **Verify App Identifier Has WeatherKit**
   - Go to **Identifiers**
   - Select `KHUR.FlareWeather`
   - Verify **WeatherKit** is checked
   - If not, check it and click **Save**

## Step 3: Try Adding Key in Xcode Again

1. **Select FlareWeather Target**
   - Click on project → Select FlareWeather target

2. **Go to Signing & Capabilities**

3. **Click on WeatherKit** (should be added now)

4. **Try These Options:**

   **Option A: Use Dropdown**
   - Look for a dropdown or "Key ID" field
   - Click on it
   - Your key should appear in the list
   - Select `B88652888V`

   **Option B: Enter Manually**
   - If there's a text field, enter: `B88652888V`
   - Press Enter or Tab

   **Option C: Configure Button**
   - Look for a **Configure** button
   - Click it
   - Select your key from the list

## Step 4: If Key Still Doesn't Appear

### Check Key Association

The key needs to be associated with your app identifier. Sometimes this happens automatically, sometimes it doesn't.

1. **In Apple Developer Portal:**
   - Go to **Identifiers → KHUR.FlareWeather**
   - Check if there's a section showing associated keys
   - WeatherKit should show your key ID

2. **If Key Isn't Associated:**
   - The key should automatically associate when you enable WeatherKit
   - If not, try:
     - Disable WeatherKit for the identifier
     - Save
     - Re-enable WeatherKit
     - Save again
     - This sometimes triggers the association

### Alternative: Create New Key

If the key still doesn't work:

1. **Create a New Key:**
   - Go to Apple Developer Portal → Keys
   - Create a new key with WeatherKit enabled
   - Download the `.p8` file
   - Note the new Key ID

2. **Use the New Key:**
   - Try configuring the new key in Xcode
   - Sometimes a fresh key works better

## Step 5: Check Xcode Console

1. **Open Xcode Console**
   - **View → Debug Area → Activate Console** (⌘⇧Y)

2. **Look for Errors:**
   - When you try to configure the key, check for error messages
   - Common errors:
     - "Key not found"
     - "Key not associated with app identifier"
     - "Authentication failed"

## Step 6: Verify Signing

1. **Check Automatic Signing:**
   - In Signing & Capabilities
   - Make sure **Automatically manage signing** is checked
   - Or if using manual signing, make sure your provisioning profile is set

2. **Check Team:**
   - Make sure the correct **Team** is selected
   - Should match your Apple Developer account

## Step 7: Restart Xcode

Sometimes Xcode needs a restart to recognize new keys:

1. **Quit Xcode completely** (⌘Q)
2. **Restart Xcode**
3. **Open your project**
4. **Try configuring the key again**

## Step 8: Check for Updates

Make sure you're using a recent version of Xcode:
- WeatherKit requires Xcode 14.0+
- You're using Xcode 16.4, so you're good ✅

## Alternative: Manual Configuration via Project File

If Xcode UI still doesn't work, we can try adding it manually to the project file, but this is more complex and risky. Let's try the steps above first.

## What to Check Right Now

1. ✅ WeatherKit enabled in Apple Developer Portal for `KHUR.FlareWeather`?
2. ✅ Key `B88652888V` has WeatherKit enabled?
3. ✅ Downloaded manual profiles in Xcode?
4. ✅ Restarted Xcode?
5. ✅ Correct team selected in Xcode?

## If Nothing Works

If you've tried all the above and the key still doesn't appear:

1. **Check if the key is actually associated:**
   - In Apple Developer Portal → Identifiers → KHUR.FlareWeather
   - Look for WeatherKit section
   - It should show your key ID

2. **Try a different approach:**
   - Sometimes Xcode needs the key to be "activated" first
   - Try building the project (even if it fails)
   - Then try configuring the key again

3. **Contact me with:**
   - Screenshot of Signing & Capabilities tab
   - What you see when you click on WeatherKit
   - Any error messages from Xcode console

