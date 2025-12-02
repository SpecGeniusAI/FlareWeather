# TestFlight Readiness Checklist

## ✅ Critical Configuration

### 1. API Keys & Environment Variables

#### OpenWeatherMap API Key
- [ ] **CRITICAL**: Add `OpenWeatherAPIKey` to Info.plist for TestFlight builds
  - Key name: `OpenWeatherAPIKey` (exact, case-sensitive)
  - Value: Your OpenWeatherMap API key
  - Location: Xcode → Project Settings → Info → Custom iOS Target Properties
  - **Note**: Environment variables in Xcode schemes are NOT included in TestFlight builds

#### Backend URL
- [x] ✅ Configured in project.pbxproj as `BackendURL`
- [x] ✅ Default URL: `https://flareweather-production.up.railway.app`
- [x] ✅ Fallback logic: Environment variable → Info.plist → Default URL

### 2. Backend Configuration

#### Railway Backend
- [x] ✅ Production URL: `https://flareweather-production.up.railway.app`
- [ ] Verify backend is running and accessible
- [ ] Verify `/health` endpoint returns 200
- [ ] Verify `/analyze` endpoint responds within timeout (60 seconds)
- [ ] Verify `/auth/*` endpoints are working

#### Environment Variables (Railway)
- [ ] `OPENAI_API_KEY` is set
- [ ] `DATABASE_URL` is set and correct
- [ ] `JWT_SECRET_KEY` is set
- [ ] `PORT` is set (Railway usually sets this automatically)

### 3. Network Configuration

#### Timeouts
- [x] ✅ `/analyze` endpoint: 60 seconds (increased from 30)
- [x] ✅ Other endpoints: 30 seconds
- [x] ✅ Error handling for timeouts is user-friendly

#### Error Handling
- [x] ✅ Network errors show user-friendly messages
- [x] ✅ Timeout errors provide helpful context
- [x] ✅ Backend errors are handled gracefully
- [x] ✅ Cached insights are used as fallback

### 4. App Configuration

#### Info.plist Settings
- [x] ✅ `BackendURL` configured
- [x] ✅ `NSLocationWhenInUseUsageDescription` configured
- [x] ✅ `AppUsesNonExemptEncryption = NO` (for App Store)
- [x] ✅ App category: `public.app-category.healthcare-fitness`
- [ ] `OpenWeatherAPIKey` - **NEEDS TO BE ADDED**

#### Entitlements
- [ ] Sign in with Apple capability enabled
- [ ] Push Notifications capability (if used)
- [ ] Location Services capability

### 5. TestFlight-Specific Features

#### TestFlight Unlock Mode
- [x] ✅ `SubscriptionManager` detects TestFlight builds
- [x] ✅ Premium features unlocked for TestFlight testers
- [x] ✅ Production builds check real subscription status

#### Build Detection
- [x] ✅ `isTestFlightOrDebug` function detects TestFlight builds
- [x] ✅ Uses `sandboxReceipt` to identify TestFlight

### 6. Security & Privacy

#### API Keys
- [x] ✅ API keys are masked in logs (using `***`)
- [x] ✅ No hardcoded API keys in source code
- [x] ✅ API keys loaded from Info.plist (not committed to git)

#### Data Handling
- [x] ✅ User data stored securely in Keychain
- [x] ✅ Authentication tokens stored securely
- [x] ✅ No sensitive data in print statements

#### Network Security
- [x] ✅ All API calls use HTTPS
- [x] ✅ Backend URL uses HTTPS
- [x] ✅ OpenWeatherMap API uses HTTPS

### 7. Error Handling

#### User-Facing Errors
- [x] ✅ Network errors: "Please check your internet connection and try again."
- [x] ✅ Timeout errors: "The analysis is taking longer than expected. This can happen when our AI service is processing complex weather patterns. Please try again in a moment."
- [x] ✅ Backend errors: "We're having trouble connecting to our analysis service right now. Please try again in a moment."
- [x] ✅ Generic errors: "Unable to analyze weather patterns at this time. Please try again later."

