import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'config/firebase_config.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/workspaces_list_screen.dart';
import 'screens/invitation_acceptance_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with explicit configuration
  if (kIsWeb) {
    // Web Firebase configuration
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: FirebaseConfig.apiKey,
        authDomain: FirebaseConfig.authDomain,
        projectId: FirebaseConfig.projectId,
        storageBucket: FirebaseConfig.storageBucket,
        messagingSenderId: FirebaseConfig.messagingSenderId,
        appId: FirebaseConfig.appId,
        measurementId: FirebaseConfig.measurementId,
      ),
    );
  } else {
    // Mobile platforms use automatic configuration from google-services.json / GoogleService-Info.plist
    await Firebase.initializeApp();
  }

  runApp(const CloudNotesApp());
}

class CloudNotesApp extends StatelessWidget {
  const CloudNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cloud Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo - more vibrant
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF6366F1),
          secondary: const Color(0xFF8B5CF6),
          tertiary: const Color(0xFFEC4899),
          surface: const Color(0xFFFFFBFE),
          surfaceContainerHighest: const Color(0xFFF5F3FF),
          primaryContainer: const Color(0xFFE0E7FF),
          secondaryContainer: const Color(0xFFF3E8FF),
          errorContainer: const Color(0xFFFFDAD6), // Light red/pink background
          onErrorContainer: const Color(0xFF410002), // Dark text on error container
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFFFFFBFE),
          foregroundColor: Color(0xFF1E1B4B),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          elevation: 4,
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF818CF8), // Lighter indigo for dark mode
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF818CF8),
          secondary: const Color(0xFFA78BFA),
          tertiary: const Color(0xFFF472B6),
          surface: const Color(0xFF1E1B4B),
          surfaceContainerHighest: const Color(0xFF312E81),
          primaryContainer: const Color(0xFF4338CA),
          secondaryContainer: const Color(0xFF6D28D9),
          errorContainer: const Color(0xFF93000A), // Dark red background for dark mode
          onErrorContainer: const Color(0xFFFFDAD6), // Light text on error container for dark mode
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: const Color(0xFF312E81),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFF1E1B4B),
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          elevation: 4,
          backgroundColor: const Color(0xFF818CF8),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      onGenerateRoute: (settings) {
        // Handle invitation links: /join/{token}
        if (settings.name?.startsWith('/join/') == true) {
          final token = settings.name!.split('/join/').last;
          return MaterialPageRoute(
            builder: (context) => InvitationAcceptanceScreen(token: token),
          );
        }
        return null;
      },
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService authService = AuthService();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  String? _pendingInvitationToken;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _checkInitialLink();
  }

  void _initDeepLinks() {
    if (kIsWeb) return; // Web handles links via URL routing

    // Listen for deep links when app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('Deep link error: $err');
      },
    );
  }

  Future<void> _checkInitialLink() async {
    if (kIsWeb) {
      // Web: Check current URL - also check on every build
      final uri = Uri.base;
      if (uri.path.startsWith('/join/')) {
        final token = uri.path.split('/join/').last;
        if (token.isNotEmpty && _pendingInvitationToken != token) {
          setState(() {
            _pendingInvitationToken = token;
          });
        }
      }
      return;
    }

    // Mobile: Check if app was opened via deep link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    // Handle invitation links: https://domain.com/join/{token}
    // or custom scheme: yourapp://join/{token}
    final path = uri.path;
    if (path.startsWith('/join/')) {
      final token = path.split('/join/').last;
      if (token.isNotEmpty) {
        setState(() {
          _pendingInvitationToken = token;
        });
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check URL on every build for web (in case user navigates to invitation link)
    if (kIsWeb) {
      final uri = Uri.base;
      if (uri.path.startsWith('/join/')) {
        final token = uri.path.split('/join/').last;
        if (token.isNotEmpty && _pendingInvitationToken != token) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _pendingInvitationToken = token;
              });
            }
          });
        }
      }
    }

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }

        // If there's a pending invitation token, show invitation screen
        if (_pendingInvitationToken != null) {
          return InvitationAcceptanceScreen(token: _pendingInvitationToken!);
        }

        if (snapshot.hasData) {
          return const WorkspacesListScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
