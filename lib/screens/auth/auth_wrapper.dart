import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'email_verification_screen.dart';
import '../sign_in_screen.dart';
import '../onboarding/onboarding_flow.dart';
import '../../services/user_service.dart';
import '../../models/user_profile.dart';
import '../../providers/theme_provider.dart';
import '../../providers/locale_provider.dart';
import '../../main.dart';

/// Auth Wrapper
///
/// Handles authentication state and email verification routing.
///
/// Flow:
/// 1. Not signed in → SignInScreen
/// 2. Google/Apple user → Skip verification (auto-verified)
/// 3. Email/password user + verified → HomeScreen
/// 4. Email/password user + unverified + old account (>7 days) → HomeScreen (with banner)
/// 5. Email/password user + unverified + new account (<7 days) → EmailVerificationScreen (BLOCKED)
/// 6. Anonymous user → HomeScreen
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Not signed in
        if (!snapshot.hasData) {
          return const SignInScreen();
        }

        final user = snapshot.data!;

        // Anonymous users - let them in (no verification needed)
        if (user.isAnonymous) {
          debugPrint('[AuthWrapper] Anonymous user - no verification needed');
          return _buildUserProfileWrapper(user);
        }

        // Get sign-in method
        final signInMethod = user.providerData.isNotEmpty
            ? user.providerData.first.providerId
            : 'password';

        // Google/Apple Sign-In users are auto-verified
        final isGoogleOrApple =
            signInMethod == 'google.com' || signInMethod == 'apple.com';

        if (isGoogleOrApple) {
          debugPrint('[AuthWrapper] Google/Apple user - auto-verified');
          return _buildUserProfileWrapper(user);
        }

        // Email/password users need verification check
        if (user.emailVerified) {
          debugPrint('[AuthWrapper] Email verified ✅');
          return _buildUserProfileWrapper(user);
        }

        // Unverified email/password user
        debugPrint('[AuthWrapper] Email NOT verified');

        // Check if account is old (grandfather clause)
        final accountCreated = user.metadata.creationTime;
        if (accountCreated == null) {
          // Safety fallback - if we can't determine age, treat as old account
          debugPrint(
              '[AuthWrapper] Cannot determine account age - grandfathering in');
          return _buildUserProfileWrapper(user);
        }

        final now = DateTime.now();
        final accountAge = now.difference(accountCreated).inDays;

        // Accounts older than 7 days = existing users (grandfathered)
        // Let them in but show optional banner
        if (accountAge > 7) {
          debugPrint('[AuthWrapper] Old account ($accountAge days) - grandfathered in');
          return _buildUserProfileWrapper(user);
        }

        // New account (< 7 days old) - REQUIRE verification
        debugPrint('[AuthWrapper] New account ($accountAge days) - verification required');
        return const EmailVerificationScreen();
      },
    );
  }

  /// Build the user profile wrapper (same logic as before)
  Widget _buildUserProfileWrapper(User user) {
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
  }
}
