# Backend URL Configuration Guide

## Overview
The FlareWeather app needs to know where your backend API is hosted. This guide explains how to configure the backend URL for both development and production.

## Configuration Methods

### Method 1: Environment Variable (Recommended for Development)

1. **Open Xcode**
2. **Select your scheme**: Click on the scheme selector (next to the Run/Stop buttons) → Edit Scheme
3. **Go to Run → Arguments**
4. **Add Environment Variable**:
   - Click the "+" button
   - Name: `BACKEND_URL`
   - Value: `http://localhost:8000` (for local development)
   - Or: `https://your-production-url.railway.app` (for production)

### Method 2: Info.plist (Recommended for Production)

1. **Find Info.plist** in your Xcode project
2. **Add a new key**:
   - Key: `BackendURL`
   - Type: `String`
   - Value: `https://your-production-url.railway.app`

### Method 3: Default (Development Only)

If neither environment variable nor Info.plist is set, the app defaults to:
- `http://localhost:8000` (for local development)

## URL Examples

### Local Development
```
http://localhost:8000
```

### Railway Production
```
https://flareweather-production.up.railway.app
```

**Your existing Railway project:** `flareweather-production.up.railway.app`

### Custom Domain
```
https://api.flareweather.app
```

## How It Works

The `AIInsightsService` checks for the backend URL in this order:
1. **Environment Variable** (`BACKEND_URL`) - Highest priority
2. **Info.plist** (`BackendURL`) - Medium priority
3. **Default** (`http://localhost:8000`) - Fallback

## Testing

After setting the URL, check the Xcode console for one of these messages:
- `✅ AIInsightsService: Backend URL found in environment variable: [URL]`
- `✅ AIInsightsService: Backend URL found in Info.plist: [URL]`
- `⚠️ AIInsightsService: Using default backend URL: http://localhost:8000`

## Production Deployment

For production builds:
1. Set the `BackendURL` key in `Info.plist` to your production URL
2. Or use Xcode's build configurations to set different URLs for Debug vs Release
3. Ensure the URL uses HTTPS (required for App Store)

## Troubleshooting

### Connection Errors
- Verify the backend is running and accessible
- Check the URL is correct (no trailing slashes)
- Ensure the backend CORS settings allow requests from your app

### Local Development Issues
- Make sure your Mac and iOS Simulator can reach `localhost:8000`
- For physical device testing, use your Mac's IP address: `http://192.168.1.XXX:8000`

### Production Issues
- Verify the production URL is correct
- Check that the backend is deployed and running
- Ensure SSL certificate is valid (HTTPS required)

