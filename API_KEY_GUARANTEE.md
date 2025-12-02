# How to Ensure API Key Always Works

## ✅ Current Configuration

The OpenWeatherMap API key is now configured in `project.pbxproj` for both Debug and Release configurations. This ensures it works in:
- ✅ Local development (Debug builds)
- ✅ TestFlight builds (Release builds)
- ✅ App Store builds (Release builds)

## 🔍 Verification Methods

### 1. Build-Time Verification (Automatic)

Run the verification script to check configuration:
```bash
./FlareWeather/verify_api_key.sh
```

This checks:
- ✅ API key exists in project.pbxproj
- ✅ API key is in both Debug and Release configurations
- ✅ API key has a value (not empty)
- ✅ API key length is valid (≥32 characters)

### 2. Runtime Verification (Automatic)

The app automatically validates the API key at startup:
- ✅ Checks Info.plist first (works in TestFlight)
- ✅ Checks environment variable second (works in development)
- ✅ Validates key length (≥32 characters)
- ✅ Logs validation status to console

### 3. Manual Verification

Check console logs when app starts:
```
✅ WeatherService: API key validated successfully (length: 32 characters)
✅ WeatherService: API key found in Info.plist as 'OpenWeatherAPIKey' (length: 32)
```

If you see:
```
❌ WeatherService: API key validation failed - no key found
```
Then the API key is not properly configured.

## 🛡️ How to Ensure It Always Works

### 1. Configuration in project.pbxproj

The API key is stored in `project.pbxproj` as:
```pbxproj
INFOPLIST_KEY_OpenWeatherAPIKey = "283e823d16ee6e1ba0c625505e5df181";
```

**Both Debug and Release configurations must have this key.**

### 2. Priority Order

The app checks for the API key in this order:
1. **Info.plist** (`OpenWeatherAPIKey`) - Works in TestFlight and production
2. **Environment variable** (`OPENWEATHER_API_KEY`) - Works in development only

**TestFlight builds ONLY use Info.plist**, so the key MUST be in `project.pbxproj`.

### 3. Build Process

When you build the app:
1. Xcode reads `project.pbxproj`
2. Generates `Info.plist` from `INFOPLIST_KEY_*` values
3. App reads from `Bundle.main.infoDictionary["OpenWeatherAPIKey"]`

### 4. Verification Checklist

Before each TestFlight build:
- [ ] Run `./FlareWeather/verify_api_key.sh` (should pass)
- [ ] Check console logs for validation message
- [ ] Test weather data loads correctly
- [ ] Verify API key is in both Debug and Release configurations

## 🚨 Common Issues & Fixes

### Issue 1: API Key Not Found in TestFlight

**Symptoms**: "Weather API key not configured" error in TestFlight

**Cause**: API key is only in environment variable (not in Info.plist)

**Fix**: Add `INFOPLIST_KEY_OpenWeatherAPIKey` to `project.pbxproj` for Release configuration

### Issue 2: API Key Not in Release Configuration

**Symptoms**: Works in Debug but not in TestFlight

**Cause**: API key is only in Debug configuration

**Fix**: Add `INFOPLIST_KEY_OpenWeatherAPIKey` to Release configuration in `project.pbxproj`

### Issue 3: API Key Value is Empty

**Symptoms**: API key found but weather data fails

**Cause**: API key value is empty or not properly quoted

**Fix**: Ensure API key value is properly quoted in `project.pbxproj`:
```pbxproj
INFOPLIST_KEY_OpenWeatherAPIKey = "your_api_key_here";
```

### Issue 4: API Key Format Wrong

**Symptoms**: API key found but doesn't work

**Cause**: API key might have extra whitespace or wrong format

**Fix**: 
1. Check API key is properly quoted (string)
2. Remove any extra whitespace
3. Verify API key is valid (32 characters, alphanumeric)

## 📋 Maintenance Checklist

### Before Each TestFlight Build

