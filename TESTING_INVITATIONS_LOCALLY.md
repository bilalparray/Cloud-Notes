# Testing Invitations Locally (No Production Required)

## Quick Start

You can test invitation links locally without any production setup! Here's how:

## Method 1: Web Testing (Easiest)

### Step 1: Run the app on web
```bash
flutter run -d chrome
# or
flutter run -d edge
```

The app will open at something like: `http://localhost:5501`

### Step 2: Create an invitation
1. Sign in with Google
2. Create a workspace (or use existing)
3. Click "Invite Teammate"
4. Select a role (Editor/Viewer)
5. Copy the invitation link

The link will look like: `http://localhost:5501/join/{token}`

### Step 3: Test the invitation
**Option A: Same browser, incognito window**
1. Open an incognito/private window
2. Paste the invitation link
3. Sign in with a different Google account
4. Accept the invitation

**Option B: Different browser**
1. Open a different browser (Chrome → Firefox, or vice versa)
2. Paste the invitation link
3. Sign in with a different Google account
4. Accept the invitation

**Option C: Share with teammate**
1. Copy the link
2. Send it to a teammate via email/SMS
3. They open it in their browser
4. They sign in and accept

## Method 2: Mobile Testing (Android/iOS)

### For Android Emulator/Device

**Option 1: Use localhost (if testing on same machine)**
1. Run the app: `flutter run`
2. Create invitation link
3. The link will be: `http://localhost:5501/join/{token}`
4. Open Chrome on the emulator/device
5. Navigate to the link
6. It should open the app (if deep linking is configured)

**Option 2: Use your local network IP (recommended for real devices)**

1. **Find your local IP address:**
   - **Windows**: Open CMD, run `ipconfig`, look for "IPv4 Address"
   - **Mac/Linux**: Run `ifconfig` or `ip addr`, look for inet address
   - Example: `192.168.1.100`

2. **Update the invitation service** (temporary for testing):
   ```dart
   // In lib/services/invitation_service.dart, line ~120
   // Replace localhost with your IP
   return 'http://192.168.1.100:5501/join/$token';
   ```

3. **Make sure Flutter web server is accessible:**
   ```bash
   flutter run -d chrome --web-port=5501 --web-hostname=0.0.0.0
   ```
   This makes the server accessible on your local network.

4. **Test:**
   - Create invitation on your computer
   - Open the link on your phone (must be on same WiFi network)
   - Link: `http://192.168.1.100:5501/join/{token}`

### For iOS Simulator/Device

Same as Android, but:
- Use Safari instead of Chrome
- Universal Links work better on real devices than simulator

## Method 3: Using ngrok (Share with anyone, anywhere)

This lets you create a public URL that tunnels to your localhost.

### Setup ngrok:

1. **Install ngrok:**
   - Download from: https://ngrok.com/download
   - Or: `choco install ngrok` (Windows) / `brew install ngrok` (Mac)

2. **Run your Flutter app:**
   ```bash
   flutter run -d chrome --web-port=5501
   ```

3. **Start ngrok tunnel:**
   ```bash
   ngrok http 5501
   ```

4. **Copy the HTTPS URL:**
   - ngrok will show something like: `https://abc123.ngrok.io`
   - Copy this URL

5. **Update invitation link generation** (temporary):
   ```dart
   // In lib/services/invitation_service.dart
   // Replace the development return with:
   return 'https://abc123.ngrok.io/join/$token';
   // (Use your actual ngrok URL)
   ```

6. **Test:**
   - Create invitation
   - Share the link with anyone (even outside your network)
   - They can open it and test

**Note:** Free ngrok URLs change each time you restart. For testing, this is fine.

## Testing Flow

### Complete Test Scenario:

1. **User A (Workspace Owner):**
   - Signs in
   - Creates workspace "Test Team"
   - Clicks "Invite Teammate"
   - Selects "Editor" role
   - Copies link: `http://localhost:5501/join/abc123token`

2. **User B (Invitee):**
   - Opens link in browser/incognito
   - Sees invitation screen with workspace details
   - Signs in with Google (different account)
   - Clicks "Accept Invitation"
   - Gets added to workspace as Editor
   - Redirected to workspace notes

3. **Verify:**
   - User B can see the workspace in their workspace list
   - User B can create/edit notes (Editor role)
   - User A can see User B in workspace members

## Troubleshooting

### "Invitation not found" error
- Check that the token in the URL matches what was created
- Verify Firestore security rules allow reading invitations
- Check browser console for errors

### Link doesn't open app (mobile)
- Make sure deep linking is configured (see DEEP_LINKING_SETUP.md)
- For now, links will open in browser (which is fine for testing)
- You can manually navigate to the app after accepting

### "Permission denied" when accepting
- Make sure both users are signed in
- Check Firestore security rules
- Verify the invitation token is valid and not expired

### Can't access localhost from phone
- Make sure phone and computer are on same WiFi network
- Use your local IP address instead of localhost
- Check firewall isn't blocking port 5501

## Quick Test Checklist

- [ ] Create workspace
- [ ] Generate invitation link
- [ ] Open link in incognito/different browser
- [ ] Sign in with different account
- [ ] Accept invitation
- [ ] Verify user added to workspace
- [ ] Test role permissions (Editor can edit, Viewer can only read)

## Production vs Development

**Current setup:**
- Development mode: Uses `localhost:5501` or your local IP
- Production mode: Will use your actual domain

**To switch to production:**
1. Deploy your app to Firebase Hosting or your server
2. Update `isDevelopment = false` in `workspaces_list_screen.dart`
3. The app will automatically use your production domain

## Tips

1. **Use different Google accounts** to test properly
2. **Test both roles** (Editor and Viewer) to verify permissions
3. **Test expired invitations** by manually setting expiry in Firestore
4. **Test used invitations** by trying to accept the same link twice
5. **Check Firestore console** to see invitation documents being created/updated
