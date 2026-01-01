import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'email_verification_screen.dart';
import '../sign_in_screen.dart';
import '../onboarding/onboarding_flow.dart';
import '../../services/user_service.dart';
import '../../services/cloud_migration_service.dart';
import '../../providers/theme_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/workspace_provider.dart';
import '../../widgets/migration_overlay.dart';
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

  /// Build the user profile wrapper with migration support
  Widget _buildUserProfileWrapper(User user) {
    return _UserProfileWrapper(user: user);
  }
}

/// Stateful wrapper to handle cloud migration
class _UserProfileWrapper extends StatefulWidget {
  final User user;

  const _UserProfileWrapper({required this.user});

  @override
  State<_UserProfileWrapper> createState() => _UserProfileWrapperState();
}

class _UserProfileWrapperState extends State<_UserProfileWrapper> {
  final CloudMigrationService _migrationService = CloudMigrationService();
  bool _migrationChecked = false;

  @override
  void dispose() {
    _migrationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasCompletedOnboarding(widget.user.uid),
      builder: (context, snapshot) {
        // Show loading while checking onboarding status
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final hasCompletedOnboarding = snapshot.data ?? false;

        // Initialize providers (local-only)
        Provider.of<ThemeProvider>(
          context,
          listen: false,
        ).initialize();
        Provider.of<LocaleProvider>(
          context,
          listen: false,
        ).initialize(widget.user.uid);

        if (!hasCompletedOnboarding) {
          final userService = UserService(FirebaseFirestore.instance, widget.user.uid);
          return OnboardingFlow(userService: userService);
        }

        // User has completed onboarding - check for migration
        if (!_migrationChecked) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkMigration(widget.user);
          });
        }

        // Show migration overlay if in progress
        return StreamBuilder<MigrationProgress>(
          stream: _migrationService.progressStream,
          builder: (context, progressSnapshot) {
            final progress = progressSnapshot.data;

            // Migration in progress or not started
            if (progress != null && !progress.isComplete) {
              return RestorationOverlay(
                progressStream: _migrationService.progressStream,
                onCancel: () {
                  // Allow user to continue offline
                  setState(() => _migrationChecked = true);
                },
              );
            }

            // Migration complete or not needed
            return const HomeScreenWrapper();
          },
        );
      },
    );
  }

  Future<void> _checkMigration(User user) async {
    setState(() => _migrationChecked = true);

    // Get workspace ID from provider
    final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
    final workspaceId = workspaceProvider.workspaceId;

    // Trigger migration if in workspace mode
    if (workspaceId != null && workspaceId.isNotEmpty) {
      debugPrint('[AuthWrapper] 🔄 Starting cloud migration for workspace: $workspaceId');
      await _migrationService.migrateIfNeeded(
        userId: user.uid,
        workspaceId: workspaceId,
      );
    } else {
      debugPrint('[AuthWrapper] ⏭️ Solo mode: skipping cloud migration');
    }
  }

  /// Check if user has completed onboarding (local-only via SharedPreferences)
  Future<bool> _hasCompletedOnboarding(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hasCompletedOnboarding_$userId') ?? false;
  }
}

/// Original standalone function (kept for backwards compatibility)
Future<bool> _hasCompletedOnboarding(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('hasCompletedOnboarding_$userId') ?? false;
}
