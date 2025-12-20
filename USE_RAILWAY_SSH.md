# Use Railway SSH to Run the Script

According to Railway's documentation, you can SSH directly into your service using the CLI.

## Quick Steps

Since you're already linked to FlareWeather service, just run:

```bash
railway ssh
```

This will open a shell **inside** your Railway container where the package is installed.

Then run:

```bash
python3 query_apple_subscriptions.py
```

## Alternative: Run Command Directly via SSH

You can also run the command directly without opening an interactive shell:

```bash
railway ssh -- python3 query_apple_subscriptions.py
```

This runs the command and shows the output immediately.

---

## If SSH Doesn't Work

Make sure:
1. The service is running (not sleeping)
2. You're linked to the correct service: `railway service` (should show FlareWeather)
3. You're logged in: `railway whoami`
