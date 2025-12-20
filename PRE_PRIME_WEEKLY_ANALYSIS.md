# Pre-Priming Weekly Forecast - API Call Analysis

## Current API Usage

### WeatherKit API
- **Current weather**: 1 call per user
- **Weekly forecast (7 days)**: Included in same call (weather.dailyForecast)
- **Hourly forecast**: 1 additional call per user

**Total WeatherKit calls per user: 2 calls**

### AI API (Claude/gpt-4o-mini)
- **Daily insight**: 1 call per user
- **Weekly forecast insight**: 1 call per user (if not skipped)

**Total AI calls per user: 1-2 calls**

---

## Pre-Priming Weekly Forecast

### Option 1: Pre-Prime Full Week (7 Daily Forecasts)

**What we'd store:**
- Today's daily forecast
- Next 6 days of daily forecasts (7 total)

**API Calls:**
- **WeatherKit**: 1 call per user (gets all 7 days in one call)
- **AI**: 7 calls per user (one insight per day)

**Total per user:**
- WeatherKit: 1 call
- AI: 7 calls

**For 1000 users:**
- WeatherKit: 1,000 calls/day
- AI: 7,000 calls/day

### Option 2: Pre-Prime Today + Weekly Summary

**What we'd store:**
- Today's daily forecast (detailed)
- Weekly summary forecast (one insight covering the week)

**API Calls:**
- **WeatherKit**: 1 call per user (gets all 7 days)
- **AI**: 2 calls per user (daily + weekly summary)

**Total per user:**
- WeatherKit: 1 call
- AI: 2 calls

**For 1000 users:**
- WeatherKit: 1,000 calls/day
- AI: 2,000 calls/day

### Option 3: Pre-Prime Today Only (Current Design)

**What we'd store:**
- Today's daily forecast only

**API Calls:**
- **WeatherKit**: 1 call per user
- **AI**: 1 call per user

**Total per user:**
- WeatherKit: 1 call
- AI: 1 call

**For 1000 users:**
- WeatherKit: 1,000 calls/day
- AI: 1,000 calls/day

---

## Recommendation: Option 2 (Today + Weekly Summary)

**Why:**
- ✅ Gives users both daily and weekly context
- ✅ Only 2 AI calls per user (manageable)
- ✅ Weekly summary is what users see in the app anyway
- ✅ Balances completeness with API costs

**What gets pre-primed:**
1. **Today's daily forecast** (detailed insight)
2. **Weekly summary** (one insight covering next 7 days)

**When user opens app:**
- Today's forecast: Instant (pre-primed)
- Weekly forecast: Instant (pre-primed)
- Individual day forecasts: Can be generated on-demand if needed

---

## API Cost Analysis

### WeatherKit
- **Free tier**: 500,000 calls/month
- **1000 users × 1 call/day × 30 days = 30,000 calls/month**
- ✅ Well within free tier

### AI API (Claude/gpt-4o-mini)

**Option 1 (7 daily insights):**
- 1000 users × 7 calls = 7,000 calls/day
- 7,000 × 30 = 210,000 calls/month
- Cost: ~$50-100/month (depending on model)

**Option 2 (Today + Weekly):**
- 1000 users × 2 calls = 2,000 calls/day
- 2,000 × 30 = 60,000 calls/month
- Cost: ~$15-30/month (depending on model)

**Option 3 (Today only):**
- 1000 users × 1 call = 1,000 calls/day
- 1,000 × 30 = 30,000 calls/month
- Cost: ~$7-15/month (depending on model)

---

## Database Storage

### Option 2: Today + Weekly Summary

**Per user per day:**
- Today's forecast: ~2 KB
- Weekly summary: ~1 KB
- Weather data (7 days): ~5 KB
- **Total: ~8 KB per user per day**

**For 1000 users:**
- 8 KB × 1000 = 8 MB/day
- 8 MB × 30 = 240 MB/month
- ✅ Negligible cost

---

## Implementation: Option 2 (Recommended)

### Database Schema

