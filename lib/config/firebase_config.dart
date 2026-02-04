/// Firebase Configuration
///
/// This file contains Firebase configuration constants.
/// For production, consider using environment variables or a config service.

class FirebaseConfig {
  // Firebase Web Configuration
  static const String apiKey = "AIzaSyD-nMxAkaIBDvKxgAR-MBbAQMTceKcwKv0";
  static const String authDomain = "cloud-notes-8e62d.firebaseapp.com";
  static const String projectId = "cloud-notes-8e62d";
  static const String storageBucket = "cloud-notes-8e62d.firebasestorage.app";
  static const String messagingSenderId = "360759372467";
  static const String appId = "1:360759372467:web:b7f2798e0b7c9a518b9ec6";
  static const String measurementId = "G-BCRH46KYFP";

  // Google Sign-In Web Client ID
  // Get this from: Firebase Console > Authentication > Sign-in method > Google > Web SDK configuration
  // TODO: Replace with your actual Web Client ID
  static const String googleWebClientId =
      "360759372467-tpcajd8iakrnevc2c6mv053b1nqo666m.apps.googleusercontent.com";
}
