// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'providers/font_provider.dart';
import 'providers/app_preferences_provider.dart';
import 'providers/workspace_provider.dart';
import 'providers/locale_provider.dart';
import 'services/user_service.dart';
import 'services/envelope_repo.dart';
import 'services/tutorial_controller.dart';
import 'screens/home_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'models/user_profile.dart';
import 'widgets/app_lifecycle_observer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final prefs = await SharedPreferences.getInstance();
  final savedThemeId = prefs.getString('selected_theme_id');
  final savedWorkspaceId = prefs.getString('selected_workspace_id');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(initialThemeId: savedThemeId),
        ),
        ChangeNotifierProvider(create: (_) => FontProvider()),
        ChangeNotifierProvider(create: (_) => AppPreferencesProvider()),
        ChangeNotifierProvider(create: (_) => TutorialController()),
        ChangeNotifierProvider(
          create: (_) => WorkspaceProvider(initialWorkspaceId: savedWorkspaceId),
        ),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, FontProvider>(
      builder: (context, themeProvider, fontProvider, child) {
        final baseTheme = themeProvider.currentTheme;
        final fontTheme = fontProvider.getTextTheme();

        return AppLifecycleObserver(
          // Wrap MaterialApp with AppLifecycleObserver
          child: MaterialApp(
            title: 'Envelope Lite',
            debugShowCheckedModeBanner: false,
            // Apply the dynamic font to the dynamic theme
            theme: baseTheme.copyWith(
              textTheme: fontTheme.apply(
                bodyColor: baseTheme.colorScheme.onSurface,
                displayColor: baseTheme.colorScheme.onSurface,
              ),
            ),
            // Global tap-to-dismiss keyboard behavior
            builder: (context, child) {
              return GestureDetector(
                onTap: () {
                  // Unfocus any active text field when tapping outside
                  final currentFocus = FocusScope.of(context);
                  if (!currentFocus.hasPrimaryFocus &&
                      currentFocus.focusedChild != null) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  }
                },
                child: child,
              );
            },
            routes: {'/home': (context) => const HomeScreenWrapper()},
            home: const AuthGate(),
          ),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // Hide splash after 3 seconds (1.5s fade in + 1.5s fade out)
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const SplashScreen();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return const SignInScreen();
        }

        final user = snapshot.data!;
        final userService = UserService(FirebaseFirestore.instance, user.uid);

        return StreamBuilder<UserProfile?>(
          stream: userService.userProfileStream,
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = profileSnap.data;

            if (profile != null) {
              // Initialize theme provider with user data if available
              Provider.of<ThemeProvider>(
                context,
                listen: false,
              ).initialize(userService);
              // Initialize locale provider
              Provider.of<LocaleProvider>(
                context,
                listen: false,
              ).initialize(user.uid);
            }

            if (profile == null || !profile.hasCompletedOnboarding) {
              return OnboardingFlow(userService: userService);
            }

            return const HomeScreenWrapper();
          },
        );
      },
    );
  }
}

class HomeScreenWrapper extends StatelessWidget {
  const HomeScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    // Listen to workspace changes and rebuild with a new repo
    return Consumer<WorkspaceProvider>(
      builder: (context, workspaceProvider, _) {
        final repo = EnvelopeRepo.firebase(
          FirebaseFirestore.instance,
          userId: user.uid,
          workspaceId: workspaceProvider.workspaceId,
        );

        final args = ModalRoute.of(context)?.settings.arguments;
        final initialIndex = args is int ? args : 0;

        return HomeScreen(repo: repo, initialIndex: initialIndex);
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // Create fade in and fade out animation
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50.0,
      ),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final imageSize = screenSize.width * 0.8; // 80% of screen width

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Image.asset(
            'assets/logo/develapp_logo.png',
            width: imageSize,
            height: imageSize,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
