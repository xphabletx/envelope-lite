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
import 'services/user_service.dart';
import 'services/envelope_repo.dart';
import 'services/tutorial_controller.dart'; // Added
import 'screens/home_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/onboarding_flow.dart';
import 'models/user_profile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final prefs = await SharedPreferences.getInstance();
  final savedThemeId = prefs.getString('selected_theme_id');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(initialThemeId: savedThemeId),
        ),
        ChangeNotifierProvider(create: (_) => FontProvider()),
        ChangeNotifierProvider(create: (_) => AppPreferencesProvider()),
        ChangeNotifierProvider(create: (_) => TutorialController()), // Added
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
          debugShowCheckedModeBanner: false,
          theme: baseTheme.copyWith(
            textTheme: fontTheme.apply(
              bodyColor: baseTheme.colorScheme.onSurface,
              displayColor: baseTheme.colorScheme.onSurface,
            ),
          ),
          routes: {'/home': (context) => const HomeScreenWrapper()},
          home: const AuthGate(),
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
              Provider.of<ThemeProvider>(
                context,
                listen: false,
              ).initialize(userService);
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
    final repo = EnvelopeRepo.firebase(
      FirebaseFirestore.instance,
      userId: user.uid,
    );

    final args = ModalRoute.of(context)?.settings.arguments;
    final initialIndex = args is int ? args : 0;

    return HomeScreen(repo: repo, initialIndex: initialIndex);
  }
}
