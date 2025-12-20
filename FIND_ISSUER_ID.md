# How to Find Your Issuer ID

## Step-by-Step Instructions

### 1. Go to App Store Connect
- Visit: https://appstoreconnect.apple.com
- Sign in with your Apple Developer account

### 2. Navigate to Keys Section
- Click on **Users and Access** in the top navigation
- Click on the **Keys** tab (next to "Users" and "Access")

### 3. Find the Issuer ID
The **Issuer ID** is displayed at the **top of the Keys page**, above the list of API keys.

It looks like this:
```
Issuer ID: 12345678-1234-1234-1234-123456789012
```

**Important:** 
- The Issuer ID is the same for all API keys in your account
- It's a UUID (long string with dashes)
- It's shown at the top of the page, not on individual key pages

### 4. Copy It
- Just copy the entire Issuer ID string
- It will look something like: `12345678-1234-1234-1234-123456789012`

## Visual Guide

```
App Store Connect
├── Users and Access
    ├── Users tab
    ├── Access tab
    └── Keys tab  ← Click here
        │
        ├── Issuer ID: 12345678-1234-1234-1234-123456789012  ← This is at the TOP
        │
        └── [List of API Keys below]
```

## If You Can't Find It

If you don't see the Keys tab or Issuer ID:
1. Make sure you have **Admin** or **Account Holder** access
2. If you're part of an organization, ask your admin for the Issuer ID
3. The Issuer ID is account-wide, so anyone with access can see it

## What You Need

You need **two different things** from the Keys page:

1. **Issuer ID** (at the top of the page) - This is what you're looking for now
2. **Key ID** (on each individual API key) - You'll get this when you create a new key

Both are needed for the Apple API to work!
