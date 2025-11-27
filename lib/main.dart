import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'services/user_service.dart';
import 'services/envelope_repo.dart';
import 'screens/onboarding_flow.dart';
import 'screens/home_screen.dart';
import 'screens/sign_in_screen.dart'; // Your existing auth screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Envelope Lite',
      theme: themeProvider.currentTheme, // 🔥 Dynamic theme!
      home: const AuthGate(),
      routes: {'/home': (context) => const HomeScreenWrapper()},
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
        if (!snapshot.hasData) {
          return const SignInScreen(); // Your existing sign-in
        }

        final user = snapshot.data!;
        final userService = UserService(FirebaseFirestore.instance, user.uid);

        // Initialize theme provider with user service
        Provider.of<ThemeProvider>(
          context,
          listen: false,
        ).initialize(userService);

        // Check if user has completed onboarding
        return FutureBuilder<bool>(
          future: userService.hasCompletedOnboarding(),
          builder: (context, onboardingSnapshot) {
            if (!onboardingSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!onboardingSnapshot.data!) {
              // Show onboarding
              return OnboardingFlow(userService: userService);
            }

            // Show home
            return HomeScreenWrapper();
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

    return HomeScreen(repo: repo);
  }
}
