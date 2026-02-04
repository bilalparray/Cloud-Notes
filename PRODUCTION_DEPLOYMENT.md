# Production Deployment Guide

Complete guide for deploying Cloud Notes (TeamDocs) to Google Play Store and Web.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Firebase Production Setup](#firebase-production-setup)
3. [Configuration Updates](#configuration-updates)
4. [Android / Play Store Deployment](#android--play-store-deployment)
5. [Web Deployment](#web-deployment)
6. [Post-Deployment Checklist](#post-deployment-checklist)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Accounts
- ✅ Google Play Console account ($25 one-time fee)
- ✅ Firebase project (free tier available)
- ✅ Domain name (for web deployment, optional but recommended)

### Required Tools
- ✅ Flutter SDK (latest stable version)
- ✅ Android Studio
- ✅ Firebase CLI (`npm install -g firebase-tools`)
- ✅ Git

---

## Firebase Production Setup

### 1. Create/Configure Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select existing project
3. Enable the following services:
   - **Authentication** → Enable Google Sign-In
   - **Firestore Database** → Create database in production mode
   - **Hosting** (for web deployment)

### 2. Configure Authentication

1. Go to **Authentication** → **Sign-in method**
2. Enable **Google** sign-in provider
3. Add your domains to **Authorized domains**:
   - Your production domain (e.g., `yourdomain.com`)
   - Firebase domain (automatically added)

### 3. Configure Firestore

1. Go to **Firestore Database**
2. Create database (choose production mode)
3. Copy the security rules from `FIRESTORE_SECURITY_RULES.txt`
4. Paste and publish in **Firestore** → **Rules**

### 4. Get Configuration Files

#### For Android:
1. Go to **Project Settings** → **Your apps** → **Android app**
2. Download `google-services.json`
3. Place it in `android/app/google-services.json`

#### For Web:
1. Go to **Project Settings** → **Your apps** → **Web app**
2. Copy the Firebase config object
3. Update `lib/config/firebase_config.dart` with the values

---

## Configuration Updates

### 1. Update `lib/config/firebase_config.dart`

```dart
class FirebaseConfig {
  // ... existing Firebase config ...
  
  // Update these for production:
  static const String appBaseUrl = 'https://your-production-domain.com';
  static const String productionDomain = 'https://your-production-domain.com';
}
```

### 2. Update Android Configuration

#### Update `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        applicationId "com.yourcompany.cloudnotes" // Change to your package name
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1 // Increment for each release
        versionName "1.0.0" // Update for each release
    }
    
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

#### Create `android/key.properties` (DO NOT commit to Git):

```properties
storePassword=your-keystore-password
keyPassword=your-key-password
keyAlias=your-key-alias
storeFile=../keystore.jks
```

#### Create Release Keystore:

```bash
keytool -genkey -v -keystore android/keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias your-key-alias
```

**Important:** 
- Store `keystore.jks` and `key.properties` securely
- Add `keystore.jks` and `key.properties` to `.gitignore`
- Keep backups of your keystore (you cannot recover it if lost!)

### 3. Update App Information

#### Update `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="Cloud Notes" <!-- Your app name -->
        android:icon="@mipmap/ic_launcher">
        
        <!-- Deep linking for invitations -->
        <intent-filter android:autoVerify="true">
            <action android:name="android.intent.action.VIEW" />
            <category android:name="android.intent.category.DEFAULT" />
            <category android:name="android.intent.category.BROWSABLE" />
            <data
                android:scheme="https"
                android:host="your-production-domain.com"
                android:pathPrefix="/join" />
        </intent-filter>
    </application>
</manifest>
```

---

## Android / Play Store Deployment

### Step 1: Build Release APK/AAB

#### Option A: Build APK (for testing)
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

#### Option B: Build App Bundle (recommended for Play Store)
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

### Step 2: Test Release Build

1. Install the release APK on a test device:
   ```bash
   flutter install --release
   ```
2. Test all features:
   - ✅ Sign in with Google
   - ✅ Create workspace
   - ✅ Create notes
   - ✅ Invite members
   - ✅ Accept invitations
   - ✅ Manage members

### Step 3: Prepare Play Store Assets

#### Required Assets:
1. **App Icon**: 512x512px PNG (no transparency)
2. **Feature Graphic**: 1024x500px PNG
3. **Screenshots**: 
   - Phone: At least 2 (up to 8), min 320px, max 3840px
   - Tablet (optional): Same requirements
4. **App Description**: Up to 4000 characters
5. **Short Description**: Up to 80 characters

### Step 4: Create Play Store Listing

1. Go to [Google Play Console](https://play.google.com/console)
2. Create new app or select existing
3. Fill in:
   - **App name**: Cloud Notes (or your name)
   - **Default language**: English
   - **App or game**: App
   - **Free or paid**: Free
   - **Declarations**: Complete all required sections

### Step 5: Upload Release

1. Go to **Production** → **Create new release**
2. Upload `app-release.aab` file
3. Add **Release notes** (what's new in this version)
4. Review and roll out to production

### Step 6: Complete Store Listing

1. **Store listing** tab:
   - Add app description
   - Upload screenshots
   - Add feature graphic
   - Set app category

2. **Content rating**:
   - Complete questionnaire
   - Get rating certificate

3. **Pricing & distribution**:
   - Set as free
   - Select countries
   - Accept agreements

### Step 7: Submit for Review

1. Review all sections (green checkmarks)
2. Click **Submit for review**
3. Wait for approval (usually 1-3 days)

---

## Web Deployment

### Step 1: Build Web App

```bash
flutter build web --release
```

Output: `build/web/` directory

### Step 2: Configure Firebase Hosting

#### Initialize Firebase Hosting:

```bash
cd your-project-directory
firebase login
firebase init hosting
```

When prompted:
- Select your Firebase project
- Public directory: `build/web`
- Single-page app: **Yes**
- Set up automatic builds: **No** (or Yes if using CI/CD)

#### Update `firebase.json` (if needed):

```json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.@(js|css|woff|woff2|ttf|otf)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=31536000"
          }
        ]
      }
    ]
  }
}
```

### Step 3: Update Web Configuration

#### Update `web/index.html` (if needed):

Ensure Firebase config is properly loaded. The app should use `lib/config/firebase_config.dart`.

#### Update `lib/config/firebase_config.dart`:

```dart
static const String appBaseUrl = 'https://your-production-domain.com';
static const String productionDomain = 'https://your-production-domain.com';
```

### Step 4: Deploy to Firebase Hosting

```bash
# Build first
flutter build web --release

