# Daily Flare Forecast Push Notification - Design

## User Experience Flow

```
Morning (8:00 AM):
1. Background service pre-primes forecasts for all users
2. Service generates daily flare forecast for each user
3. Push notification sent: "Today's flare risk: LOW - Steady pressure expected"
4. User taps notification → App opens → Instant display of forecast
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Morning Pre-Priming Service (Railway)                  │
│  ┌───────────────────────────────────────────────────┐ │
│  │  1. Fetch weather for all active users            │ │
│  │  2. Generate daily flare forecast (AI insight)    │ │
│  │  3. Store in database                             │ │
│  │  4. Send push notifications                       │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│  Database (PostgreSQL)                                   │
│  ┌───────────────────────────────────────────────────┐ │
│  │  daily_forecasts table                           │ │
│  │  - user_id                                       │ │
│  │  - date (YYYY-MM-DD)                            │ │
│  │  - weather_data (JSON)                           │ │
│  │  - flare_forecast (JSON) - AI insight            │ │
│  │  - risk_level (LOW/MODERATE/HIGH)                │ │
│  │  - notification_sent (boolean)                   │ │
│  │  - created_at                                    │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│  Push Notification Service                               │
│  ┌───────────────────────────────────────────────────┐ │
│  │  Apple Push Notification Service (APNs)           │ │
│  │  - Sends notification with forecast summary       │ │
│  │  - Deep link to app with forecast data            │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│  iOS App                                                 │
│  ┌───────────────────────────────────────────────────┐ │
│  │  User taps notification                           │ │
│  │  → App opens with deep link                       │ │
│  │  → Loads pre-primed forecast instantly            │ │
│  │  → Shows daily flare forecast                     │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

---

## Database Schema

### New Table: `daily_forecasts`

```sql
CREATE TABLE daily_forecasts (
    id VARCHAR PRIMARY KEY,
    user_id VARCHAR NOT NULL REFERENCES users(id),
    forecast_date DATE NOT NULL,  -- YYYY-MM-DD format
    
    -- Location
    location_latitude FLOAT NOT NULL,
    location_longitude FLOAT NOT NULL,
    location_name VARCHAR,
    
    -- Weather data (pre-fetched)
    current_weather JSONB,      -- Current conditions
    hourly_forecast JSONB,      -- Next 24 hours
    daily_forecast JSONB,       -- Next 7 days
    
    -- AI-generated flare forecast
    risk_level VARCHAR,         -- "LOW", "MODERATE", "HIGH"
    forecast_summary TEXT,      -- Main forecast message
    why_explanation TEXT,       -- Why bodies may notice
    daily_insight JSONB,        -- Full daily insight object
    comfort_tip TEXT,           -- Eastern medicine tip
    
    -- Notification
    notification_sent BOOLEAN DEFAULT FALSE,
    notification_sent_at TIMESTAMP,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Unique constraint: one forecast per user per day
    UNIQUE(user_id, forecast_date),
    
    -- Indexes
    INDEX idx_daily_forecasts_user_date (user_id, forecast_date),
    INDEX idx_daily_forecasts_date (forecast_date),
    INDEX idx_daily_forecasts_notification (notification_sent, forecast_date)
);
```

### Update `User` table

```sql
ALTER TABLE users ADD COLUMN push_notification_token VARCHAR;
ALTER TABLE users ADD COLUMN push_notifications_enabled BOOLEAN DEFAULT TRUE;
ALTER TABLE users ADD COLUMN notification_time TIME DEFAULT '08:00:00';  -- Default 8 AM
ALTER TABLE users ADD COLUMN timezone VARCHAR DEFAULT 'UTC';
```

---

## Background Service

### Service: `daily_forecast_service.py`

**Schedule:** Runs once daily at 8:00 AM (configurable per user timezone)

**What it does:**

1. **Pre-Prime Weather** (for all active users)
   ```python
   for user in active_users:
       # Get user's location
       location = get_user_location(user)
       
       # Fetch weather from WeatherKit
       weather_data = fetch_weather(location)
       
       # Store in daily_forecasts table
       store_weather(user, weather_data, date=today)
   ```

2. **Generate Flare Forecasts** (AI insights)
   ```python
   for user in active_users:
       # Get pre-primed weather
       weather = get_daily_forecast(user, date=today)
       
       # Get user's diagnoses/sensitivities
       diagnoses = user.diagnoses
       sensitivities = user.sensitivities
       
       # Generate AI insight (same as current /analyze endpoint)
       insight = generate_daily_insight(
           weather=weather,
           diagnoses=diagnoses,
           sensitivities=sensitivities
       )
       
       # Store forecast
       update_daily_forecast(user, date=today, insight=insight)
   ```

3. **Send Push Notifications**
   ```python
   for user in active_users:
       if not user.push_notifications_enabled:
           continue
       
       forecast = get_daily_forecast(user, date=today)
       
       # Build notification message
       message = f"Today's flare risk: {forecast.risk_level}"
       if forecast.forecast_summary:
           message += f" - {forecast.forecast_summary[:50]}"
       
       # Send push notification
       send_push_notification(
           token=user.push_notification_token,
           title="Daily Flare Forecast",
           body=message,
           data={
               "type": "daily_forecast",
               "date": today,
               "risk_level": forecast.risk_level
           }
       )
       
       # Mark as sent
       mark_notification_sent(user, date=today)
   ```

---

## Push Notification Setup

### iOS: Register for Push Notifications

**In `FlareWeatherApp.swift`:**
```swift
import UserNotifications

