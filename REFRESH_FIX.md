# ✅ AI Insights Refresh Fix

## Problem
After logging symptoms, the AI insights on the Home screen didn't update because the analysis only ran once when the view first loaded.

## Solution
Added automatic refresh when:
1. ✅ **View appears** - When you switch back to Home tab from Log tab
2. ✅ **Pull to refresh** - Pull down on the Home screen to manually refresh
3. ✅ **Throttled** - Prevents too many rapid refreshes (2 second minimum between refreshes)

## What Changed

### HomeView.swift
- Added `refreshAnalysis()` helper function
- Added `.onAppear` to refresh when view appears
- Added `.refreshable` for pull-to-refresh gesture
- Added throttling to prevent excessive API calls

### AIInsightsService.swift
- Added `lastAnalysisTime` tracking
- Fetches real symptoms from CoreData
- Uses real weather data from WeatherService

## How to Test

1. **Log symptoms**:
   - Go to Log tab
   - Add a symptom (e.g., "Headache", severity 8)
   - Tap "Log Symptom"

2. **Switch back to Home**:
   - Go to Home tab
   - The AI insights should automatically refresh
   - You should see console: `🔄 HomeView: Refreshing analysis...`
   - You should see: `📊 Found X symptom entries in CoreData`

3. **Manual refresh**:
   - Pull down on the Home screen
   - The analysis will refresh

## What You Should See

**In Xcode Console**:
```
🔄 HomeView: Refreshing analysis...
📊 Found 2 symptom entries in CoreData
📤 Sending 2 symptoms and 2 weather snapshots to backend
📤 Sending request to: http://localhost:8000/analyze
✅ Success! Received insight with X citations
```

**In the App**:
- AI Insights card updates with new analysis
- Citations appear below the message (if papers found)
- Loading indicator shows while refreshing

---

**Now when you log symptoms and go back to Home, the insights will update automatically!** 🎉

