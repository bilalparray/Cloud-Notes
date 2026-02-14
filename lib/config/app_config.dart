/// App URLs and version – update these in one place for Settings, share, and Play Store.
class AppConfig {
  AppConfig._();

  /// App version shown in Settings (About). Keep in sync with pubspec.yaml version.
  static const String appVersion = '1.0.0';

  /// Play Store app listing – used by "Check for updates" and share text.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.qayham.cloudnotes';

  /// Web app URL – used in share text.
  static const String webUrl = 'https://qayham.com/cloudnotes';

  /// Text shared when user taps "Share app" in Settings.
  static String get shareText =>
      'Check out Cloud Notes – sync your notes across devices.\n\n'
      'Android: $playStoreUrl\n'
      'Web: $webUrl';
}
