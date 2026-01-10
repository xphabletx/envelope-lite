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
import 'providers/repository_provider.dart';
import 'services/envelope_repo.dart';
import 'services/account_repo.dart';
import 'services/scheduled_payment_repo.dart';
import 'services/notification_repo.dart';
import 'services/repository_manager.dart';
import 'services/hive_service.dart';
import 'services/subscription_service.dart';
import 'services/logger_service.dart';
import 'services/app_update_service.dart';
import 'services/cloud_migration_service.dart';
import 'screens/home_screen.dart';
import 'screens/auth/auth_wrapper.dart';
import 'widgets/app_lifecycle_observer.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Global navigator key for forced navigation (e.g., logout)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (still needed for auth and workspace sync)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Firebase App Check (only in Release mode to avoid debug token errors)
  if (kReleaseMode) {
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: AndroidPlayIntegrityProvider(),
        providerApple: AppleDeviceCheckProvider(),
      );
    } catch (e) {
    }
  } else {
  }

  // 🔥 Enable Firebase persistence for offline sync
  try {
    // Configure Firestore settings BEFORE any usage
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true, // ENABLE offline cache for sync queue
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // Valid cache size
    );

  } catch (e) {
  }

  // NEW: Initialize Hive (local storage - our primary storage)
  try {
    await HiveService.init();

    // Validate all boxes are open
    final boxStatus = HiveService.validateBoxes();
    boxStatus.values.every((isOpen) => isOpen);
  } catch (e) {
  }

  // NEW: Initialize RevenueCat
  await SubscriptionService().init();

  // Initialize Logger Service
  await LoggerService.init();

  // Log app version on startup
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    await LoggerService.info(
      'App started: v${packageInfo.version} (${packageInfo.buildNumber})',
    );
  } catch (e) {
  }

  // Initialize Firebase Remote Config for update checking
  try {
    await AppUpdateService.init();
  } catch (e) {
  }

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
        ChangeNotifierProvider(create: (_) => RepositoryProvider()),
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

        return MaterialApp(
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
          builder: (context, widgetChild) {
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
                child: widgetChild,
              ),
            );
          },
          routes: {'/home': (context) => const HomeScreenWrapper()},
          home: const AuthGate(),
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
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Start minimum splash duration timer (4 seconds to ensure all initialization completes)
    final splashTimer = Future.delayed(const Duration(milliseconds: 4000));

    // Wait for authentication state to be ready
    final user = await FirebaseAuth.instance.authStateChanges().first;

    // If user is logged in, perform data restoration during splash
    if (user != null && mounted) {
      // Pre-initialize providers
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
      final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
      final repositoryProvider = Provider.of<RepositoryProvider>(context, listen: false);

      themeProvider.initialize();
      localeProvider.initialize(user.uid);

      // Check if user is brand new (skip restoration for brand new users)
      final creationTime = user.metadata.creationTime;
      final lastSignInTime = user.metadata.lastSignInTime;
      final isBrandNewUser =
          creationTime != null &&
          lastSignInTime != null &&
          lastSignInTime.difference(creationTime).inSeconds < 5;

      // Start subscription check, migration, and repository initialization in parallel
      final subscriptionFuture = SubscriptionService().hasActiveSubscription(
        userEmail: user.email,
      ).then((hasSub) {
        return hasSub;
      }).catchError((e) {
        return false;
      });

      Future<void>? migrationFuture;
      if (!isBrandNewUser) {
        // Perform data restoration during splash
        final migrationService = CloudMigrationService();

        migrationFuture = migrationService.migrateIfNeeded(
          userId: user.uid,
          workspaceId: workspaceProvider.workspaceId,
        ).then((_) {
          migrationService.dispose();
        }).catchError((e) {
          migrationService.dispose();
          // Continue anyway - user can access app offline
        });
      }

      // Initialize repositories during splash to prevent home screen loading delays
      final repositoryFuture = _initializeRepositories(
        user: user,
        workspaceProvider: workspaceProvider,
        repositoryProvider: repositoryProvider,
      );

      // Wait for subscription check, migration, and repository initialization to complete
      await Future.wait([
        subscriptionFuture,
        if (migrationFuture != null) migrationFuture,
        repositoryFuture,
      ]);
    }

    // Ensure minimum splash duration has elapsed
    await splashTimer;

    if (mounted) {
      setState(() {
        _showSplash = false;
      });
    }
  }

  /// Initialize repositories during splash screen
  /// This prevents the brief loading spinner after splash ends
  Future<void> _initializeRepositories({
    required User user,
    required WorkspaceProvider workspaceProvider,
    required RepositoryProvider repositoryProvider,
  }) async {
    try {
      final db = FirebaseFirestore.instance;

      // Create all repositories
      final envelopeRepo = EnvelopeRepo.firebase(
        db,
        userId: user.uid,
        workspaceId: workspaceProvider.workspaceId,
      );

      final accountRepo = AccountRepo(envelopeRepo);
      final scheduledPaymentRepo = ScheduledPaymentRepo(user.uid);
      final notificationRepo = NotificationRepo(userId: user.uid);

      // Register with the global manager for cleanup on logout
      RepositoryManager().registerRepositories(
        envelopeRepo: envelopeRepo,
        accountRepo: accountRepo,
        scheduledPaymentRepo: scheduledPaymentRepo,
        notificationRepo: notificationRepo,
      );

      // Store in provider for immediate access by HomeScreen
      await repositoryProvider.initializeRepositories(
        envelopeRepo: envelopeRepo,
        accountRepo: accountRepo,
        scheduledPaymentRepo: scheduledPaymentRepo,
        notificationRepo: notificationRepo,
      );

    } catch (e) {
      // Continue anyway - repositories will be created later if needed
    }
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
    // Listen to workspace changes and repository initialization
    return Consumer2<WorkspaceProvider, RepositoryProvider>(
      builder: (context, workspaceProvider, repositoryProvider, _) {
        // If repositories are not initialized yet (edge case), show loading
        if (!repositoryProvider.areRepositoriesInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Get repositories from provider (already initialized during splash)
        final envelopeRepo = repositoryProvider.envelopeRepo!;
        final paymentRepo = repositoryProvider.scheduledPaymentRepo!;
        final notificationRepo = repositoryProvider.notificationRepo!;

        final args = ModalRoute.of(context)?.settings.arguments;
        final initialIndex = args is int ? args : 0;

        return AppLifecycleObserver(
          envelopeRepo: envelopeRepo,
          paymentRepo: paymentRepo,
          notificationRepo: notificationRepo,
          child: HomeScreen(
            repo: envelopeRepo,
            scheduledPaymentRepo: paymentRepo,
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
      duration: const Duration(milliseconds: 4000),
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
