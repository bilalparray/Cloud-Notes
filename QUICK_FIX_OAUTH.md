# Quick Fix: Google Sign-In Error 400

## The Error
**"Error 400: redirect_uri_mismatch"**

Your app is running on `http://127.0.0.1:5501` but this redirect URI isn't authorized.

## ✅ Fix in 3 Steps

### 1. Go to Google Cloud Console
https://console.cloud.google.com/

### 2. Navigate to OAuth Settings
- Select project: **cloud-notes-8e62d**
- **APIs & Services** > **Credentials**
- Click your **OAuth 2.0 Client ID** (Web client)

### 3. Add These Redirect URIs

**Authorized redirect URIs:**
```
http://127.0.0.1:5501
http://localhost:5501
http://127.0.0.1:5500
http://localhost:5500
```

**Authorized JavaScript origins:**
```
http://127.0.0.1:5501
http://localhost:5501
http://127.0.0.1:5500
http://localhost:5500
```

### 4. Save & Wait
- Click **Save**
- Wait 1-2 minutes
- Refresh your app and try again

## Alternative: Use Flutter's Server

Instead of VS Code Live Server, use:

```bash
flutter run -d chrome
```

This uses a consistent port that you can add to Google Cloud Console.
