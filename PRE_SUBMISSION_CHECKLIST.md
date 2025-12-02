# Pre-Submission Checklist for App Store

## ✅ Critical Items

### 1. StoreKit Subscriptions
- [ ] Products configured in App Store Connect:
  - `fw_plus_monthly` - $2.99/month with 7-day free trial
  - `fw_plus_yearly` - $19.99/year
- [ ] Subscription group: "FlareWeather Subscription"
- [ ] Products are in "Ready to Submit" or approved status
- [ ] Products are linked to app version
- [ ] Subscription metadata complete (localizations, descriptions)
- [ ] Tested in sandbox with sandbox tester account
- [ ] Tested in TestFlight - subscriptions work correctly

### 2. Authentication & User Data
- [ ] Sign up flow works
- [ ] Log in works (email/password)
- [ ] Apple Sign In works
- [ ] Forgot password flow works (tested email delivery)
- [ ] Password reset works end-to-end
- [ ] User data persists correctly (diagnoses, sensitivities, profile)

### 3. Core Features
- [ ] Weather data loads correctly
- [ ] Daily AI insight generates and displays correctly
- [ ] Weekly forecast insight generates and displays correctly
- [ ] Location services work (device location + manual city selection)
- [ ] Symptom logging works (if implemented)

### 4. UI/UX
- [ ] Dark mode works correctly (all screens)
- [ ] Text is readable in both light and dark modes
- [ ] All buttons are accessible and have proper contrast
- [ ] Navigation flows work smoothly
- [ ] No broken layouts or overlapping elements
- [ ] Loading states show correctly
- [ ] Error messages are user-friendly

### 5. Legal & Compliance
- [ ] Privacy Policy URL is live: https://www.flareweather.app/privacy-policy
- [ ] Terms of Service URL is live: https://www.flareweather.app/terms-of-service
- [ ] Medical disclaimer present on insights: "Flare isn't a substitute for medical professionals"
- [ ] App Store Privacy details completed in App Store Connect

### 6. Backend & Infrastructure
- [ ] Railway backend is deployed and stable
- [ ] Environment variables set in Railway:
  - MAILGUN_API_KEY
  - MAILGUN_DOMAIN
  - MAILGUN_FROM_EMAIL
  - DATABASE_URL
  - JWT_SECRET
  - OPENAI_API_KEY
- [ ] Mailgun domain `flareweather.app` is verified
- [ ] Test endpoint `/test-email` is secured or removed (currently has basic protection)

### 7. App Store Connect Setup
- [ ] App Store listing complete:
  - App name, subtitle, description
  - Keywords
  - Screenshots for required device sizes
  - App icon
  - Privacy policy URL
  - Support URL
- [ ] Age rating completed
- [ ] App Review Information:
  - Contact info
  - Demo account credentials (if needed)
  - Notes for reviewers
- [ ] Pricing and Availability set
- [ ] Version number ready (1.0.0 or similar)

### 8. Testing
- [ ] Tested on physical device (not just simulator)
- [ ] Tested in TestFlight with external testers
- [ ] All subscription flows tested
- [ ] Password reset email received and tested
- [ ] App works with poor/no internet connection (graceful errors)
- [ ] App handles location permission denials gracefully

### 9. Code Quality
- [ ] No compiler warnings
- [ ] No crash logs or errors
- [ ] Debug logging is appropriate (not exposing sensitive data)
- [ ] Error handling is robust
- [ ] Memory leaks checked

### 10. Known Issues to Monitor
- [ ] Monitor Railway logs for any errors after TestFlight release
- [ ] Watch for any Mailgun delivery issues
- [ ] Monitor subscription activation rates
- [ ] Check for any user-reported issues in TestFlight

## 🚨 Before Final Submission

1. Remove or properly secure test endpoints (`/test-email`)
2. Verify all URLs work (Privacy Policy, Terms of Service)
3. Double-check subscription products are ready
4. Review App Store Connect metadata for typos
5. Test the app one more time end-to-end
6. Verify all screenshots match current app version

## Notes

- Test endpoint `/test-email` has basic protection but should be removed before final production
- Apple Sign In identity token verification has TODO comment (acceptable for initial submission)
- Email retry/backoff logic has TODO (not critical for launch)
