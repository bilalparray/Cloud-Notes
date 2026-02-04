# Deep Linking Setup Guide

## How Invitation Links Work

### Current Implementation

1. **Web**: ✅ Fully working
   - User clicks link: `https://your-domain.com/join/{token}`
   - Web app detects `/join/` path in URL
   - Shows invitation acceptance screen
   - User signs in (if needed) and accepts invitation

2. **Mobile**: ✅ Now supported with deep linking
   - User clicks link: `https://your-domain.com/join/{token}` or `yourapp://join/{token}`
   - App opens (if installed) or redirects to app store
   - App detects the deep link
   - Shows invitation acceptance screen
   - User signs in (if needed) and accepts invitation

## Setup Instructions

### 1. Android Deep Linking

#### Option A: App Links (Recommended - opens app directly)

1. **Add intent filter to `android/app/src/main/AndroidManifest.xml`**:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme"
    ...>
    
    <!-- Existing intent filters -->
    
    <!-- Deep Link: Custom Scheme -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data
            android:scheme="yourapp"
            android:host="join" />
    </intent-filter>
    
    <!-- App Link: HTTPS (requires domain verification) -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data
            android:scheme="https"
            android:host="your-domain.com"
            android:pathPrefix="/join" />
    </intent-filter>
</activity>
```

2. **For App Links (HTTPS)**, create `/.well-known/assetlinks.json` on your domain:

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.yourcompany.cloud_notes",
    "sha256_cert_fingerprints": [
      "YOUR_APP_SHA256_FINGERPRINT"
    ]
  }
}]
```

To get your SHA256 fingerprint:
```bash
keytool -list -v -keystore android/app/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### 2. iOS Deep Linking

#### Option A: Universal Links (Recommended)

1. **Add to `ios/Runner/Info.plist`**:

```xml
<key>CFBundleURLTypes</key>
<array>
    <!-- Custom URL Scheme -->
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.cloudnotes</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>yourapp</string>
        </array>
    </dict>
</array>
```

2. **For Universal Links**, create `/.well-known/apple-app-site-association` on your domain:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAM_ID.com.yourcompany.cloudnotes",
        "paths": ["/join/*"]
      }
    ]
  }
}
```

3. **Enable Associated Domains in Xcode**:
   - Open `ios/Runner.xcworkspace` in Xcode
   - Select Runner target → Signing & Capabilities
   - Add "Associated Domains"
   - Add: `applinks:your-domain.com`

### 3. Update Invitation Link Generation

For mobile apps, you can use either:

**Option 1: HTTPS links** (works for both web and mobile if App Links/Universal Links configured)
```
https://your-domain.com/join/{token}
```

**Option 2: Custom scheme** (works for mobile only)
```
yourapp://join/{token}
```

Update `lib/services/invitation_service.dart` if you want to use custom scheme:

```dart
String generateInvitationLink(String token, {String? baseUrl, bool useCustomScheme = false}) {
  if (useCustomScheme && !kIsWeb) {
    return 'yourapp://join/$token';
  }
  
  // ... rest of existing code
}
```

## Testing Deep Links

### Android

**Custom Scheme:**
```bash
adb shell am start -W -a android.intent.action.VIEW -d "yourapp://join/testtoken123" com.yourcompany.cloud_notes
```

**HTTPS (App Link):**
```bash
adb shell am start -W -a android.intent.action.VIEW -d "https://your-domain.com/join/testtoken123" com.yourcompany.cloud_notes
```

### iOS

**Custom Scheme:**
```bash
xcrun simctl openurl booted "yourapp://join/testtoken123"
```

**HTTPS (Universal Link):**
- Send the link via Messages/Email
- Click it in Safari (Universal Links don't work in simulator)

## How It Works

1. **User receives invitation link** (via email, SMS, etc.)
2. **User clicks link**:
   - **If app installed**: App opens directly to invitation screen
   - **If app not installed**: Opens in browser (web version) or app store
3. **App detects deep link** via `app_links` package
4. **Shows InvitationAcceptanceScreen** with token
5. **User signs in** (if not already signed in)
6. **User accepts invitation** → Added to workspace
7. **Redirected to workspace notes**

## Security Notes

- ✅ Token is validated server-side (Firestore security rules)
- ✅ Token expires after 7 days
- ✅ Token can only be used once
- ✅ User must authenticate before accepting
- ✅ Workspace access is validated

## Troubleshooting

**Link doesn't open app:**
- Check AndroidManifest.xml / Info.plist configuration
- Verify intent filters are correct
- For App Links: Verify assetlinks.json is accessible
- For Universal Links: Verify apple-app-site-association is accessible

**App opens but doesn't show invitation:**
- Check that token is being extracted correctly
- Verify deep link path matches `/join/{token}`
- Check console logs for errors

**Works on web but not mobile:**
- Ensure `app_links` package is added to pubspec.yaml
- Run `flutter pub get`
- Rebuild the app (not just hot reload)
