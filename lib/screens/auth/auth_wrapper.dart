import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'email_verification_screen.dart';
import '../sign_in_screen.dart';
import '../onboarding/consolidated_onboarding_flow.dart';
import 'stuffrite_paywall_screen.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../services/cloud_migration_service.dart';
import '../../services/subscription_service.dart';
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
    // CRITICAL: Check if we're logging out FIRST to prevent phantom builds
    final workspaceProvider = Provider.of<WorkspaceProvider>(context);
    if (workspaceProvider.isLoggingOut) {
      debugPrint('[AuthWrapper] 🚫 Logging out - showing loading screen to prevent phantom build');
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Not signed in - Use ValueKey to force complete widget tree teardown
        // When UID changes from logged-in → null, Flutter destroys entire tree
        // This kills all Firestore listeners and prevents PERMISSION_DENIED errors
        if (!snapshot.hasData) {
          return SignInScreen(key: const ValueKey('logged-out'));
        }

        final user = snapshot.data!;

        // Anonymous users - let them in (no verification needed)
        // Use ValueKey with UID to force tree rebuild when user changes
        if (user.isAnonymous) {
          debugPrint('[AuthWrapper] Anonymous user - no verification needed');
          return Container(
            key: ValueKey(user.uid),
            child: _buildUserProfileWrapper(user),
          );
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
          return Container(
            key: ValueKey(user.uid),
            child: _buildUserProfileWrapper(user),
          );
        }

        // Email/password users need verification check
        if (user.emailVerified) {
          debugPrint('[AuthWrapper] Email verified ✅');
          return Container(
            key: ValueKey(user.uid),
            child: _buildUserProfileWrapper(user),
          );
        }

        // Unverified email/password user
        debugPrint('[AuthWrapper] Email NOT verified');

        // Check if account is old (grandfather clause)
        final accountCreated = user.metadata.creationTime;
        if (accountCreated == null) {
          // Safety fallback - if we can't determine age, treat as old account
          debugPrint(
              '[AuthWrapper] Cannot determine account age - grandfathering in');
          return Container(
            key: ValueKey(user.uid),
            child: _buildUserProfileWrapper(user),
          );
        }

        final now = DateTime.now();
        final accountAge = now.difference(accountCreated).inDays;

        // Accounts older than 7 days = existing users (grandfathered)
        // Let them in but show optional banner
        if (accountAge > 7) {
          debugPrint('[AuthWrapper] Old account ($accountAge days) - grandfathered in');
          return Container(
            key: ValueKey(user.uid),
            child: _buildUserProfileWrapper(user),
          );
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
  bool _restorationComplete = false;
  bool? _hasCompletedOnboarding;

  @override
  void initState() {
    super.initState();
    // Start restoration immediately
    _performRestoration();
  }

  @override
  void dispose() {
    _migrationService.dispose();
    super.dispose();
  }

  Future<void> _performRestoration() async {
    // Initialize providers (local-only)
    Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).initialize();
    Provider.of<LocaleProvider>(
      context,
      listen: false,
    ).initialize(widget.user.uid);

    // Check if user is brand new (first sign-in)
    final creationTime = widget.user.metadata.creationTime;
    final lastSignInTime = widget.user.metadata.lastSignInTime;
    final isBrandNewUser = creationTime != null &&
                           lastSignInTime != null &&
                           lastSignInTime.difference(creationTime).inSeconds < 5;

    if (isBrandNewUser) {
      // Brand new user - skip migration and go straight to onboarding
      debugPrint('[AuthWrapper] 👶 Brand new user detected - skipping restoration check');

      // CRITICAL: Clear any ghost data from previous accounts
      debugPrint('[AuthWrapper] 🧹 Clearing local onboarding flags for brand new user');
      await AuthService.clearLocalOnboardingFlags(widget.user.uid);

      // CRITICAL: Clear Hive data if it belongs to a different user
      debugPrint('[AuthWrapper] 🧹 Checking Hive data for user changes');
      await AuthService.clearHiveIfDifferentUser(widget.user.uid);

      final completed = await _checkOnboardingStatus(widget.user.uid);

      if (mounted) {
        setState(() {
          _hasCompletedOnboarding = completed;
          _restorationComplete = true;
        });
      }
      return;
    }

    // Returning user - perform restoration check
    debugPrint('[AuthWrapper] 🔄 Returning user - starting restoration check');

    // Get workspace ID from provider
    final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
    final workspaceId = workspaceProvider.workspaceId;

    await _migrationService.migrateIfNeeded(
      userId: widget.user.uid,
      workspaceId: workspaceId,
    );

    // Check if user has completed onboarding (after restoration completes)
    final completed = await _checkOnboardingStatus(widget.user.uid);

    if (mounted) {
      setState(() {
        _hasCompletedOnboarding = completed;
        _restorationComplete = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // RESTORATION GATE: Show restoration overlay until complete
    if (!_restorationComplete) {
      return RestorationOverlay(
        progressStream: _migrationService.progressStream,
        onCancel: () {
          // Allow user to continue offline
          if (mounted) {
            setState(() => _restorationComplete = true);
          }
        },
      );
    }

    // Restoration complete - decide based on whether user has completed onboarding
    final hasCompletedOnboarding = _hasCompletedOnboarding ?? false;

    // TEMPORARY: Skip onboarding for debugging
    const bool SKIP_ONBOARDING = false;

    if (!hasCompletedOnboarding && !SKIP_ONBOARDING) {
      // New user or hasn't completed onboarding - show onboarding flow
      debugPrint('[AuthWrapper] 📝 No onboarding completion - showing ConsolidatedOnboardingFlow');
      return ConsolidatedOnboardingFlow(userId: widget.user.uid);
    }

    if (SKIP_ONBOARDING && !hasCompletedOnboarding) {
      debugPrint('[AuthWrapper] ⏭️ SKIPPING onboarding (debug mode)');
    }

    // User has completed onboarding - check subscription
    return FutureBuilder<bool>(
      future: SubscriptionService().hasActiveSubscription(
        userEmail: widget.user.email,
      ),
      builder: (context, subscriptionSnapshot) {
        // Show loading while checking subscription
        if (subscriptionSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Check subscription status (includes VIP bypass logic)
        final hasPremium = subscriptionSnapshot.data ?? false;

        if (!hasPremium) {
          // No premium subscription - show paywall
          debugPrint('[AuthWrapper] ⛔ No premium subscription - showing paywall');
          return const StuffritePaywallScreen();
        }

        // User has premium and completed onboarding - go to home
        debugPrint('[AuthWrapper] ✅ Premium subscription active - showing HomeScreen');
        // Use UniqueKey to force new widget instance and prevent state leakage
        return HomeScreenWrapper(key: UniqueKey());
      },
    );
  }

  /// Check if user has completed onboarding
  /// Checks Firebase user profile document for persistence across devices
  /// Falls back to SharedPreferences for backwards compatibility
  Future<bool> _checkOnboardingStatus(String userId) async {
    try {
      // Check Firebase first (cloud-persisted, survives logout/login)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final hasCompleted = data?['hasCompletedOnboarding'] as bool?;
        if (hasCompleted != null) {
          // Cache to SharedPreferences for faster future checks
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('hasCompletedOnboarding_$userId', hasCompleted);
          return hasCompleted;
        }
      }

      // Fallback to SharedPreferences (for backwards compatibility)
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('hasCompletedOnboarding_$userId') ?? false;
    } catch (e) {
      debugPrint('[AuthWrapper] Error checking onboarding status: $e');
      // Fallback to SharedPreferences on error
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('hasCompletedOnboarding_$userId') ?? false;
    }
  }
}