1. **Verify Configuration**
   ```bash
   ./FlareWeather/verify_api_key.sh
   ```

2. **Check project.pbxproj**
   ```bash
   grep -i "OpenWeatherAPIKey" FlareWeather/FlareWeather.xcodeproj/project.pbxproj
   ```
   Should show 2 lines (Debug and Release)

3. **Test on Device**
   - Build for Release
   - Install on physical device
   - Check console for: `✅ WeatherService: API key validated successfully`
   - Verify weather data loads

### After Each Xcode Update

1. **Verify API key is still in project.pbxproj**
   ```bash
   ./FlareWeather/verify_api_key.sh
   ```

2. **Check if Xcode modified the configuration**
   - Sometimes Xcode updates can reset configurations
   - Verify API key is still present

### If API Key Changes

1. **Update project.pbxproj**
   - Update `INFOPLIST_KEY_OpenWeatherAPIKey` in both Debug and Release
   - Ensure value is properly quoted

2. **Verify Configuration**
   ```bash
   ./FlareWeather/verify_api_key.sh
   ```

3. **Test on Device**
   - Build and test to ensure new key works

## 🔐 Security Considerations

### API Key Storage

- ✅ **Info.plist**: Secure for TestFlight/production (not exposed to users)
- ⚠️ **Environment Variables**: Only work in development (not in TestFlight)
- ❌ **Source Code**: Never hardcode API keys in source code

### Best Practices

1. **Don't commit API keys to git** (if possible)
   - Use environment variables for local development
   - Use Info.plist for TestFlight/production (but be careful with git)

2. **Rotate API keys regularly**
   - Update API key in project.pbxproj
   - Verify configuration after update
   - Test on device

3. **Monitor API key usage**
   - Check OpenWeatherMap dashboard for usage
   - Set up alerts for unusual activity

## 🧪 Testing

### Local Testing

1. **Build for Debug**
   ```bash
   # API key should work from environment variable or Info.plist
   ```

2. **Build for Release**
   ```bash
   # API key should work from Info.plist
   ```

3. **Test on Physical Device**
   - Install app on device
   - Check console logs
   - Verify weather data loads

### TestFlight Testing

1. **Archive App**
   - Product → Archive
   - Uses Release configuration
   - API key should be in Info.plist

2. **Upload to TestFlight**
   - Distribute App → App Store Connect
   - Test on TestFlight device
   - Verify weather data loads

## 📝 Summary

### How It Works

1. **Configuration**: API key is in `project.pbxproj` as `INFOPLIST_KEY_OpenWeatherAPIKey`
2. **Build**: Xcode generates `Info.plist` from `project.pbxproj` settings
3. **Runtime**: App reads from `Bundle.main.infoDictionary["OpenWeatherAPIKey"]`
4. **Validation**: App validates API key at startup

### How to Ensure It Always Works

1. **Keep API key in project.pbxproj** (both Debug and Release)
2. **Run verification script** before each TestFlight build
3. **Test on physical device** to verify it works
4. **Check console logs** for validation messages
5. **Verify configuration** after Xcode updates

### Verification Command

```bash
./FlareWeather/verify_api_key.sh
```

This will verify:
- ✅ API key exists in project.pbxproj
- ✅ API key is in both configurations
- ✅ API key has a value
- ✅ API key length is valid

## 🎯 Quick Reference

### Check API Key Configuration
```bash
grep -i "OpenWeatherAPIKey" FlareWeather/FlareWeather.xcodeproj/project.pbxproj
```

### Verify Configuration
```bash
./FlareWeather/verify_api_key.sh
```

### Test on Device
1. Build for Release
2. Install on physical device
3. Check console: `✅ WeatherService: API key validated successfully`
4. Verify weather data loads

### If Not Working
1. Check console logs for error messages
2. Run verification script
3. Verify API key is in project.pbxproj (both Debug and Release)
4. Clean build folder and rebuild
5. Test on physical device

