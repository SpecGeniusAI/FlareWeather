# Daily Flare Forecast Notification - Implementation Plan

## Schedule: Two-Phase Daily Process

### Phase 1: Pre-Prime Data (7:45 AM EST)
**EST = UTC-5** (or UTC-4 during daylight saving)
- **7:45 AM EST** = **12:45 PM UTC** (standard time)
- **7:45 AM EDT** = **11:45 AM UTC** (daylight time)

**What happens:**
- Fetch weather data for all active users
- Generate daily + weekly insights
- Store everything in `daily_forecasts` table
- Mark records as `notification_sent = FALSE` (ready to send)

### Phase 2: Send Notifications (8:00 AM EST)
- **8:00 AM EST** = **1:00 PM UTC** (standard time)
- **8:00 AM EDT** = **12:00 PM UTC** (daylight time)

**What happens:**
- Query all users with `notification_sent = FALSE` for today
- Send push notifications
- Mark as `notification_sent = TRUE`

**Why two phases?**
- ✅ Gives 15 minutes to process all API calls (could be 1000+ users)
- ✅ Users get notifications only when data is ready
- ✅ No race conditions (data exists before notification)

---

## What Gets Pre-Primed

### 1. Weather Data (1 WeatherKit API call per user)
- Current weather (today)
- Hourly forecast (next 24 hours)
- Daily forecast (next 7 days) - **All included in one call!**

