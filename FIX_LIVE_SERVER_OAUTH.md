# Fix OAuth Error for Live Server (127.0.0.1:5501)

## The Problem
Live Server gives you URLs like `http://127.0.0.1:5501`, but Google OAuth doesn't recognize this redirect URI.

## ✅ Solution: Add Redirect URI to Google Cloud Console

### Step-by-Step Instructions:

1. **Go to Google Cloud Console**
   - Open: https://console.cloud.google.com/
   - Make sure you're logged in with the same Google account

2. **Select Your Project**
   - Click the project dropdown at the top
   - Select: **cloud-notes-8e62d**

3. **Navigate to Credentials**
   - In the left menu: **APIs & Services** > **Credentials**
   - Find your **OAuth 2.0 Client ID** (it should say "Web client" or have your Web Client ID)
   - Click on it to edit

4. **Add Authorized Redirect URIs**
   - Scroll to **Authorized redirect URIs**
   - Click **+ ADD URI**
   - Add these one by one:
     ```
     http://127.0.0.1:5500
     http://127.0.0.1:5501
     http://127.0.0.1:5502
     http://localhost:5500
     http://localhost:5501
     http://localhost:5502
     ```
   - (Live Server can use different ports, so add a few)

5. **Add Authorized JavaScript Origins**
   - Scroll to **Authorized JavaScript origins**
   - Click **+ ADD URI**
   - Add these:
     ```
     http://127.0.0.1:5500
     http://127.0.0.1:5501
     http://127.0.0.1:5502
     http://localhost:5500
     http://localhost:5501
     http://localhost:5502
     ```

6. **Save**
   - Click **SAVE** at the bottom
   - Wait 1-2 minutes for changes to propagate

7. **Test**
   - Refresh your app in the browser
   - Try signing in again

## Alternative: Use Flutter's Built-in Server

If you want to avoid this configuration, use Flutter's server instead:

```bash
flutter run -d chrome
```

This uses a fixed port that you can configure once in Google Cloud Console.

## Quick Visual Guide

**What you're looking for in Google Cloud Console:**

```
OAuth 2.0 Client IDs
└── [Your Web Client ID]
    ├── Authorized JavaScript origins
    │   └── Add: http://127.0.0.1:5501
    └── Authorized redirect URIs
        └── Add: http://127.0.0.1:5501
```

## Still Not Working?

1. **Clear browser cache** - Sometimes old OAuth tokens cause issues
2. **Try incognito mode** - To rule out browser extensions
3. **Check the exact port** - Look at your browser's address bar for the exact URL
4. **Wait longer** - Google's changes can take up to 5 minutes to propagate
