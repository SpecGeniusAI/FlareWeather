# Pre-Priming Daily Forecasts - Design Overview

## Current State

**What happens now:**
1. User opens app → App requests location
2. Location available → Fetch current weather from WeatherKit
3. Fetch hourly forecast (background)
4. Fetch weekly forecast (lazy loaded)
5. Generate AI insights based on weather data

**Problem:** Users wait 2-5 seconds for weather data to load when they open the app.

---

## Pre-Priming Approach

### Concept
Pre-fetch weather forecasts for all active users in the background, so when they open the app, the data is already ready.

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Background Service (Railway)                           │
│  ┌───────────────────────────────────────────────────┐ │
│  │  Forecast Pre-Priming Service                      │ │
│  │  - Runs every 30-60 minutes                       │ │
│  │  - Fetches weather for all active users            │ │
│  │  - Stores in database                              │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│  Database (PostgreSQL)                                   │
│  ┌───────────────────────────────────────────────────┐ │
│  │  user_forecasts table                            │ │
│  │  - user_id (FK)                                  │ │
│  │  - location_lat, location_lon                    │ │
│  │  - current_weather (JSON)                         │ │
│  │  - hourly_forecast (JSON)                         │ │
│  │  - daily_forecast (JSON)                          │ │
│  │  - fetched_at (timestamp)                         │ │
│  │  - expires_at (timestamp)                         │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│  iOS App                                                 │
│  ┌───────────────────────────────────────────────────┐ │
│  │  On App Open:                                     │ │
│  │  1. Check database for pre-fetched forecast      │ │
│  │  2. If exists & fresh (< 30 min old) → Use it    │ │
│  │  3. If missing/stale → Fetch fresh (fallback)    │ │
│  │  4. Display instantly!                            │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

---

## Database Schema

### New Table: `user_forecasts`

```sql
CREATE TABLE user_forecasts (
    id VARCHAR PRIMARY KEY,
    user_id VARCHAR NOT NULL REFERENCES users(id),
    location_latitude FLOAT NOT NULL,
    location_longitude FLOAT NOT NULL,
    location_name VARCHAR,  -- e.g., "Toronto, ON"
    
    -- Weather data (stored as JSON)
    current_weather JSONB,      -- Current conditions
    hourly_forecast JSONB,      -- Next 24-48 hours
    daily_forecast JSONB,       -- Next 7-10 days
    
    -- Metadata
    fetched_at TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NOT NULL,  -- When data becomes stale
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_user_forecasts_user_id (user_id),
    INDEX idx_user_forecasts_expires_at (expires_at)
);
```

---

## Background Service

### Service: `forecast_pre_priming.py`

**What it does:**
1. Runs every 30-60 minutes (configurable)
2. Queries all active users (logged in within last 7 days)
3. For each user:
   - Get their last known location (from `User` table or previous forecast)
   - Fetch weather from WeatherKit API
   - Store in `user_forecasts` table
   - Set `expires_at` to 30 minutes from now

**Key Features:**
- Batch processing (process multiple users)
- Rate limiting (respect WeatherKit API limits)
- Error handling (skip users with invalid locations)
- Logging (track success/failure rates)

---

## iOS App Changes

### Modified: `WeatherService.swift`

**New method:**
```swift
func loadPrePrimedForecast(for user: User) async -> Bool {
    // 1. Call backend API: GET /user/pre-primed-forecast
    // 2. Backend returns pre-fetched forecast from database
    // 3. Parse and populate weatherData, hourlyForecast, weeklyForecast
    // 4. Return true if loaded successfully
}
```

**Modified: `HomeView.swift`**
```swift
.onAppear {
    // Try to load pre-primed forecast first
    if let user = authManager.currentUser {
        let loaded = await weatherService.loadPrePrimedForecast(for: user)
        if loaded {
            print("✅ Loaded pre-primed forecast - instant display!")
            return  // Skip fetching, data is ready
        }
    }
    
    // Fallback: Fetch fresh data (current behavior)
    await fetchWeatherData()
}
```

---

## Backend API Endpoint

### New Endpoint: `GET /user/pre-primed-forecast`

**Request:**
- Requires authentication (JWT token)
- No parameters needed (uses current user)

