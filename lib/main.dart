import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'providers/font_provider.dart';
import 'providers/app_preferences_provider.dart';
import 'services/user_service.dart';
import 'services/envelope_repo.dart';
import 'screens/onboarding_flow.dart';
import 'screens/home_screen.dart';
import 'screens/sign_in_screen.dart';

// DEBUG FLAG: Set to true to always show onboarding (for testing)
const bool _FORCE_ONBOARDING_FOR_TESTING = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FontProvider()),
        ChangeNotifierProvider(create: (_) => AppPreferencesProvider()),
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
          title: 'Envelope Lite',
          theme: baseTheme.copyWith(
            textTheme: fontTheme.apply(
              bodyColor: baseTheme.colorScheme.onSurface,
              displayColor: baseTheme.colorScheme.onSurface,
            ),
          ),
          home: const AuthGate(),
          routes: {'/home': (context) => const HomeScreenWrapper()},
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Not signed in - show sign in screen
        if (!snapshot.hasData) {
          return const SignInScreen();
        }

        final user = snapshot.data!;
        final userService = UserService(FirebaseFirestore.instance, user.uid);

        // Initialize theme provider with user service
        Provider.of<ThemeProvider>(
          context,
          listen: false,
        ).initialize(userService);

        // --- BYPASS MODIFICATION ---
        // We skip the FutureBuilder that checks userService.hasCompletedOnboarding()
        // and immediately return the Home Screen.
        return const HomeScreenWrapper();
      },
    );
  }
}

class HomeScreenWrapper extends StatelessWidget {
  const HomeScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final repo = EnvelopeRepo.firebase(
      FirebaseFirestore.instance,
      userId: user.uid,
    );

    return HomeScreen(repo: repo);
  }
}
