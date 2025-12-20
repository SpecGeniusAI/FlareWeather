# Scheduling Daily Forecast Services

## Overview

Two services need to run daily:
1. **Pre-prime forecasts** (7:45 AM EST) - Fetches weather and generates insights
2. **Send notifications** (8:00 AM EST) - Sends push notifications

## Schedule Times

- **7:45 AM EST** = **12:45 PM UTC** (standard time) / **11:45 AM UTC** (daylight time)
- **8:00 AM EST** = **1:00 PM UTC** (standard time) / **12:00 PM UTC** (daylight time)

## Railway Scheduling Options

### Option 1: Railway Cron Jobs (Recommended)

Railway supports cron jobs. Add to `railway.toml`:

```toml
[build]
builder = "nixpacks"

[deploy]
startCommand = "uvicorn app:app --host 0.0.0.0 --port $PORT"

# Cron jobs
[[cron]]
schedule = "45 12 * * *"  # 7:45 AM EST (12:45 UTC)
command = "python pre_prime_forecasts.py"

[[cron]]
schedule = "0 13 * * *"   # 8:00 AM EST (1:00 PM UTC)
command = "python send_daily_notifications.py"
```

**Note:** Railway cron uses UTC. Adjust for EST/EDT:
- EST (winter): UTC-5 → 12:45 UTC = 7:45 AM EST
- EDT (summer): UTC-4 → 11:45 UTC = 7:45 AM EDT

### Option 2: External Cron Service

Use a service like:
- **Cronitor** (https://cronitor.io)
- **EasyCron** (https://www.easycron.com)
- **GitHub Actions** (scheduled workflows)

Configure to call Railway webhook or use Railway CLI:

```bash
# Pre-prime (7:45 AM EST)
railway run python pre_prime_forecasts.py

# Send notifications (8:00 AM EST)
railway run python send_daily_notifications.py
```

### Option 3: Background Service with Sleep

Create a single service that runs continuously and sleeps until the right time:

```python
# daily_forecast_scheduler.py
import schedule
import time
from datetime import datetime
import pytz

EST = pytz.timezone("America/New_York")

def pre_prime():
    from pre_prime_forecasts import pre_prime_forecasts
    pre_prime_forecasts()

def send_notifications():
    from send_daily_notifications import send_daily_notifications
    send_daily_notifications()

# Schedule at 7:45 AM EST
schedule.every().day.at("07:45").do(pre_prime)

# Schedule at 8:00 AM EST
schedule.every().day.at("08:00").do(send_notifications)

while True:
    schedule.run_pending()
    time.sleep(60)  # Check every minute
```

Run this as a separate Railway service.

## Environment Variables Required

### For Pre-Priming Service

```bash
OPENWEATHER_API_KEY=your_openweather_api_key
DATABASE_URL=your_database_url
OPENAI_API_KEY=your_openai_key  # or ANTHROPIC_API_KEY
```

### For Notification Service

```bash
APNS_KEY_ID=your_apns_key_id
APNS_TEAM_ID=your_apns_team_id
APNS_BUNDLE_ID=com.specgenius.FlareWeather
APNS_KEY_PATH=/path/to/key.p8  # or APNS_KEY_CONTENT (base64)
APNS_USE_SANDBOX=true  # or false for production
DATABASE_URL=your_database_url
```

## Testing

### Test Pre-Priming Locally

```bash
# Set environment variables
export OPENWEATHER_API_KEY=your_key
export DATABASE_URL=your_database_url

# Run
python pre_prime_forecasts.py
```

### Test Notifications Locally

```bash
# Set environment variables
export APNS_KEY_ID=your_key_id
export APNS_TEAM_ID=your_team_id
export APNS_KEY_CONTENT=your_key_content
export DATABASE_URL=your_database_url

# Run
python send_daily_notifications.py
```

### Test on Railway

```bash
# Pre-prime
railway run python pre_prime_forecasts.py

# Send notifications
railway run python send_daily_notifications.py
```

## Monitoring

Check logs in Railway dashboard:
- Pre-prime service should show: "✅ Pre-primed forecast for {user}"
- Notification service should show: "✅ Sent notification to {user}"

## Troubleshooting

### Pre-Prime Fails

1. Check `OPENWEATHER_API_KEY` is set
2. Check user locations are stored (`last_location_latitude`, `last_location_longitude`)
3. Check database connection
4. Check API rate limits

### Notifications Not Sending

1. Check APNs credentials are correct
2. Check `APNS_USE_SANDBOX` matches your environment
3. Check users have `push_notification_token` set
4. Check `push_notifications_enabled` is `true`
5. Verify APNs key format (should have PEM headers)

### Timezone Issues

EST/EDT automatically handled by `pytz.timezone("America/New_York")`.

For cron, use UTC times:
- EST: 12:45 UTC (7:45 AM EST)
- EDT: 11:45 UTC (7:45 AM EDT)

Or use a timezone-aware scheduler.
