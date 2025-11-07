# Adding OpenWeatherMap API Key to Xcode

## Your API Key
```
283e823d16ee6e1ba0c625505e5df181
```

## Step-by-Step Instructions

### Step 1: Open Scheme Editor
1. In Xcode, make sure the **FlareWeather** project is open
2. Look at the top toolbar - you'll see a device/simulator selector (e.g., "iPhone 15 Pro")
3. Click on **FlareWeather** (next to the device selector) - this opens the scheme menu
4. Click **Edit Scheme...** (or press `⌘<`)

### Step 2: Add Environment Variable
1. In the left sidebar, make sure **Run** is selected (should be highlighted)
2. Click the **Arguments** tab at the top
3. Look for **Environment Variables** section (below "Arguments Passed On Launch")
4. Click the **+** button (plus icon) in the bottom left of the Environment Variables section
5. A new row will appear with two fields:
   - **Name**: Type `OPENWEATHER_API_KEY`
   - **Value**: Type `283e823d16ee6e1ba0c625505e5df181`
6. Make sure the **checkbox** next to it is **checked** ✅
7. Click **Close** button at the bottom right

### Step 3: Verify It's Set
1. Go back to **Product → Scheme → Edit Scheme...**
2. Click **Run** → **Arguments** tab
3. Under **Environment Variables**, you should see:
   - `OPENWEATHER_API_KEY` = `283e823d16ee6e1ba0c625505e5df181` ✅

## Visual Guide

```
Xcode Toolbar:
[FlareWeather ▼] [iPhone 15 Pro ▼] [▶️]

Click "FlareWeather ▼" → "Edit Scheme..."

Left Sidebar:
✓ Run
  Build
  Test
  ...

Top Tabs:
[Info] [Arguments] [Options] [Diagnostics]

Click "Arguments" tab

Environment Variables Section:
[+]

After clicking +:
Name: OPENWEATHER_API_KEY
Value: 283e823d16ee6e1ba0c625505e5df181
[✓] (checkbox checked)
```

## Quick Test

After adding the API key:
1. Build and run the app (⌘R)
2. Grant location permission when asked
3. Check the Home tab - you should see real weather data (not mock data like "22°C")
4. Check Xcode console (bottom panel) - should NOT see any API key errors

## Troubleshooting

### Can't find "Edit Scheme"?
- Make sure you clicked on **FlareWeather** next to the device selector (top toolbar)
- Or use keyboard shortcut: `⌘<` (Command + Less Than)

### Don't see "Arguments" tab?
- Make sure **Run** is selected in the left sidebar of the scheme editor
- The Arguments tab should be at the top, next to "Info"

### API key not working?
- Make sure the checkbox is checked ✅
- Make sure there are no extra spaces in the name or value
- Try Product → Clean Build Folder (⇧⌘K), then build again

## Next Steps

Once the API key is added:
1. ✅ Test the app (⌘R)
2. ✅ Verify weather data loads
3. ✅ Then proceed to add Location Permission (Step 4)

