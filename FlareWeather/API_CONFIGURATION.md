# API Configuration Guide

## Required API Keys

The FlareWeather app requires the following API keys to function properly:

### 1. OpenWeatherMap API Key (Required for Weather Data)

**Purpose**: Fetch real-time weather data and forecasts

**How to Get**:
1. Go to https://openweathermap.org/api
2. Sign up for a free account
3. Get your API key from the API keys section

**How to Add to iOS App**:

#### Option 1: Xcode Scheme Environment Variable (Recommended for Development)
1. Open Xcode
2. Select your scheme (FlareWeather)
3. Go to Product → Scheme → Edit Scheme
4. Select "Run" on the left
5. Go to "Arguments" tab
6. Under "Environment Variables", add:
   - Name: `OPENWEATHER_API_KEY`
   - Value: `your_api_key_here`
7. Click "Close"

#### Option 2: Info.plist (For Production/TestFlight)
1. Open Xcode
2. Select the FlareWeather target
3. Go to the "Info" tab
4. Add a new key: `OpenWeatherAPIKey`
5. Set value to your API key

**Note**: The app will show an error message if the API key is not configured.

### 2. Backend URL (Already Configured)

The backend URL is already configured in the project:
- Production: `https://flareweather-production.up.railway.app`

This is set in the project's Info.plist as `BackendURL`.

## Testing API Configuration

### Check if OpenWeatherMap API Key is Set:
1. Run the app
2. Check the console logs for:
   - `✅ WeatherService: API key found in environment variable` OR
   - `✅ WeatherService: API key found in Info.plist` OR
   - `⚠️ WeatherService: No API key found in environment or Info.plist`

### Check if Backend URL is Set:
1. Run the app
2. Check the console logs for:
   - `✅ AIInsightsService: Backend URL found in Info.plist: https://flareweather-production.up.railway.app` OR
   - `✅ AIInsightsService: Using production backend URL: https://flareweather-production.up.railway.app`

## Troubleshooting

### Weather Data Shows 22°C (Mock Data)
**Cause**: OpenWeatherMap API key is not configured
**Solution**: Add the API key using one of the methods above

### AI Insights Show "Analyzing weather patterns…"
**Cause**: Backend API is not responding or returning errors
**Solution**: 
1. Check backend logs in Railway
2. Verify backend is deployed and running
3. Check network connectivity

### Network Errors
**Cause**: No internet connection or API endpoints are unreachable
**Solution**:
1. Check internet connection
2. Verify API endpoints are accessible
3. Check firewall/proxy settings

## Environment Variables for TestFlight/Production

For TestFlight and production builds, you need to:

1. **OpenWeatherMap API Key**: Add to Info.plist as `OpenWeatherAPIKey`
2. **Backend URL**: Already configured in Info.plist as `BackendURL`

## Security Notes

- **Never commit API keys to git**
- Use environment variables for development
- Use Info.plist for production (but be careful not to commit sensitive keys)
- Consider using a secrets management service for production apps