#### Fallback Behavior
- [x] ✅ Cached insights are used when API fails
- [x] ✅ Mock data is used when API key is missing
- [x] ✅ Loading states are shown during API calls

### 8. App Store Requirements

#### Encryption
- [x] ✅ `AppUsesNonExemptEncryption = NO` configured
- [x] ✅ Standard encryption only (no custom encryption)

#### Privacy
- [x] ✅ Location permission description is user-friendly
- [x] ✅ No sensitive data collection without user consent
- [x] ✅ Privacy policy and terms of service links are configured

#### Sign in with Apple
- [ ] Apple Sign In capability enabled
- [ ] Apple Sign In configured in App Store Connect
- [ ] Backend handles Apple Sign In correctly

### 9. Code Quality

#### Debug Code
- [x] ✅ Print statements don't expose sensitive data
- [x] ✅ API keys are masked in logs
- [ ] Consider removing excessive print statements for production (optional)

#### Error Logging
- [x] ✅ Errors are logged for debugging
- [x] ✅ User-friendly error messages are shown
- [x] ✅ No sensitive data in error logs

### 10. Testing

#### Pre-TestFlight Testing
- [ ] Test on physical device (not just simulator)
- [ ] Test with no internet connection
- [ ] Test with slow internet connection
- [ ] Test timeout scenarios
- [ ] Test error scenarios
- [ ] Test Sign in with Apple
- [ ] Test location services
- [ ] Test weather API calls
- [ ] Test AI insights generation
- [ ] Test backend connection

#### TestFlight Testing
- [ ] Install via TestFlight
- [ ] Test on multiple devices
- [ ] Test on different iOS versions
- [ ] Test all features
- [ ] Verify API keys work
- [ ] Verify backend connection works
- [ ] Verify error handling works
- [ ] Verify premium features are unlocked

## 🚨 Critical Issues to Fix

### 1. OpenWeatherMap API Key
**Status**: ⚠️ **NOT CONFIGURED IN PROJECT.PBXPROJ**

**Action Required**:
1. Open Xcode
2. Select project → Target → Info
3. Add new key: `OpenWeatherAPIKey`
4. Set value: Your OpenWeatherMap API key
5. Make sure it's set for both Debug and Release configurations

**Impact**: Without this, weather data will not work in TestFlight builds.

### 2. Sign in with Apple
**Status**: ⚠️ **NEEDS VERIFICATION**

**Action Required**:
1. Verify Sign in with Apple capability is enabled in Xcode
2. Verify Apple Sign In is configured in App Store Connect
3. Verify backend handles Apple Sign In correctly
4. Test Apple Sign In flow

**Impact**: Users won't be able to sign in with Apple if not configured.

### 3. Backend Availability
**Status**: ⚠️ **NEEDS VERIFICATION**

**Action Required**:
1. Verify Railway backend is running
2. Verify `/health` endpoint returns 200
3. Verify `/analyze` endpoint responds
4. Verify environment variables are set correctly

**Impact**: App won't work if backend is down or unreachable.

## ✅ Verified Working

1. ✅ Backend URL configuration (defaults to production URL)
2. ✅ Error handling (user-friendly messages)
3. ✅ Timeout handling (60 seconds for `/analyze`)
4. ✅ TestFlight unlock mode (premium features unlocked)
5. ✅ Network error handling (graceful fallbacks)
6. ✅ API key masking in logs (security)
7. ✅ Cached insights fallback (better UX)
8. ✅ App-specific message filtering (removes unwanted messages)
9. ✅ Location services configuration
10. ✅ App Store encryption configuration

## 📝 Notes

- Environment variables in Xcode schemes are **NOT** included in TestFlight builds
- API keys must be in Info.plist for TestFlight to work
- Backend must be accessible from TestFlight devices
- TestFlight testers get premium features unlocked automatically
- Production builds will check real subscription status

## 🔍 Testing Checklist

Before submitting to TestFlight:
- [ ] Test on physical device
- [ ] Test with no internet
- [ ] Test with slow internet
- [ ] Test timeout scenarios
- [ ] Test error scenarios
- [ ] Test all features
- [ ] Verify API keys work
- [ ] Verify backend works
- [ ] Verify error handling works

