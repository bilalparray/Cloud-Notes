# Google Play Store Deployment Guide

Complete step-by-step guide to deploy Cloud Notes to the Google Play Store.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Setup Release Signing](#setup-release-signing)
3. [Configure Android App](#configure-android-app)
4. [Build Release App Bundle](#build-release-app-bundle)
5. [Test Release Build](#test-release-build)
6. [Prepare Play Store Assets](#prepare-play-store-assets)
7. [Create Play Store Listing](#create-play-store-listing)
8. [Upload and Publish](#upload-and-publish)
9. [Post-Publication](#post-publication)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Accounts
- ✅ **Google Play Console Account** ($25 one-time registration fee)
  - Sign up at: https://play.google.com/console
- ✅ **Firebase Project** (free tier available)
- ✅ **Google Cloud Project** (linked to Firebase)

### Required Tools
- ✅ Flutter SDK (latest stable version)
- ✅ Android Studio
- ✅ Java JDK (for keytool)
- ✅ Git (for version control)

### Required Information
- ✅ App name: **Cloud Notes**
- ✅ Package name: **com.qayham.cloudnotes**
- ✅ Company/Developer name: **QAYHAM**

---

## Step 1: Setup Release Signing

### 1.1 Create Release Keystore

**Important:** Keep your keystore file and passwords secure! You cannot recover them if lost.

Open terminal/command prompt and run:

```bash
keytool -genkey -v -keystore android/keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias cloudnotes
```

You'll be prompted for:
- **Keystore password**: (create a strong password, save it securely)
- **Key password**: (can be same as keystore password)
- **Your name**: QAYHAM (or your company name)
- **Organizational Unit**: (optional)
- **Organization**: QAYHAM
- **City**: (your city)
- **State**: (your state/province)
- **Country code**: (e.g., US, GB, etc.)

**Example:**
```bash
keytool -genkey -v -keystore android/keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias cloudnotes
Enter keystore password: [your-keystore-password]
Re-enter new password: [your-keystore-password]
What is your first and last name?
  [Unknown]:  QAYHAM
What is the name of your organizational unit?
  [Unknown]:  Development
What is the name of your organization?
  [Unknown]:  QAYHAM
What is the name of your City or Locality?
  [Unknown]:  [Your City]
What is the name of your State or Province?
  [Unknown]:  [Your State]
What is the two-letter country code for this unit?
  [Unknown]:  US
Is CN=QAYHAM, OU=Development, O=QAYHAM, L=[City], ST=[State], C=US correct?
  [no]:  yes

Generating 2,048 bit RSA key pair and self-signed certificate (SHA256withRSA) with a validity of 10,000 days
        for: CN=QAYHAM, OU=Development, O=QAYHAM, L=[City], ST=[State], C=US
[Storing android/keystore.jks]
```

### 1.2 Create key.properties File

Create a file `android/key.properties` with the following content:

```properties
storePassword=your-keystore-password
keyPassword=your-key-password
keyAlias=cloudnotes
storeFile=keystore.jks
```

**Replace:**
- `your-keystore-password` with your actual keystore password
- `your-key-password` with your actual key password (can be same as keystore password)

### 1.3 Add to .gitignore

Ensure these files are NOT committed to Git:

```bash
# Add to .gitignore
android/keystore.jks
android/key.properties
```

---

## Step 2: Configure Android App

### 2.1 Update build.gradle

Update `android/app/build.gradle` to use release signing:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing configuration ...

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

### 2.2 Update Version Information

Update version in `pubspec.yaml`:

```yaml
version: 1.0.0+1
```

- **1.0.0** = version name (shown to users)
- **+1** = version code (increment for each release)

For each new release:
- Increment version code: `1.0.0+2`, `1.0.0+3`, etc.
- Update version name: `1.0.1`, `1.1.0`, `2.0.0`, etc.

### 2.3 Verify AndroidManifest.xml

Check `android/app/src/main/AndroidManifest.xml` has deep linking configured:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme">
    
    <!-- Deep linking for invitation links -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data
            android:scheme="https"
            android:host="qayham.com"
            android:pathPrefix="/join" />
    </intent-filter>
</activity>
```

---

## Step 3: Configure Firebase for Android

### 3.1 Get SHA-1 Fingerprint

Get your app's SHA-1 fingerprint for Firebase:

```bash
keytool -list -v -keystore android/keystore.jks -alias cloudnotes
```

Copy the **SHA-1** fingerprint (looks like: `AA:BB:CC:DD:EE:...`)

### 3.2 Add SHA-1 to Firebase

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Project Settings** → **Your apps** → **Android app**
4. Click **Add fingerprint**
5. Paste your SHA-1 fingerprint
6. Download the updated `google-services.json`
7. Replace `android/app/google-services.json` with the new file

### 3.3 Verify Firebase Configuration

Ensure `android/app/google-services.json` exists and contains your project configuration.

---

## Step 4: Build Release App Bundle

### 4.1 Clean Previous Builds

```bash
flutter clean
flutter pub get
```

### 4.2 Build App Bundle (AAB)

**Recommended for Play Store:**

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### 4.3 Build APK (Optional - for Testing)

For testing on devices:

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

---

## Step 5: Test Release Build

### 5.1 Install on Test Device

```bash
# Install release APK
flutter install --release

# Or manually install
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 5.2 Test Checklist

Test all features thoroughly:

- ✅ **Google Sign-In**: Sign in with Google account
- ✅ **Create Workspace**: Create a new workspace
- ✅ **Create Notes**: Create, edit, and delete notes
- ✅ **Invite Members**: Create invitation link
- ✅ **Accept Invitations**: Test invitation link opens app
- ✅ **Manage Members**: Add/remove members, change roles
- ✅ **Deep Linking**: Test invitation links from browser
- ✅ **Offline Mode**: Test app behavior without internet
- ✅ **Performance**: Check app speed and responsiveness
- ✅ **UI/UX**: Verify all screens display correctly

### 5.3 Test Deep Linking

Test invitation links work:

1. Create an invitation in the app
2. Copy the invitation link
3. Open link in browser (should open app)
4. Verify invitation acceptance works

---

## Step 6: Prepare Play Store Assets

### 6.1 Required Assets

Prepare these assets before creating your listing:

#### App Icon
- **Size**: 512x512px
- **Format**: PNG (no transparency)
- **Content**: Your app icon

#### Feature Graphic
- **Size**: 1024x500px
- **Format**: PNG or JPG
- **Content**: Promotional banner for your app

#### Screenshots
- **Phone**: At least 2, up to 8 screenshots
- **Size**: Min 320px, max 3840px (width or height)
- **Format**: PNG or JPG
- **Recommended**: 1080x1920px (portrait) or 1920x1080px (landscape)

#### Tablet Screenshots (Optional)
- Same requirements as phone screenshots

### 6.2 App Description

**Short Description** (80 characters max):
```
Cloud Notes - Sync your notes across all devices with Google authentication
```

**Full Description** (4000 characters max):
```
Cloud Notes is a powerful note-taking app that syncs seamlessly across all your devices. Built with Flutter and powered by Firebase, Cloud Notes offers a modern, intuitive interface for creating and managing your notes.

Key Features:
• Google Sign-In: Secure authentication with your Google account
• Real-time Sync: Your notes sync instantly across all devices
• Workspace Collaboration: Create workspaces and invite team members
• Rich Text Notes: Create detailed notes with formatting
• Offline Support: Access your notes even without internet
• Deep Linking: Share invitation links that open directly in the app
• Material Design: Beautiful, modern UI following Material Design principles

Perfect for:
• Personal note-taking
• Team collaboration
• Project documentation
• Meeting notes
• Task management

Your data is securely stored in Firebase and synced in real-time. Start organizing your thoughts and collaborate with your team today!

Privacy & Security:
• All data encrypted in transit
• Secure Firebase backend
• Google authentication
• No ads, no tracking
```

### 6.3 Privacy Policy

Create a privacy policy and host it online (e.g., on your website).

**Required sections:**
- What data you collect
- How you use the data
- Data storage and security
- Third-party services (Firebase, Google)
- User rights

**Example Privacy Policy URL:**
```
https://qayham.com/privacy-policy
```

---

## Step 7: Create Play Store Listing

### 7.1 Create App in Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Click **Create app**
3. Fill in:
   - **App name**: Cloud Notes
   - **Default language**: English (United States)
   - **App or game**: App
   - **Free or paid**: Free
   - **Declarations**: Check all that apply
4. Click **Create app**

### 7.2 Complete Store Listing

Go to **Store presence** → **Main store listing**:

1. **App name**: Cloud Notes
2. **Short description**: (80 characters max)
3. **Full description**: (4000 characters max)
4. **App icon**: Upload 512x512px icon
5. **Feature graphic**: Upload 1024x500px graphic
6. **Screenshots**: Upload at least 2 phone screenshots
7. **Category**: Productivity (or appropriate category)
8. **Contact details**: Your email
9. **Privacy Policy**: URL to your privacy policy

### 7.3 Complete App Content

Go to **Policy** → **App content**:

1. **Privacy Policy**: Add URL
2. **Data Safety**: Complete questionnaire
3. **Target audience**: Select appropriate age group
4. **Content ratings**: Complete questionnaire

### 7.4 Complete App Access

Go to **App content** → **App access**:

1. **All or some functionality is restricted**: Select if applicable
2. **Declarations**: Complete all required sections

---

## Step 8: Upload and Publish

### 8.1 Create Production Release

1. Go to **Production** → **Releases**
2. Click **Create new release**
3. Upload `app-release.aab` file
4. **Release name**: `1.0.0` (or your version)
5. **Release notes**: 
   ```
   Initial release of Cloud Notes
   - Google Sign-In authentication
   - Real-time note syncing
   - Workspace collaboration
   - Deep linking support
   ```
6. Click **Save**

### 8.2 Review Release

1. Review all sections:
   - ✅ Store listing complete
   - ✅ App content complete
   - ✅ Privacy policy added
   - ✅ Content rating complete
   - ✅ Release uploaded
   - ✅ All required sections have green checkmarks

### 8.3 Submit for Review

1. Click **Review release**
2. Review all information
3. Click **Start rollout to Production**
4. Wait for review (usually 1-3 days)

---

## Step 9: Post-Publication

### 9.1 Monitor Reviews

- Check Play Console for user reviews
- Respond to user feedback
- Monitor crash reports

### 9.2 Update App

For future updates:

1. **Update version** in `pubspec.yaml`:
   ```yaml
   version: 1.0.1+2  # Increment both
   ```

2. **Rebuild app bundle**:
   ```bash
   flutter build appbundle --release
   ```

3. **Upload new release** in Play Console

4. **Add release notes**:
   ```
   Version 1.0.1
   - Bug fixes
   - Performance improvements
   - New features
   ```

### 9.3 Promote Your App

- Share on social media
- Add to your website
- Create promotional materials
- Encourage user reviews

---

## Step 10: Troubleshooting

### Issue: Build Fails with Signing Error

**Solution:**
- Verify `key.properties` file exists and is correct
- Check keystore file path is correct
- Verify passwords match
- Ensure keystore file is in `android/` directory

### Issue: Google Sign-In Not Working

**Solution:**
- Verify SHA-1 fingerprint is added to Firebase
- Check `google-services.json` is up to date
- Verify OAuth client ID is configured in Firebase
- Test with release build (not debug)

### Issue: Deep Links Not Working

**Solution:**
- Verify AndroidManifest.xml has intent-filter
- Check `android:autoVerify="true"` is set
- Verify domain is verified in Play Console
- Test with release build

### Issue: App Rejected by Play Store

**Common reasons:**
- Missing privacy policy
- Incomplete content rating
- Policy violations
- Technical issues

**Solution:**
- Check Play Console for specific rejection reason
- Address all issues mentioned
- Resubmit after fixing

### Issue: Version Code Already Used

**Solution:**
- Increment version code in `pubspec.yaml`
- Rebuild app bundle
- Upload new version

---

## Quick Reference Commands

```bash
# Create keystore
keytool -genkey -v -keystore android/keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias cloudnotes

# Get SHA-1 fingerprint
keytool -list -v -keystore android/keystore.jks -alias cloudnotes

# Build app bundle
flutter clean
flutter pub get
flutter build appbundle --release

# Build APK (for testing)
flutter build apk --release

# Install on device
flutter install --release
# or
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Important Notes

1. **Keystore Security**: 
   - Never commit keystore to Git
   - Keep backups in secure location
   - You cannot recover lost keystore

2. **Version Management**:
   - Always increment version code for each release
   - Version code must be unique and increasing
   - Version name can be any string

3. **Review Process**:
   - First submission: 1-3 days
   - Updates: Usually faster (hours to 1 day)
   - Monitor Play Console for status

4. **Testing**:
   - Always test release builds before submitting
   - Test on multiple devices if possible
   - Test all features thoroughly

---

## Support Resources

- **Play Console Help**: https://support.google.com/googleplay/android-developer
- **Flutter Documentation**: https://flutter.dev/docs
- **Firebase Documentation**: https://firebase.google.com/docs
- **Android Developer Guide**: https://developer.android.com/distribute/googleplay

---

**Last Updated**: 2025
**App Package**: com.qayham.cloudnotes
**App Name**: Cloud Notes