### 2. AI Insights (2 AI API calls per user)
- **Daily insight** (today's flare forecast)
- **Weekly summary insight** (summary of next 7 days)

---

## API Call Breakdown

### Per User Per Day

**WeatherKit:**
- 1 call (gets everything: current + hourly + 7-day forecast)

**AI API (Claude/gpt-4o-mini):**
- 1 call for daily insight
- 1 call for weekly summary insight

**Total: 3 API calls per user per day**

### For 1000 Users

**Daily:**
- WeatherKit: 1,000 calls
- AI: 2,000 calls

**Monthly:**
- WeatherKit: 30,000 calls/month
  - ✅ Well within free tier (500K/month)
- AI: 60,000 calls/month
  - Cost: ~$15-30/month (depending on model)

---

## Database Schema

```sql
CREATE TABLE daily_forecasts (
    id VARCHAR PRIMARY KEY,
    user_id VARCHAR NOT NULL REFERENCES users(id),
    forecast_date DATE NOT NULL,  -- YYYY-MM-DD
    
    -- Location
    location_latitude FLOAT NOT NULL,
    location_longitude FLOAT NOT NULL,
    location_name VARCHAR,
    
    -- Weather data (from 1 WeatherKit call)
    current_weather JSONB,      -- Today's current conditions
    hourly_forecast JSONB,      -- Next 24 hours
    daily_forecast JSONB,       -- Next 7 days (all days)
    
    -- Today's daily insight (from 1 AI call)
    daily_risk_level VARCHAR,   -- "LOW", "MODERATE", "HIGH"
    daily_forecast_summary TEXT,
    daily_why_explanation TEXT,
    daily_insight JSONB,        -- Full daily insight object
    daily_comfort_tip TEXT,
    
    -- Weekly summary insight (from 1 AI call)
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

### Update User Table

```sql
ALTER TABLE users ADD COLUMN push_notification_token VARCHAR;
ALTER TABLE users ADD COLUMN push_notifications_enabled BOOLEAN DEFAULT TRUE;
ALTER TABLE users ADD COLUMN last_location_latitude FLOAT;
ALTER TABLE users ADD COLUMN last_location_longitude FLOAT;
ALTER TABLE users ADD COLUMN last_location_name VARCHAR;
```

---

## Background Services

### Service 1: `pre_prime_forecasts.py` (7:45 AM EST)

**Runs:** Daily at 7:45 AM EST (12:45 PM UTC / 11:45 AM UTC during DST)

**Process:**

1. **Get Active Users**
   ```python
   # Users who logged in within last 7 days
   active_users = db.query(User).filter(
       User.updated_at >= datetime.now() - timedelta(days=7)
   ).all()
   ```

2. **For Each User:**
   ```python
   for user in active_users:
       try:
           # Get location (from User table or last forecast)
           location = get_user_location(user)
           
           # 1. Fetch weather (1 WeatherKit call)
           weather = fetch_weather_kit(location)
           # Returns: current + hourly + 7-day forecast
           
           # 2. Generate daily insight (1 AI call)
           daily_insight = generate_daily_insight(
               weather=weather.currentWeather,
               diagnoses=user.diagnoses,
               sensitivities=user.sensitivities
           )
           
           # 3. Generate weekly summary (1 AI call)
           weekly_insight = generate_weekly_forecast_insight(
               weekly_forecast=weather.dailyForecast,  # All 7 days
               diagnoses=user.diagnoses,
               sensitivities=user.sensitivities
           )
           
           # 4. Store in database (notification_sent = FALSE)
           store_daily_forecast(
               user=user,
               date=today,
               weather=weather,
               daily_insight=daily_insight,
               weekly_insight=weekly_insight,
               notification_sent=False  # Ready to send, but not sent yet
           )
           
           print(f"✅ Pre-primed forecast for {user.email}")
       except Exception as e:
           print(f"❌ Error pre-priming for {user.email}: {e}")
           # Continue with next user
   ```

**Timing:**
- Processes users sequentially or in batches
- Takes ~15 minutes for 1000 users (3 API calls × 1000 = 3000 calls)
- Should complete before 8:00 AM EST

---

### Service 2: `send_daily_notifications.py` (8:00 AM EST)

**Runs:** Daily at 8:00 AM EST (1:00 PM UTC / 12:00 PM UTC during DST)

**Process:**

```python
# Get all users with ready forecasts that haven't been notified
today = datetime.now().date()
ready_forecasts = db.query(DailyForecast).filter(
    DailyForecast.forecast_date == today,
    DailyForecast.notification_sent == False
).all()

for forecast in ready_forecasts:
    user = db.query(User).filter(User.id == forecast.user_id).first()
    
    if not user:
        continue
    
    # Only send if user has token and notifications enabled
    if user.push_notification_token and user.push_notifications_enabled:
        try:
            # Build notification
            risk_level = forecast.daily_risk_level or "MODERATE"
            summary = forecast.daily_forecast_summary or "Check your daily forecast"
            
            send_push_notification(
                token=user.push_notification_token,
                title="Daily Flare Forecast",
                body=f"Today's flare risk: {risk_level} - {summary[:50]}...",
                data={
                    "type": "daily_forecast",
                    "date": str(today),
                    "risk_level": risk_level
                }
            )
            
            # Mark as sent
            forecast.notification_sent = True
            forecast.notification_sent_at = datetime.now()
            db.commit()
            
            print(f"✅ Sent notification to {user.email}")
        except Exception as e:
            print(f"❌ Error sending notification to {user.email}: {e}")
```

**Timing:**
- Runs after pre-prime completes (8:00 AM EST)
- Only sends to users with ready data
- Fast (just database queries + push sends)

---

## Benefits of Pre-Priming Weekly

### User Experience
- ✅ **Instant weekly forecast** - No waiting when user opens app
- ✅ **Complete picture** - Users see both daily + weekly context
- ✅ **Better planning** - Users know what to expect for the week

### API Efficiency
- ✅ **WeatherKit**: Only 1 call per user (gets everything)
- ✅ **AI**: 2 calls per user (daily + weekly summary)
- ✅ **Reasonable cost**: ~$15-30/month for 1000 users

---

## Storage Impact

**Per user per day:**
- Weather data (7 days): ~5 KB
- Daily insight: ~2 KB
- Weekly insight: ~1 KB
- **Total: ~8 KB per user per day**

**For 1000 users:**
- 8 KB × 1000 = 8 MB/day
- 8 MB × 30 = 240 MB/month
- ✅ Negligible database cost

---

## Timing Benefits

**Why 7:45 AM + 8:00 AM split?**

1. **Processing Time**
   - 1000 users × 3 API calls = 3000 calls
   - At ~0.5 seconds per call = ~25 minutes total
   - 15 minutes gives us buffer for API rate limits/retries

2. **Data Ready Before Notifications**
   - Users get notifications only when data exists
   - No "checking..." states when they tap notification
   - Instant load when app opens

3. **Error Handling**
   - If pre-prime fails for some users, they just don't get notified
   - No partial notifications sent
   - Can retry failed users later

4. **Scalability**
   - Can process in batches (e.g., 100 users at a time)
   - Can parallelize API calls if needed
   - 15-minute window gives flexibility

---

## Next Steps

Ready to implement:
1. Database schema (daily_forecasts table)
2. Pre-priming service (runs at 7:45 AM EST)
3. Notification sending service (runs at 8:00 AM EST)
4. Push notification setup (APNs)
5. iOS integration

Should I start building this?
