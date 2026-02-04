# TeamDocs (formerly Cloud Notes)

A Flutter application for team collaboration with workspaces, invitations, and role-based access control. Built with Firebase and Google Sign-In.

## Features

- 🔐 Google Sign-In authentication (auto-registration on first login)
- 👥 **Workspaces** - Organize notes by team or project
- 🎫 **Invitation System** - Secure token-based team invitations
- 👤 **Role-Based Access** - Owner, Editor, and Viewer roles
- 📝 Create, edit, and delete notes (with role-based permissions)
- ☁️ Real-time synchronization across devices
- 🌙 Dark mode support (follows system theme)
- 🎨 Material Design 3 UI
- 🌐 Web support (deploy to any static hosting)
- 📱 Cross-platform (Android, iOS, Web)

## Prerequisites

- Flutter SDK (3.0.0 or higher) with web support enabled
- Firebase project with:
  - Authentication enabled (Google Sign-In provider)
  - Firestore Database enabled
  - iOS/Android/Web apps configured

## Firebase Setup

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select an existing one
3. Enable **Google Analytics** (optional but recommended)

### 2. Configure Authentication

1. In Firebase Console, go to **Authentication** > **Sign-in method**
2. Enable **Google** as a sign-in provider
3. Add your project's support email
4. Save the changes

### 3. Configure Firestore

1. Go to **Firestore Database** in Firebase Console
2. Click **Create database**
3. Start in **production mode** (or test mode for development)
4. Choose your preferred location
5. Create the database

### 4. Set up Firestore Security Rules

Copy the complete security rules from `FIRESTORE_SECURITY_RULES.txt` or `FIRESTORE_SECURITY_RULES.md` and paste them into Firebase Console > Firestore > Rules.

**Steps:**
1. Open Firebase Console: https://console.firebase.google.com
2. Select your project
3. Go to Firestore Database → Rules tab
4. Copy the rules from `FIRESTORE_SECURITY_RULES.txt`
5. Paste into the Rules editor
6. Click "Publish"
7. Wait 1-2 minutes for rules to propagate

**Important:** 
- These rules support workspace-based access control with roles (Owner, Editor, Viewer)
- Users can only access notes in workspaces they belong to
- Only owners and editors can create/edit/delete notes
- Viewers can only read notes

### 5. Create Firestore Composite Indexes

The app requires composite indexes for workspace-based queries:

**Index 1: Notes by workspace**
- Collection: `notes`
- Fields: `workspaceId` (Ascending), `createdAt` (Descending)

**Option 1 (Automatic):**
When you first run the app and query notes, Firestore will automatically detect the need for an index and provide a link in the console/logs. Click the link to create the index.

**Option 2 (Manual):**

To manually create the composite index:

1. Go to [Firebase Console](https://console.firebase.google.com/) and select your project
2. Navigate to **Firestore Database** > **Indexes** tab
3. Click **"Create Index"** button
4. Configure the index:
   - **Collection ID**: `notes`
   - **Fields to index**:
     - Field: `userId`, Order: **Ascending**
     - Field: `createdAt`, Order: **Descending**
5. Click **"Create"** and wait for the index to build (may take a few minutes)

**Note:** The app will not work properly until this index is created. You'll see an error in the console if you try to query notes before the index is ready.

### 6. Add Firebase Configuration Files

#### Android Setup

1. In Firebase Console, go to **Project Settings** > **Your apps**
2. Click the Android icon to add an Android app
3. Register your app with package name: `com.qayham.cloudnotes` (or your preferred package name)
4. Download `google-services.json`
5. Place it in `android/app/` directory

#### iOS Setup

1. In Firebase Console, go to **Project Settings** > **Your apps**
2. Click the iOS icon to add an iOS app
3. Register your app with bundle ID: `com.example.cloudNotes` (or your preferred bundle ID)
4. Download `GoogleService-Info.plist`
5. Place it in `ios/Runner/` directory

### 7. Configure Android

1. Update `android/build.gradle`:
   ```gradle
   buildscript {
       dependencies {
           classpath 'com.google.gms:google-services:4.4.0'
       }
   }
   ```

2. Update `android/app/build.gradle`:
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

3. Update `android/app/src/main/AndroidManifest.xml` to include internet permission (usually already present):
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   ```

### 8. Configure iOS

1. Update `ios/Podfile` (if needed):
   ```ruby
   platform :ios, '12.0'
   ```

2. Run in `ios/` directory:
   ```bash
   pod install
   ```

3. Update `ios/Runner/Info.plist` to add URL scheme for Google Sign-In:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleTypeRole</key>
           <string>Editor</string>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>YOUR_REVERSED_CLIENT_ID</string>
           </array>
       </dict>
   </array>
   ```
   (Get `YOUR_REVERSED_CLIENT_ID` from `GoogleService-Info.plist`)

## Installation

1. Clone or download this project

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Ensure Firebase configuration files are in place:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`

4. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart                 # App entry point and routing
├── models/
│   └── note.dart           # Note data model
├── screens/
│   ├── login_screen.dart   # Google Sign-In screen
│   ├── notes_list_screen.dart  # Notes list with CRUD operations
│   └── note_edit_screen.dart   # Create/Edit note screen
└── services/
    ├── auth_service.dart   # Firebase Auth service
    └── notes_service.dart  # Firestore CRUD service
```

## Usage

1. **First Launch**: Tap "Sign in with Google" to authenticate
2. **Create Note**: Tap the + button on the notes list screen
3. **Edit Note**: Tap on any note in the list
4. **Delete Note**: Tap the menu icon (three dots) on a note and select "Delete"
5. **Logout**: Tap the logout icon in the app bar

## Notes

- Notes are automatically synced in real-time across all devices
- Each note contains: title, content, creation date, and user ID
- Notes are stored in Firestore collection: `notes`
- All notes are linked to the authenticated user's Firebase UID

## Troubleshooting

### Google Sign-In not working
- Ensure `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) is correctly placed
- Verify Google Sign-In is enabled in Firebase Console
- Check that SHA-1 fingerprint is added for Android (if required)

### Firestore permission errors
- Verify security rules are correctly set up
- Ensure user is authenticated before accessing notes

### Build errors
- Run `flutter clean` and `flutter pub get`
- For iOS: Run `pod install` in `ios/` directory
- Ensure Flutter SDK version is 3.0.0 or higher

## License

This project is provided as-is for educational and development purposes.
