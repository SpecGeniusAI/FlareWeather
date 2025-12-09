# Access Status Integration Guide

This guide explains how the iOS app should handle access status checks and show the popup when free access expires.

## Backend Changes

### 1. `/auth/me` Endpoint (Updated)
Now returns access status information:

```json
{
  "user_id": "abc123",
  "email": "user@example.com",
  "name": "John Doe",
  "created_at": "2024-01-01T00:00:00",
  "has_access": true,
  "access_type": "free",
  "access_expires_at": "2024-12-31T23:59:59",
  "access_required": false
}
```

**Fields:**
- `has_access`: `true` if user has active subscription or free access
- `access_type`: `"subscription"` | `"free"` | `"none"`
- `access_expires_at`: ISO datetime string or `null` (if never expires)
- `access_required`: `true` if user needs to subscribe/upgrade (opposite of `has_access`)

### 2. `/user/access-status` Endpoint (New)
Explicit endpoint to check access status:

```json
{
  "user_id": "abc123",
  "email": "user@example.com",
  "has_access": false,
  "access_type": "none",
  "expires_at": null,
  "is_expired": true
}
```

### 3. `/analyze` Endpoint (Updated)
Now includes access flags in the response:

```json
{
  "correlation_summary": "...",
  "ai_message": "...",
  // ... other fields ...
  "access_required": true,
  "access_expired": true
}
```

**Fields:**
- `access_required`: `true` if user doesn't have active access
- `access_expired`: `true` if user's free access has expired (shows they had free access before)

## iOS App Implementation

### Step 1: Check Access Status on App Launch

After login, call `/auth/me` and check the access status:

```swift
// After successful login
let userResponse = try await authService.getCurrentUser()
if userResponse.access_required == true {
    // Show access popup
    showAccessExpiredPopup(expired: userResponse.access_expired ?? false)
}
```

### Step 2: Check Access Before Showing Insights

Before displaying insights, check the `access_required` flag:

```swift
// After calling /analyze endpoint
if insightResponse.access_required == true {
    // Show popup instead of insights
    showAccessExpiredPopup(expired: insightResponse.access_expired ?? false)
} else {
    // Show insights normally
    displayInsights(insightResponse)
}
```

### Step 3: Create Access Expired Popup

Create a popup view that shows when access expires:

```swift
struct AccessExpiredPopupView: View {
    let expired: Bool
    let logoutMessage: String?
    let onSubscribe: () -> Void
    let onLogout: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text(expired ? "Free Access Has Ended" : "Access Required")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(expired 
                ? "Your free access period has ended. Subscribe to continue enjoying full insights, or logout to view basic insights."
                : "Full access is required for personalized insights. Subscribe to unlock all features, or logout to view basic insights.")
                .multilineTextAlignment(.center)
                .padding()
            
            HStack(spacing: 16) {
                Button("Subscribe") {
                    onSubscribe()
                }
                .buttonStyle(.borderedProminent)
                
                VStack(spacing: 4) {
                    Button("Logout") {
                        onLogout()
                    }
                    .buttonStyle(.bordered)
                    
                    if let message = logoutMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
    }
}
```

### Step 4: Handle User Actions

**Subscribe Button:**
- Navigate to subscription/paywall screen
- Use your existing subscription flow

**Logout Button:**
- Log out the user
- Show the basic insights page (no subscription required)
- This should be a view that doesn't require access checks

### Step 5: Periodic Access Checks

Optionally, check access status periodically or when app comes to foreground:

```swift
// In your main view or app delegate
.onAppear {
    checkAccessStatus()
}

func checkAccessStatus() {
    Task {
        do {
            let status = try await apiService.getAccessStatus()
            if status.has_access == false {
                showAccessExpiredPopup(expired: status.is_expired)
            }
        } catch {
            // Handle error
        }
    }
}
```

## Flow Diagram

```
User Opens App
    ↓
Check /auth/me
    ↓
Has Access? ──No──→ Show Popup (Subscribe or Logout)
    │                    │
   Yes                   │
    ↓                    │
Show Insights        Logout → Basic Insights (No Access Required)
    ↓
User Uses App
    ↓
Call /analyze
    ↓
Check access_required flag
    ↓
If true → Show Popup
If false → Show Insights
```

## Example API Service Methods

```swift
class APIService {
    // Get current user with access status
    func getCurrentUser() async throws -> UserResponse {
        // Call GET /auth/me
    }
    
    // Get explicit access status
    func getAccessStatus() async throws -> AccessStatusResponse {
        // Call GET /user/access-status
    }
    
    // Analyze with access checking
    func analyze(request: CorrelationRequest) async throws -> InsightResponse {
        // Call POST /analyze
        // Check access_required and access_expired flags in response
    }
}
```

## Testing Scenarios

1. **User with active free access**: `has_access: true`, `access_type: "free"` → Show insights
2. **User with expired free access**: `has_access: false`, `access_expired: true` → Show popup
3. **User with subscription**: `has_access: true`, `access_type: "subscription"` → Show insights
4. **User with no access**: `has_access: false`, `access_required: true` → Show popup

## Notes

- The backend still returns insights even if access is required (for basic insights)
- The iOS app should check the flags and decide whether to show the popup
- The popup should be non-blocking but prominent
- Consider showing a subtle indicator when user is on free access that will expire