```sql
CREATE TABLE daily_forecasts (
    id VARCHAR PRIMARY KEY,
    user_id VARCHAR NOT NULL,
    forecast_date DATE NOT NULL,
    
    -- Location
    location_latitude FLOAT NOT NULL,
    location_longitude FLOAT NOT NULL,
    location_name VARCHAR,
    
    -- Weather data (7 days)
    current_weather JSONB,      -- Today's current conditions
    hourly_forecast JSONB,      -- Next 24 hours
    daily_forecast JSONB,       -- Next 7 days (all days)
    
    -- Today's daily insight
    daily_risk_level VARCHAR,   -- "LOW", "MODERATE", "HIGH"
    daily_forecast_summary TEXT,
    daily_why_explanation TEXT,
    daily_insight JSONB,        -- Full daily insight
    daily_comfort_tip TEXT,
    
    -- Weekly summary insight
    weekly_forecast_insight TEXT,  -- Weekly summary text
    weekly_insight_sources JSONB,  -- Sources/citations
    
    -- Notification
    notification_sent BOOLEAN DEFAULT FALSE,
    notification_sent_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(user_id, forecast_date)
);
```

### Pre-Priming Service Logic

```python
def pre_prime_daily_forecast(user):
    # 1. Get user location
    location = get_user_location(user)
    
    # 2. Fetch weather (1 WeatherKit call - gets 7 days)
    weather = fetch_weather_kit(location)
    # weather.dailyForecast contains all 7 days
    
    # 3. Generate today's daily insight (1 AI call)
    today_weather = weather.currentWeather
    daily_insight = generate_daily_insight(
        weather=today_weather,
        diagnoses=user.diagnoses,
        sensitivities=user.sensitivities
    )
    
    # 4. Generate weekly summary insight (1 AI call)
    weekly_forecast_data = weather.dailyForecast  # All 7 days
    weekly_insight = generate_weekly_forecast_insight(
        weekly_forecast=weekly_forecast_data,
        diagnoses=user.diagnoses,
        sensitivities=user.sensitivities
    )
    
    # 5. Store everything
    store_daily_forecast(
        user=user,
        date=today,
        weather=weather,
        daily_insight=daily_insight,
        weekly_insight=weekly_insight
    )
```

---

## Summary

### API Calls Per User Per Day

**WeatherKit:**
- 1 call (gets current + 7-day forecast + hourly)

**AI API:**
- 2 calls (daily insight + weekly summary)

**Total: 3 API calls per user per day**

### For 1000 Users

**Daily:**
- WeatherKit: 1,000 calls
- AI: 2,000 calls

**Monthly:**
- WeatherKit: 30,000 calls (well within free tier)
- AI: 60,000 calls (~$15-30/month)

### Benefits

- ✅ Users get instant daily + weekly forecast
- ✅ No waiting when app opens
- ✅ Manageable API costs
- ✅ Good balance of completeness vs. cost

---

## Schedule: Two-Phase Process

**EST = UTC-5** (or UTC-4 during daylight saving)

### Phase 1: Pre-Prime (7:45 AM EST)
- 7:45 AM EST = 12:45 PM UTC (standard time)
- 7:45 AM EDT = 11:45 AM UTC (daylight time)

**What happens:**
- Fetch weather + generate insights for all users
- Store in database
- Mark as `notification_sent = FALSE`

### Phase 2: Send Notifications (8:00 AM EST)
- 8:00 AM EST = 1:00 PM UTC (standard time)
- 8:00 AM EDT = 12:00 PM UTC (daylight time)

**What happens:**
- Query ready forecasts
- Send push notifications
- Mark as `notification_sent = TRUE`

**Why split?**
- ✅ 15 minutes to process 1000+ users (3000+ API calls)
- ✅ Data ready before notifications sent
- ✅ No race conditions

**Implementation:**
```python
# Pre-prime service: 7:45 AM EST
pre_prime_schedule = "12:45"  # UTC (adjusts for DST)

# Notification service: 8:00 AM EST
notification_schedule = "13:00"  # UTC (adjusts for DST)
```

---

Ready to implement? This gives users instant daily + weekly forecasts with reasonable API costs!
