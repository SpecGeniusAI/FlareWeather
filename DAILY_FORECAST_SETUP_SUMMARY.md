# Daily Forecast Notification - Setup Summary

## ✅ What's Been Implemented

### 1. Database Schema
- ✅ `daily_forecasts` table created
- ✅ User table updated with:
  - `push_notification_token`
  - `push_notifications_enabled`
  - `last_location_latitude`
  - `last_location_longitude`
  - `last_location_name`

### 2. Pre-Priming Service (`pre_prime_forecasts.py`)
- ✅ Fetches weather from OpenWeatherMap API
- ✅ Generates daily insight (1 AI call per user)
- ✅ Generates weekly summary insight (1 AI call per user)
- ✅ Stores everything in `daily_forecasts` table
- ✅ Runs at 7:45 AM EST

### 3. Notification Service (`send_daily_notifications.py`)
- ✅ Sends push notifications via APNs
- ✅ Only sends to users with ready forecasts
- ✅ Marks forecasts as sent
- ✅ Runs at 8:00 AM EST

### 4. API Endpoints
- ✅ `POST /user/push-token` - Register push token
- ✅ `PUT /user/notification-settings` - Update notification preferences
- ✅ `GET /user/daily-forecast` - Get today's forecast
- ✅ `GET /user/daily-forecast/{date}` - Get forecast for specific date

### 5. Dependencies
- ✅ Added `PyJWT`, `cryptography`, `pytz` to `requirements.txt`

---

## 🔧 Next Steps

### 1. Set Up Environment Variables

**For Pre-Priming:**
```bash
OPENWEATHER_API_KEY=your_openweather_api_key
```

**For Notifications:**
```bash
APNS_KEY_ID=your_apns_key_id
APNS_TEAM_ID=your_apns_team_id
APNS_BUNDLE_ID=com.specgenius.FlareWeather
APNS_KEY_CONTENT=your_base64_key  # or APNS_KEY_PATH
APNS_USE_SANDBOX=true  # false for production
```

### 2. Set Up Scheduling

See `SCHEDULE_DAILY_FORECASTS.md` for options:
- Railway cron jobs (recommended)
- External cron service
- Background scheduler service

### 3. iOS App Integration

Still needed:
- Register for push notifications
- Send push token to backend
- Handle notification taps
- Load pre-primed forecast on app open

See iOS implementation guide (to be created).

---

## 📊 API Call Summary

**Per user per day:**
- WeatherKit/OpenWeatherMap: 1 call
- AI API: 2 calls (daily + weekly)

**For 1000 users:**
- Daily: 1,000 weather calls + 2,000 AI calls
- Monthly: 30,000 weather calls + 60,000 AI calls
- Cost: ~$15-30/month (AI API)

---

## 🧪 Testing

### Test Pre-Priming
```bash
railway run python pre_prime_forecasts.py
```

### Test Notifications
```bash
railway run python send_daily_notifications.py
```

### Test API Endpoints
```bash
# Register push token
curl -X POST https://your-backend.com/user/push-token \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{"push_token": "device_token_here"}'

# Get today's forecast
curl https://your-backend.com/user/daily-forecast \
  -H "Authorization: Bearer {token}"
```

---

## ⚠️ Important Notes

1. **User Location Required**: Users must have `last_location_latitude` and `last_location_longitude` set for pre-priming to work.

2. **OpenWeatherMap API Key**: You'll need an OpenWeatherMap API key (One Call API 3.0). Free tier: 1,000 calls/day.

3. **APNs Setup**: You need:
   - APNs Key (.p8 file) from Apple Developer
   - Key ID and Team ID
   - Bundle ID matches your app

4. **Timezone Handling**: Services use `pytz.timezone("America/New_York")` to handle EST/EDT automatically.

5. **Error Handling**: Services continue processing other users if one fails.

---

## 📝 Files Created

- `database.py` - Updated with DailyForecast model and User columns
- `pre_prime_forecasts.py` - Pre-priming service
- `send_daily_notifications.py` - Notification sending service
- `models.py` - Updated with push notification models
- `app.py` - Updated with API endpoints
- `requirements.txt` - Updated with dependencies
- `SCHEDULE_DAILY_FORECASTS.md` - Scheduling guide
- `DAILY_FORECAST_SETUP_SUMMARY.md` - This file

---

Ready for iOS integration! 🚀
