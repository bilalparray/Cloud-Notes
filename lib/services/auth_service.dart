import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../config/firebase_config.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final GoogleSignIn _googleSignIn;

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
      await Future.wait([
        _googleSignIn.signOut(),
        _auth.signOut(),
      ]);
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }
}
