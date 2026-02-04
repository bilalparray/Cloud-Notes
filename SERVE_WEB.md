# How to Serve Flutter Web App Locally

## The Problem
If you're seeing errors like:
- `flutter.js` 404 errors
- `_flutter is not defined`
- Resources not loading

It means you're serving from the wrong directory.

## ✅ Correct Way to Serve

### Option 1: Serve from `build/web` directory (Recommended)

**Using VS Code Live Server:**
1. Right-click on the `build/web` folder
2. Select "Open with Live Server"
3. The app will open at `http://127.0.0.1:5500` (or similar)

**Using Python:**
```bash
cd build/web
python -m http.server 8000
# Open: http://localhost:8000
```

**Using Node.js (http-server):**
```bash
npm install -g http-server
cd build/web
http-server -p 8000
# Open: http://localhost:8000
```

### Option 2: Use Flutter's Built-in Server (Easiest)

```bash
flutter run -d chrome
```

This automatically:
- Builds the app
- Serves it correctly
- Opens in Chrome
- Enables hot reload

### Option 3: Rebuild with Correct Base Path

If you must serve from a subdirectory:

```bash
flutter build web --release --base-href /build/web/
```

Then serve from the project root.

## ❌ Wrong Way (What You're Doing Now)

Don't serve from the project root and access `build/web/index.html` directly. This causes path issues.

## Quick Fix for Your Current Setup

1. **Stop your current server**
2. **Navigate to `build/web` folder in VS Code**
3. **Right-click `index.html` in the `build/web` folder**
4. **Select "Open with Live Server"**

Or use Flutter's built-in server:
```bash
flutter run -d chrome
```
