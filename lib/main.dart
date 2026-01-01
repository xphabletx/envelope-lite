// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'providers/font_provider.dart';
import 'providers/workspace_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/time_machine_provider.dart';
import 'providers/onboarding_provider.dart';
import 'services/envelope_repo.dart';
import 'services/account_repo.dart';
import 'services/scheduled_payment_repo.dart';
import 'services/notification_repo.dart';
import 'services/repository_manager.dart';
import 'services/hive_service.dart';
import 'services/subscription_service.dart';
import 'screens/home_screen.dart';
import 'screens/auth/auth_wrapper.dart';
import 'widgets/app_lifecycle_observer.dart';

// Global navigator key for forced navigation (e.g., logout)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (still needed for auth and workspace sync)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[Main] 🔥 Firebase initialized');

  // Initialize Firebase App Check (only in Release mode to avoid debug token errors)
  if (kReleaseMode) {
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: AndroidPlayIntegrityProvider(),
        providerApple: AppleDeviceCheckProvider(),
      );
      debugPrint('[Main] ✅ Firebase App Check activated (Release mode)');
    } catch (e) {
      debugPrint('[Main] ⚠️ Firebase App Check activation failed: $e');
    }
  } else {
    debugPrint('[Main] ⚠️ Firebase App Check skipped (Debug mode)');
  }

  // 🔥 NUCLEAR OPTION: Completely disable Firebase offline features
  try {
    // Configure Firestore settings BEFORE any usage
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false, // Disable offline cache
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // Valid cache size
    );

    debugPrint('[Main] ⚠️ Firebase persistence DISABLED');
    debugPrint('[Main] ⚠️ Firebase cache size set to unlimited');
  } catch (e) {
    debugPrint('[Main] ⚠️ Could not configure Firebase settings: $e');
    debugPrint(
      '[Main] ⚠️ This is expected if settings were already configured',
    );
  }

  // NEW: Initialize Hive (local storage - our primary storage)
  try {
    await HiveService.init();
    debugPrint('[Main] 📦 Hive initialized successfully');

    // Validate all boxes are open
    final boxStatus = HiveService.validateBoxes();
    final allOpen = boxStatus.values.every((isOpen) => isOpen);
    if (!allOpen) {
      final closedBoxes = boxStatus.entries
          .where((e) => !e.value)
          .map((e) => e.key)
          .toList();
      debugPrint('[Main] ⚠️ Some Hive boxes failed to open: $closedBoxes');
    }
  } catch (e) {
    debugPrint('[Main] ❌ CRITICAL: Hive initialization failed: $e');
    debugPrint('[Main] ❌ App may not function correctly without local storage');
  }

  // NEW: Initialize RevenueCat
  await SubscriptionService().init();

  final prefs = await SharedPreferences.getInstance();
  final savedThemeId = prefs.getString('selected_theme_id');
  final savedWorkspaceId = prefs.getString('active_workspace_id');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(initialThemeId: savedThemeId),
        ),
        ChangeNotifierProvider(create: (_) => FontProvider()),
        ChangeNotifierProvider(
          create: (_) =>
              WorkspaceProvider(initialWorkspaceId: savedWorkspaceId),
        ),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => TimeMachineProvider()),
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
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

        // CRITICAL: KeyedSubtree inside Consumer ensures theme is evaluated
        // BEFORE widget tree is rebuilt on user change
        return KeyedSubtree(
          key: ValueKey(FirebaseAuth.instance.currentUser?.uid ?? 'logged-out'),
          child: MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Stuffrite',
            debugShowCheckedModeBanner: false,
          // Apply the dynamic font to the dynamic theme
          theme: baseTheme.copyWith(
            textTheme: fontTheme.apply(
              bodyColor: baseTheme.colorScheme.onSurface,
              displayColor: baseTheme.colorScheme.onSurface,
            ),
          ),
          // Global tap-to-dismiss keyboard behavior + back button handling
          builder: (context, child) {
            return PopScope(
              canPop: true,
              onPopInvokedWithResult: (bool didPop, dynamic result) {
                // This callback is called after a pop is handled
                // We don't need to do anything here as the home screen
                // will handle its own double-tap logic
              },
              child: GestureDetector(
                onTap: () {
                  // Unfocus any active text field when tapping outside
                  final currentFocus = FocusScope.of(context);
                  if (!currentFocus.hasPrimaryFocus &&
                      currentFocus.focusedChild != null) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  }
                },
                child: child,
              ),
            );
          },
          routes: {'/home': (context) => const HomeScreenWrapper()},
          home:
              const AuthGate(), // Uses AuthWrapper internally for email verification
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

    // Use AuthWrapper which handles email verification
    return const AuthWrapper();
  }
}

class HomeScreenWrapper extends StatelessWidget {
  const HomeScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final db = FirebaseFirestore.instance;

    // Listen to workspace changes and rebuild with a new repo
    return Consumer<WorkspaceProvider>(
      builder: (context, workspaceProvider, _) {
        final envelopeRepo = EnvelopeRepo.firebase(
          db,
          userId: user.uid,
          workspaceId: workspaceProvider.workspaceId,
        );

        // Clean up any orphaned scheduled payments from deleted envelopes
        // This is a one-time migration for existing users
        envelopeRepo.cleanupOrphanedScheduledPayments().then((count) {
          if (count > 0) {
            debugPrint('[Main] Cleaned up $count orphaned scheduled payments');
          }
        });

        // Initialize all repos
        final accountRepo = AccountRepo(envelopeRepo);
        final paymentRepo = ScheduledPaymentRepo(user.uid);
        final notificationRepo = NotificationRepo(userId: user.uid);

        // Register repositories with the global manager for cleanup on logout
        RepositoryManager().registerRepositories(
          envelopeRepo: envelopeRepo,
          accountRepo: accountRepo,
          scheduledPaymentRepo: paymentRepo,
          notificationRepo: notificationRepo,
        );

        final args = ModalRoute.of(context)?.settings.arguments;
        final initialIndex = args is int ? args : 0;

        return AppLifecycleObserver(
          envelopeRepo: envelopeRepo,
          paymentRepo: paymentRepo,
          notificationRepo: notificationRepo,
          child: HomeScreen(
            repo: envelopeRepo,
            initialIndex: initialIndex,
            notificationRepo: notificationRepo,
          ),
        );
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
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
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
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SizedBox.expand(
          child: Image.asset(
            'assets/logo/splash_screen_stuffrite.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
