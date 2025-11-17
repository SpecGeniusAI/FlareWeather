# FlareWeather iOS App - Current State Summary

## Overview
FlareWeather is a weather-aware wellness app that provides AI-powered insights on how weather patterns affect health for people with weather-sensitive conditions. The app combines real-time weather data with personalized health tracking and AI-generated daily and weekly insights.

---

## 🎯 Core Features

### 1. **Authentication & User Management**
- **Email/Password Authentication**: Full signup and login flow
- **Apple Sign In**: Integrated Sign in with Apple
- **Password Reset Flow**: 
  - 6-digit code-based password reset
  - Email delivery via Mailgun
  - Secure code hashing and expiration
- **Account Deletion**: User can delete account with confirmation
- **Case-Insensitive Email**: All email lookups are case-insensitive

### 2. **Onboarding Flow** (Linear Navigation)
Complete multi-step onboarding experience:
1. **OnboardingHeroView**: Welcome screen with app value proposition
2. **OnboardingValueView**: Key benefits and features
3. **DiagnosisSelectionView**: Select health conditions (with "Other" option)
4. **SensitivitySelectionView**: Optional weather sensitivity selection
5. **InsightPreviewView**: Preview of daily and weekly insights
6. **PaywallPlaceholderView**: "Start My Free Week" option
7. **AccountCreationView**: Final account creation

**Features:**
- Linear navigation using `NavigationStack`
- State preservation across screens
- Data saved to Core Data and UserDefaults
- Dark mode support
- Smooth transitions

### 3. **AI-Powered Insights**

#### **Daily AI Insight**
- **Format**: Summary → Why → Comfort Tip → Sign-off
- **Why Section**: Uses specific, physical body-sensation language
  - No vague phrases (removed: "supportive", "gentle", "may feel different")
  - Weather never "feels" - only the body does
  - Approved vocabulary: sluggish, draining, tiring, stiff, tense, sensitive, effortful, etc.
  - Examples: "Pressure drops can make the body feel heavy or slow"
- **Icons**: 
  - Info icon (brand green) for "Why" section
  - Hand clap icon (brand green) for "Comfort tip"
- **Sources**: Displayed at bottom after disclaimer
- **Real-time Analysis**: Triggers on weather changes, prevents duplicate triggers

#### **Weekly Forecast Insight**
- **Summary**: Short, one-sentence summary (no numbers, no templates)
- **Day Breakdown**: 
  - Low-risk days show: "low flare risk"
  - Moderate/high-risk days show descriptive blurbs
  - Format: `<Weekday> — <weather pattern> — <body feel>`
  - Fixed-width weekday labels (48pt) for clean alignment
- **Sources**: Displayed at bottom after medical disclaimer
- **Template Fixing**: Automatically removes broken templates and numeric values

### 4. **Weather Data**
- **Current Weather**: Temperature, condition, feels-like, humidity, wind, pressure
- **24-Hour Forecast**: Hourly breakdown with pressure change arrows
- **7-Day Forecast**: Extended outlook
- **Location Services**: 
  - Device location with permissions
  - Manual city search with autocomplete
  - MapKit integration with error handling
  - Reverse geocoding for location names

### 5. **Symptom Tracking**
- **LogView**: Track symptoms, pain levels, and notes
- **TrendsView**: View symptom patterns over time
- **Core Data Integration**: Persistent storage
- **Weekly Summary**: Statistics and patterns

### 6. **Settings**
- **Profile Management**: View and edit user information
- **Location Settings**: Toggle between device location and manual entry
- **Diagnoses Display**: Shows selected health conditions
- **Weather Sensitivities**: Displays selected sensitivities
- **Account Deletion**: Red button with confirmation alert
- **Logout**: Clear authentication state

---

## 📱 Screens & Views

### **Main Screens**
1. **ContentView**: Root view with tab navigation
2. **HomeView**: Main dashboard with weather and AI insights
3. **LogView**: Symptom tracking interface
4. **TrendsView**: Historical data and patterns
5. **SettingsView**: User settings and preferences

### **Authentication Screens**
1. **LoginView**: Email/password login + Apple Sign In
2. **SignupView**: Account creation (legacy, replaced by onboarding)
3. **ForgotPasswordView**: Initiate password reset
4. **ResetPasswordCodeView**: Enter 6-digit code and new password

### **Onboarding Screens**
1. **OnboardingFlowView**: Container managing the flow
2. **OnboardingHeroView**: Welcome screen
3. **OnboardingValueView**: Value propositions
4. **DiagnosisSelectionView**: Health condition selection
5. **SensitivitySelectionView**: Weather sensitivity selection
6. **InsightPreviewView**: Preview of insights
7. **PaywallPlaceholderView**: Subscription prompt
8. **AccountCreationView**: Final account setup

### **Reusable Components**
- **DailyInsightCardView**: Renders daily AI insights with parsing
- **WeeklyForecastInsightCardView**: Renders weekly insights
- **WeatherCardView**: Current weather display
- **PressureAlertCardView**: Pressure change alerts

---

## 🎨 Design & Styling

### **Theme System**
- **ThemeManager**: Centralized theme management
- **Adaptive Colors**: 
  - `adaptiveText`: Adapts to light/dark mode
  - `adaptiveBackground`: Background colors
  - `adaptiveMuted`: Secondary text
  - `adaptiveCardBackground`: Card backgrounds
- **Brand Colors**: 
  - Brand Green: `#1A6B5A` (used for icons)
  - Brand Blue, Rose, Violet: Available in assets
- **Typography**: 
  - `.interTitle`, `.interHeadline`, `.interBody`, `.interCaption`, `.interSmall`
  - Consistent font weights and sizes

