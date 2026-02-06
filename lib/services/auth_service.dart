import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../config/firebase_config.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final GoogleSignIn _googleSignIn;
  bool _isDemoMode = false;

  AuthService() {
    // Configure Google Sign-In for web with client ID
    if (kIsWeb) {
      // For web, you need to provide the client ID from Firebase Console
      // Get it from: Firebase Console > Authentication > Sign-in method > Google > Web SDK configuration
      _googleSignIn = GoogleSignIn(
        clientId: FirebaseConfig.googleWebClientId == 'YOUR_WEB_CLIENT_ID_HERE'
            ? null
            : FirebaseConfig.googleWebClientId,
        scopes: ['email', 'profile'],
      );
    } else {
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
    }
  }

  User? get currentUser => _auth.currentUser;

  bool get isDemoMode => _isDemoMode;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      throw Exception('Failed to sign in with Google: $e');
    }
  }

  Future<void> signOut() async {
    try {
      _isDemoMode = false;
      await Future.wait([
        _googleSignIn.signOut(),
        _auth.signOut(),
      ]);
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  /// Sign in with demo mode using Firebase Anonymous Authentication
  /// This allows Play Store reviewers to test the app without Google Sign-In
  /// Available to all users - no admin restrictions
  Future<UserCredential> signInWithDemo() async {
    try {
      _isDemoMode = true;
      // Use Firebase Anonymous Authentication for demo mode
      // This creates a temporary anonymous account that works with all Firebase features
      // Available to everyone - no administrator restrictions
      final userCredential = await _auth.signInAnonymously();

      // Update the display name to indicate it's a demo account
      await userCredential.user?.updateDisplayName('Demo User');
      await userCredential.user?.reload();

      return userCredential;
    } catch (e) {
      _isDemoMode = false;
      // Provide a more helpful error message
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('anonymous') || errorMessage.contains('auth')) {
        throw Exception(
            'Demo mode requires Anonymous Authentication to be enabled in Firebase Console. Please enable it in Authentication > Sign-in method > Anonymous');
      }
      throw Exception('Failed to sign in with demo: $e');
    }
  }
}
