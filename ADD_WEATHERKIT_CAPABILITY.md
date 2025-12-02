# How to Add WeatherKit Capability in Xcode

## If WeatherKit is Not Clickable

If you can't click on WeatherKit in the capabilities list, you need to **add it first** using the "+ Capability" button.

## Step-by-Step Instructions

### 1. Open Your Project in Xcode
```bash
open FlareWeather/FlareWeather.xcodeproj
```

### 2. Select Your Target

1. Click on **FlareWeather** project (top item in the navigator - blue icon)
2. Select **FlareWeather** target (under TARGETS, not PROJECTS)

### 3. Go to Signing & Capabilities Tab

- Click the **Signing & Capabilities** tab at the top

### 4. Add WeatherKit Capability

1. **Look for the "+ Capability" button** (top-left of the capabilities section)
   - It's a button with a **+** icon
   - It might say "**+ Capability**" or just show a **+** icon

2. **Click the "+ Capability" button**

3. **Search for "WeatherKit"**
   - A dialog will appear with a search box
   - Type "WeatherKit" in the search box
   - You should see "WeatherKit" in the results

4. **Double-click "WeatherKit"** (or click it and then click "Add")
   - WeatherKit will be added to your capabilities list

### 5. Configure the Key

After WeatherKit is added:

1. **Click on "WeatherKit"** in the capabilities list (it should now be clickable)

2. **Configure the Key ID:**
   - You should see a section for WeatherKit configuration
   - Look for **Key ID** field or dropdown
   - Click **Configure** button (if visible)
   - Select your key: **B88652888V**
   - Or enter the Key ID manually: `B88652888V`

3. **Verify:**
   - ✅ **Key ID**: `B88652888V` (or similar)
   - ✅ **Team ID**: Should auto-populate
   - ✅ **Service ID**: Should auto-populate

### 6. If Key Doesn't Appear

If your key doesn't appear in the dropdown:

1. **Refresh Xcode's account:**
   - Go to **Xcode → Settings** (or **Preferences**)
   - Click **Accounts** tab
   - Select your Apple Developer account
   - Click **Download Manual Profiles**
   - Wait for it to complete

2. **Try again:**
   - Go back to Signing & Capabilities
   - Click Configure on WeatherKit
   - Your key should now appear

### 7. Clean and Rebuild

1. **Clean Build Folder:**
   - **Product → Clean Build Folder** (⌘⇧K)

2. **Rebuild:**
   - **Product → Build** (⌘B)

3. **Run:**
   - **Product → Run** (⌘R)

## Troubleshooting

### "+ Capability" Button Not Visible

**Solution:**
- Make sure you've selected the **target** (FlareWeather), not the project
- Make sure you're in the **Signing & Capabilities** tab
- Try scrolling up - the button is at the top of the capabilities section

### WeatherKit Not in Search Results

**Possible causes:**
1. **WeatherKit not enabled in Apple Developer Portal:**
   - Go to Apple Developer Portal
   - Certificates, Identifiers & Profiles → Identifiers
   - Select `KHUR.FlareWeather`
   - Check **WeatherKit** checkbox
   - Click **Save**

2. **Xcode needs to be updated:**
   - WeatherKit requires Xcode 14.0+ (you should be fine with Xcode 16.4)

3. **Account not signed in:**
   - Go to Xcode → Settings → Accounts
   - Make sure your Apple Developer account is signed in

### Key ID Not Showing

**Solution:**
1. Make sure you created the key with WeatherKit enabled
2. Make sure you're signed in with the same Apple Developer account
3. Download manual profiles (Xcode → Settings → Accounts → Download Manual Profiles)
4. Try restarting Xcode

## Visual Guide

```
Xcode Window:
┌─────────────────────────────────────────┐
│ FlareWeather (Project)                 │
│   ├─ FlareWeather (Target) ← SELECT    │
│   └─ FlareWeatherTests                 │
├─────────────────────────────────────────┤
│ [General] [Signing & Capabilities] ← CLICK
│                                         │
│ Capabilities:                           │
│ [+ Capability] ← CLICK THIS BUTTON     │
│                                         │
│   ✅ Sign in with Apple                 │
│   ⬜ WeatherKit (not added yet)         │
└─────────────────────────────────────────┘

After clicking "+ Capability":
┌─────────────────────────────────────────┐
│ Add Capability                         │
│                                         │
│ Search: [WeatherKit        ]           │
│                                         │
│   WeatherKit                            │
│   (Double-click to add)                │
└─────────────────────────────────────────┘
```

## Quick Checklist

- [ ] Opened project in Xcode
- [ ] Selected FlareWeather target (not project)
- [ ] Went to Signing & Capabilities tab
- [ ] Clicked "+ Capability" button
- [ ] Searched for "WeatherKit"
- [ ] Added WeatherKit capability
- [ ] Configured Key ID: `B88652888V`
- [ ] Verified Team ID and Service ID are set
- [ ] Cleaned build folder
- [ ] Rebuilt and tested

## After Setup

Once WeatherKit is added and configured:
- ✅ WeatherKit will appear in capabilities list
- ✅ You can click on it to configure
- ✅ Key ID will be set
- ✅ WeatherKit will authenticate automatically
- ✅ No more authentication errors!