### **Card Styling**
- `.cardStyle()` modifier: Rounded corners, padding, background
- Consistent spacing (16pt between sections)
- Dividers with muted opacity
- Smooth transitions and animations

---

## 🔧 Technical Architecture

### **Services**
1. **AIInsightsService**: 
   - Handles AI insight generation
   - Formats daily and weekly insights
   - Validates and rewrites vague language
   - Removes template placeholders and numeric values
   - Manages insight state

2. **WeatherService**: 
   - Fetches weather data from backend
   - Handles API errors
   - Caches weather data

3. **AuthService**: 
   - API calls for authentication
   - Password reset endpoints
   - Error handling

4. **AuthManager**: 
   - Manages authentication state
   - User session handling
   - Account deletion

5. **LocationManager**: 
   - CoreLocation integration
   - Reverse geocoding
   - Manual location management

### **Data Persistence**
- **Core Data**: 
  - UserProfile model
  - SymptomEntry model
  - Persistent storage
- **UserDefaults**: 
  - User preferences
  - Weather sensitivities
  - Authentication tokens
  - Location settings

### **Backend Integration**
- **FastAPI Backend**: Python-based API
- **Endpoints**:
  - `/analyze`: AI insight generation
  - `/auth/signup`: User registration
  - `/auth/login`: User authentication
  - `/auth/forgot-password`: Password reset initiation
  - `/auth/reset-password`: Password reset completion
  - `/auth/delete-account`: Account deletion
- **Database**: PostgreSQL (production) / SQLite (local)
- **Email Service**: Mailgun integration for password resets

---

## ✨ Key Improvements & Fixes

### **AI Insights Formatting**
- ✅ Daily "Why" section uses specific body-sensation language
- ✅ Weekly summaries remove all numeric values and templates
- ✅ Low-risk days show "low flare risk" instead of generic messages
- ✅ Sources properly cited at bottom of cards
- ✅ Preview page matches live card styling exactly

### **User Experience**
- ✅ Complete onboarding flow with state preservation
- ✅ Improved login page layout (buttons grouped, sign-up after divider)
- ✅ Location search error handling (MapKit errors)
- ✅ Password reset with 6-digit codes
- ✅ Case-insensitive email lookups

### **Code Quality**
- ✅ No force unwraps in critical paths
- ✅ Proper error handling throughout
- ✅ Consistent styling and spacing
- ✅ Reusable components
- ✅ Dark mode support

---

## 🚀 Deployment Status

### **Git Repository**
- **Branch**: `main`
- **Latest Commit**: TestFlight launch improvements
- **Status**: All changes committed and pushed to GitHub

### **Backend (Railway)**
- **Auto-Deploy**: Configured to deploy from `main` branch
- **Services**: 
  - FastAPI application
  - PostgreSQL database
  - Mailgun email service
- **Environment Variables**: Configured for production

### **TestFlight Ready**
- ✅ All features implemented and tested
- ✅ No critical bugs or crashes
- ✅ Error handling in place
- ✅ User flows complete
- ✅ AI insights properly formatted
- ✅ UI/UX polished and consistent

---

## 📋 Feature Checklist

### **Authentication** ✅
- [x] Email/password signup
- [x] Email/password login
- [x] Apple Sign In
- [x] Password reset flow
- [x] Account deletion
- [x] Session management

### **Onboarding** ✅
- [x] Hero screen
- [x] Value proposition
- [x] Diagnosis selection
- [x] Sensitivity selection
- [x] Insight preview
- [x] Paywall placeholder
- [x] Account creation

### **AI Insights** ✅
- [x] Daily insight generation
- [x] Weekly forecast insight
- [x] Proper formatting (no numbers, no templates)
- [x] Body-sensation language enforcement
- [x] Source citations
- [x] Low-risk day detection

### **Weather** ✅
- [x] Current weather display
- [x] 24-hour forecast
- [x] 7-day forecast
- [x] Location services
- [x] Manual location search
- [x] Pressure change indicators

### **Tracking** ✅
- [x] Symptom logging
- [x] Pain level tracking
- [x] Notes and details
- [x] Trends visualization
- [x] Historical data

### **Settings** ✅
- [x] Profile management
- [x] Location settings
- [x] Diagnoses display
- [x] Sensitivities display
- [x] Account deletion
- [x] Logout

---

## 🔐 Security Features

- ✅ Password hashing (bcrypt)
- ✅ JWT token authentication
- ✅ Secure password reset codes (hashed, expired)
- ✅ Case-insensitive email (prevents duplicate accounts)
- ✅ No sensitive data in logs
- ✅ Environment variables for API keys

---

## 📊 Data Models

### **UserProfile** (Core Data)
- Name, email
- Diagnoses (array)
- Created/updated timestamps

### **SymptomEntry** (Core Data)
- Date, time
- Symptom type
- Pain level
- Location
- Notes

### **API Models**
- `InsightResponse`: Daily/weekly insights from backend
- `CorrelationRequest`: Weather + symptom data to backend
- `ForgotPasswordRequest/Response`: Password reset flow
- `ResetPasswordRequest/Response`: Password reset completion

---

## 🎯 Next Steps (Future Enhancements)

- [ ] RevenueCat/StoreKit integration for subscriptions
- [ ] Push notifications for weather alerts
- [ ] Thank-you email after signup
- [ ] Advanced trend analysis
- [ ] Export data functionality
- [ ] Social sharing of insights

---

## 📝 Notes

- **TestFlight Build**: Ready for distribution
- **Backend**: Auto-deploys from GitHub main branch
- **Environment**: Production-ready with proper error handling
- **Code Quality**: No linter errors, proper error handling
- **User Experience**: Polished, consistent, accessible

---

**Last Updated**: Current as of latest commit
**Status**: ✅ Ready for TestFlight Launch

