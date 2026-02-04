# Building Cloud Notes for Web

## Quick Build Commands

### 1. Development Build (Test Locally)

```bash
flutter run -d chrome
```

This will:
- Build the app in debug mode
- Open it in Chrome automatically
- Enable hot reload for development

### 2. Production Build (For Deployment)

```bash
flutter build web --release
```

This creates an optimized production build in `build/web/` folder.

### 3. Optimized Production Build (Recommended)

```bash
flutter build web --release --web-renderer canvaskit
```

**Options:**
- `--web-renderer canvaskit`: Better compatibility, larger bundle (~2MB)
- `--web-renderer html`: Smaller bundle (~500KB), better performance (modern browsers only)

## Build Output

After building, your files will be in:
```
build/web/
├── index.html
├── main.dart.js
├── assets/
└── ...
```

## Deploy the Build

### Option 1: Firebase Hosting (Recommended)

```bash
# Install Firebase CLI (one-time)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase Hosting
firebase init hosting
# Select: build/web as public directory
# Configure as single-page app: Yes

# Build and Deploy
flutter build web --release
firebase deploy --only hosting
```

Your app will be live at: `https://cloud-notes-8e62d.web.app`

### Option 2: Netlify

1. Build: `flutter build web --release`
2. Go to [Netlify Drop](https://app.netlify.com/drop)
3. Drag and drop the `build/web` folder

### Option 3: Vercel

```bash
npm install -g vercel
flutter build web --release
vercel --prod build/web
```

### Option 4: Any Static Host

1. Build: `flutter build web --release`
2. Upload all files from `build/web/` to your web server

## Important Before Deploying

1. ✅ **Web Client ID**: Make sure it's set in `lib/config/firebase_config.dart` (you've done this!)
2. ✅ **Authorized Domains**: Add your domain in Firebase Console > Authentication > Settings
3. ✅ **Redirect URIs**: Add your domain in Google Cloud Console > OAuth 2.0 Client IDs

## Troubleshooting

### Build Fails
```bash
flutter clean
flutter pub get
flutter build web --release
```

### Large Bundle Size
- Use `--web-renderer html` for smaller builds
- Enable tree-shaking (already enabled by default)

### CORS Errors
- Ensure authorized domains are set in Firebase Console
- Check that your domain matches exactly

## Next Steps

1. Test locally: `flutter run -d chrome`
2. Build for production: `flutter build web --release`
3. Deploy to your chosen platform
4. Test the deployed app