# Deploy
firebase deploy --only hosting
```

Your app will be available at: `https://your-project-id.web.app` or your custom domain.

### Step 5: Set Up Custom Domain (Optional)

1. Go to **Firebase Console** → **Hosting**
2. Click **Add custom domain**
3. Enter your domain name
4. Follow DNS configuration instructions
5. Wait for SSL certificate (automatic, usually < 24 hours)

### Step 6: Configure OAuth Redirect URIs

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to **APIs & Services** → **Credentials**
4. Edit your **OAuth 2.0 Client ID** (Web client)
5. Add to **Authorized redirect URIs**:
   - `https://your-domain.com/__/auth/handler`
   - `https://your-project-id.web.app/__/auth/handler`
6. Add to **Authorized JavaScript origins**:
   - `https://your-domain.com`
   - `https://your-project-id.web.app`

---

## Post-Deployment Checklist

### Android (Play Store)
- [ ] App is live on Play Store
- [ ] Deep linking works (test invitation links)
- [ ] Google Sign-In works
- [ ] All features tested on production build
- [ ] App version updated for next release
- [ ] Release notes prepared

### Web
- [ ] App deployed to Firebase Hosting
- [ ] Custom domain configured (if applicable)
- [ ] SSL certificate active
- [ ] OAuth redirect URIs configured
- [ ] Invitation links work correctly
- [ ] All features tested on production
- [ ] `appBaseUrl` in config matches production domain

### Both Platforms
- [ ] Firestore security rules deployed
- [ ] Firebase config updated in code
- [ ] Error monitoring set up (optional: Firebase Crashlytics)
- [ ] Analytics configured (optional: Firebase Analytics)
- [ ] Backup strategy for keystore (Android)

---

## Troubleshooting

### Android Issues

#### Build Fails with "Signing Config" Error
- Ensure `key.properties` exists and is correct
- Verify keystore file path is correct
- Check keystore passwords match

#### App Crashes on Release Build
- Check ProGuard rules (if minifyEnabled is true)
- Test with `flutter run --release` first
- Check logs: `adb logcat`

#### Google Sign-In Not Working
- Verify `google-services.json` is in `android/app/`
- Check SHA-1 fingerprint is added to Firebase Console
- Get SHA-1: `keytool -list -v -keystore android/keystore.jks`

### Web Issues

#### White Screen After Deployment
- Check browser console for errors
- Verify Firebase config is correct
- Ensure `index.html` loads Firebase scripts
- Check that `main.dart.js` is being served

#### OAuth Redirect Error
- Verify redirect URIs in Google Cloud Console
- Check that domain matches exactly
- Ensure HTTPS is enabled

#### Invitation Links Not Working
- Verify `appBaseUrl` in config matches deployment URL
- Check deep linking configuration
- Test invitation link in incognito mode

### General Issues

#### Firestore Permission Denied
- Verify security rules are deployed
- Check that rules match your data structure
- Test rules in Firebase Console → Rules → Rules Playground

#### Invitations Not Working
- Verify invitation tokens are being created
- Check Firestore `invitations` collection
- Ensure security rules allow invitation reads

---

## Version Management

### Android Versioning

Update in `android/app/build.gradle`:
```gradle
versionCode 2  // Increment for each release
versionName "1.0.1"  // Semantic versioning
```

### Web Versioning

Web doesn't require version numbers, but you can track in:
- `pubspec.yaml`: `version: 1.0.0+1`
- Firebase Hosting shows deployment history

---

## Security Best Practices

1. **Never commit**:
   - `keystore.jks`
   - `key.properties`
   - API keys (use environment variables in CI/CD)

2. **Firestore Security Rules**:
   - Always test rules before deploying
   - Use Rules Playground to test scenarios
   - Review rules regularly

3. **OAuth Configuration**:
   - Only add production domains to authorized URIs
   - Remove test/localhost URIs in production

4. **App Signing**:
   - Use Google Play App Signing (recommended)
   - Keep keystore backups in secure location

---

## Continuous Deployment (Optional)

### GitHub Actions Example

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy

on:
  push:
    branches: [ main ]

jobs:
  deploy-web:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v1
      - run: flutter build web --release
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
```

---

## Support & Resources

- **Flutter Documentation**: https://flutter.dev/docs
- **Firebase Documentation**: https://firebase.google.com/docs
- **Play Store Help**: https://support.google.com/googleplay/android-developer
- **Firebase Hosting**: https://firebase.google.com/docs/hosting

---

## Quick Reference Commands

```bash
# Android Release Build
flutter build appbundle --release

# Web Release Build
flutter build web --release

# Deploy Web
firebase deploy --only hosting

# Get Android SHA-1
keytool -list -v -keystore android/keystore.jks

# Test Release APK
flutter install --release
```

---

**Last Updated**: 2024
**Version**: 1.0.0