**Response:**
```json
{
    "current_weather": {
        "temperature": 22.5,
        "humidity": 65,
        "pressure": 1013.25,
        "windSpeed": 15.0,
        "condition": "Partly Cloudy",
        "timestamp": "2025-12-10T15:00:00Z"
    },
    "hourly_forecast": [
        {
            "time": "2025-12-10T16:00:00Z",
            "temperature": 23.0,
            "condition": "Sunny"
        },
        // ... next 24 hours
    ],
    "daily_forecast": [
        {
            "date": "2025-12-10",
            "high": 25.0,
            "low": 18.0,
            "condition": "Partly Cloudy"
        },
        // ... next 7 days
    ],
    "fetched_at": "2025-12-10T14:55:00Z",
    "expires_at": "2025-12-10T15:25:00Z",
    "location": {
        "latitude": 43.6532,
        "longitude": -79.3832,
        "name": "Toronto, ON"
    }
}
```

**If no pre-primed data:**
- Returns `404` or empty response
- App falls back to fetching fresh data

---

## Benefits

### User Experience
- ✅ **Instant loading** - Weather appears immediately when app opens
- ✅ **No waiting** - No spinner, no "Loading weather..." message
- ✅ **Works offline** - Can show cached forecast even if network is slow
- ✅ **Better first impression** - App feels faster and more responsive

### Technical
- ✅ **Reduced API calls** - Batch fetching is more efficient
- ✅ **Better caching** - Centralized cache in database
- ✅ **Predictable load** - Background service handles peak times
- ✅ **Fallback safety** - Still works if pre-priming fails

---

## Challenges & Considerations

### 1. **Location Management**
- **Problem:** Need to know user's location to pre-fetch
- **Solution:** 
  - Store last known location in `User` table
  - Update when user opens app
  - For new users, skip pre-priming until they have a location

### 2. **WeatherKit API Limits**
- **Problem:** WeatherKit has rate limits
- **Solution:**
  - Batch requests efficiently
  - Cache aggressively (30-60 min TTL)
  - Respect API quotas

### 3. **Storage Costs**
- **Problem:** Storing forecasts for all users uses database space
- **Solution:**
  - Only pre-prime active users (logged in within 7 days)
  - Auto-cleanup expired forecasts
  - JSONB is efficient in PostgreSQL

### 4. **Data Freshness**
- **Problem:** Pre-primed data might be stale
- **Solution:**
  - Set `expires_at` to 30 minutes
  - App checks expiration before using
  - Falls back to fresh fetch if expired

### 5. **Location Changes**
- **Problem:** User might be in different location
- **Solution:**
  - Check if user's current location differs significantly (> 10km)
  - If different, fetch fresh data
  - Update stored location

---

## Implementation Steps

### Phase 1: Database & Backend
1. Create `user_forecasts` table
2. Add `last_location_lat/lon` to `User` table
3. Create backend endpoint: `GET /user/pre-primed-forecast`
4. Create background service: `forecast_pre_priming.py`

### Phase 2: Background Service
1. Set up Railway service for pre-priming
2. Schedule to run every 30-60 minutes
3. Fetch weather for active users
4. Store in database

### Phase 3: iOS Integration
1. Add `loadPrePrimedForecast()` method
2. Modify `HomeView` to try pre-primed first
3. Add fallback to fresh fetch
4. Update location when user opens app

### Phase 4: Optimization
1. Monitor success rates
2. Adjust refresh frequency
3. Optimize batch processing
4. Add metrics/logging

---

## Cost Estimate

### Database Storage
- ~2-5 KB per user forecast (JSON)
- 1000 active users = ~5 MB
- Negligible cost

### WeatherKit API
- Free tier: 500,000 calls/month
- 1000 users × 48 fetches/day = 48,000 calls/day = 1.44M/month
- Might need paid tier if you exceed limits

### Railway Service
- One additional service running 24/7
- Minimal CPU/memory usage
- ~$5-10/month

---

## Alternative: Simpler Approach

Instead of full pre-priming, you could:

1. **Cache in iOS app** - Store last forecast locally
2. **Show cached data immediately** - Display while fetching fresh
3. **Update in background** - Refresh after showing cached data

This is simpler but less effective (still requires network on first open).

---

## Recommendation

**Start with:** Pre-priming for active users (logged in within 7 days)
- Lower API usage
- Focus on users who actually use the app
- Easier to scale

**Expand later:** Pre-prime for all users if needed

---

## Questions to Consider

1. **How often to refresh?** (30 min? 60 min?)
2. **Which users to pre-prime?** (All? Active only?)
3. **What if location changes?** (How to handle?)
4. **What if WeatherKit is down?** (Fallback strategy?)

Let me know if you want me to implement this!
