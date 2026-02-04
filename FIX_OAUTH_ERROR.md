# Fix: Google Sign-In Error 400: redirect_uri_mismatch

## The Problem
You're seeing: **"Error 400: redirect_uri_mismatch"**

This means the redirect URI your app is using (`http://127.0.0.1:5501`) is not authorized in Google Cloud Console.

## ✅ Solution: Add Redirect URIs

### Step 1: Go to Google Cloud Console

1. Open: https://console.cloud.google.com/
2. Select your project: **cloud-notes-8e62d**
3. Go to: **APIs & Services** > **Credentials**
4. Find your **OAuth 2.0 Client ID** (the one with "Web client" type)
5. Click on it to edit

### Step 2: Add Authorized Redirect URIs

In the **Authorized redirect URIs** section, add these:

```
http://localhost:5500
http://localhost:5501
http://localhost:5502
http://localhost:5503
http://localhost:5504
http://localhost:5505
http://127.0.0.1:5500
http://127.0.0.1:5501
http://127.0.0.1:5502
http://127.0.0.1:5503
http://127.0.0.1:5504
http://127.0.0.1:5505
http://localhost:*
http://127.0.0.1:*
```

**OR** add a wildcard pattern (if supported):
```
http://localhost:*
http://127.0.0.1:*
```

### Step 3: Add Authorized JavaScript Origins

Also add these to **Authorized JavaScript origins**:

```
http://localhost:5500
http://localhost:5501
http://127.0.0.1:5500
http://127.0.0.1:5501
http://localhost
http://127.0.0.1
```

### Step 4: Save and Wait

1. Click **Save**
2. Wait 1-2 minutes for changes to propagate
3. Try signing in again

## Alternative: Use a Fixed Port

If wildcards don't work, you can use a fixed port:

1. **Stop your current server**
2. **Use Flutter's built-in server** (uses a fixed port):
   ```bash
   flutter run -d chrome
   ```
3. **Add that specific port** to Google Cloud Console

## For Production Deployment

When you deploy, also add:
- `https://cloud-notes-8e62d.web.app`
- `https://cloud-notes-8e62d.firebaseapp.com`
- Your custom domain (if you have one)

## Quick Checklist

- [ ] Opened Google Cloud Console
- [ ] Selected project: cloud-notes-8e62d
- [ ] Found OAuth 2.0 Client ID (Web client)
- [ ] Added redirect URIs for localhost ports
- [ ] Added JavaScript origins
- [ ] Saved changes
- [ ] Waited 1-2 minutes
- [ ] Tried signing in again