init() {
    // Request notification permission
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        if granted {
            // Register for remote notifications
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}
```

**Send token to backend:**
```swift
// When device token is received
func application(_ application: UIApplication, 
                didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    
    // Send to backend: POST /user/push-token
    // Store in User.push_notification_token
}
```

### Backend: Send Push Notifications

**New endpoint: `POST /user/push-token`**
```python
@app.post("/user/push-token")
async def update_push_token(
    token: str,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    user = db.query(User).filter(User.id == current_user["user_id"]).first()
    user.push_notification_token = token
    db.commit()
    return {"success": True}
```

**Push notification service:**
```python
# Use PyAPNs2 or similar library
from apns2.client import APNsClient
from apns2.payload import Payload

def send_push_notification(token, title, body, data):
    client = APNsClient(
        credentials=APNS_CREDENTIALS,
        use_sandbox=False  # Use True for development
    )
    
    payload = Payload(
        alert={"title": title, "body": body},
        sound="default",
        badge=1,
        custom=data
    )
    
    client.send_notification(token, payload, topic="com.yourcompany.flareweather")
```

---

## iOS: Handle Notification Tap

**In `FlareWeatherApp.swift`:**
```swift
// Handle notification tap
func userNotificationCenter(_ center: UNUserNotificationCenter,
                           didReceive response: UNNotificationResponse,
                           withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    
    if let type = userInfo["type"] as? String, type == "daily_forecast" {
        // Deep link to forecast view
        // Load pre-primed forecast from backend
        // Show instantly
    }
    
    completionHandler()
}
```

**In `HomeView.swift`:**
```swift
.onAppear {
    // Check if opened from notification
    if let forecastDate = notificationForecastDate {
        // Load pre-primed forecast for this date
        await loadPrePrimedForecast(date: forecastDate)
    } else {
        // Normal app open - load today's forecast
        await loadPrePrimedForecast(date: today)
    }
}
```

---

## Backend API Endpoints

### 1. `GET /user/daily-forecast/{date}`

Returns pre-primed forecast for a specific date.

**Response:**
```json
{
    "date": "2025-12-10",
    "weather": {
        "current": {...},
        "hourly": [...],
        "daily": [...]
    },
    "flare_forecast": {
        "risk": "LOW",
        "forecast": "Steady pressure today may feel steadier.",
        "why": "Higher pressure can reduce inflammation...",
        "daily_insight": {
            "summary_sentence": "...",
            "why_line": "...",
            "comfort_tip": "...",
            "sign_off": "..."
        }
    },
    "fetched_at": "2025-12-10T08:00:00Z"
}
```

### 2. `POST /user/push-token`

Register/update push notification token.

### 3. `PUT /user/notification-settings`

Update notification preferences (enable/disable, time).

---

## Scheduling

### Option 1: Single Time (8 AM UTC)

**Pros:** Simple, one service runs at 8 AM
**Cons:** Not personalized (8 AM UTC = different local times)

### Option 2: Per-User Timezone

**Pros:** Personalized (8 AM in user's timezone)
**Cons:** More complex, need to handle multiple timezones

**Implementation:**
```python
# Group users by timezone
users_by_timezone = group_users_by_timezone()

# For each timezone, schedule at 8 AM local time
for timezone, users in users_by_timezone.items():
    schedule_at = get_8am_in_timezone(timezone)
    # Run pre-priming for these users at scheduled time
```

### Option 3: User-Configurable Time

**Pros:** Users choose their preferred time
**Cons:** Most complex

**Recommendation:** Start with Option 1 (8 AM UTC), add timezone support later.

---

## Notification Message Examples

**LOW Risk:**
```
"Today's flare risk: LOW - Steady pressure expected. Your body may feel more balanced today."
```

**MODERATE Risk:**
```
"Today's flare risk: MODERATE - Pressure changes ahead. Chinese medicine recommends gentle movement."
```

**HIGH Risk:**
```
"Today's flare risk: HIGH - Significant pressure drop expected. Take extra care today."
```

---

## Benefits

### User Experience
- ✅ **Daily reminder** - Users get consistent daily forecast
- ✅ **Instant loading** - Pre-primed data loads immediately
- ✅ **Proactive** - Users know what to expect before symptoms
- ✅ **Engagement** - Daily touchpoint keeps users coming back

### Technical
- ✅ **Efficient** - Batch processing in background
- ✅ **Reliable** - Pre-generated, no waiting for API calls
- ✅ **Scalable** - Can handle thousands of users
- ✅ **Offline-friendly** - Data ready even if network is slow

---

## Implementation Steps

### Phase 1: Pre-Priming
1. Create `daily_forecasts` table
2. Build pre-priming service
3. Schedule to run daily at 8 AM
4. Test with a few users

### Phase 2: Push Notifications
1. Set up APNs (Apple Push Notification service)
2. Add push token registration in iOS app
3. Build notification sending service
4. Test notifications

### Phase 3: iOS Integration
1. Handle notification taps
2. Load pre-primed forecast on open
3. Display forecast instantly
4. Test full flow

### Phase 4: Polish
1. Add notification preferences
2. Timezone support
3. Notification scheduling
4. Analytics/metrics

---

## Cost Estimate

### Database
- ~5-10 KB per user per day
- 1000 users × 30 days = ~300 MB/month
- Negligible cost

### WeatherKit API
- 1000 users × 1 fetch/day = 30,000 calls/month
- Well within free tier (500K/month)

### Push Notifications
- Apple APNs is free
- No cost for sending notifications

### Railway Service
- One service running daily (not 24/7)
- Minimal cost (~$2-5/month)

---

## Questions

1. **What time?** 8 AM in user's timezone or UTC?
2. **Which users?** All users or only active subscribers?
3. **Notification content?** Just risk level or full forecast?
4. **Opt-out?** Allow users to disable notifications?

Let me know if you want me to implement this!
