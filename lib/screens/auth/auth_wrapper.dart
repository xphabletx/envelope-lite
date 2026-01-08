import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'email_verification_screen.dart';
import '../sign_in_screen.dart';
import '../onboarding/consolidated_onboarding_flow.dart';
import 'stuffrite_paywall_screen.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/cloud_migration_service.dart';
import '../../providers/workspace_provider.dart';
import '../../widgets/migration_overlay.dart';
import '../../main.dart';

/// Helper class to manage AuthWrapper state across rebuilds
class AuthWrapperState {
  static final Map<String, bool> _initializedUsers = {};
  static final Map<String, GlobalKey<_UserProfileWrapperState>> _userKeys = {};

  /// Get or create a GlobalKey for a user to preserve widget state
  static GlobalKey<_UserProfileWrapperState> getKeyForUser(String userId) {
    return _userKeys.putIfAbsent(
      userId,
      () => GlobalKey<_UserProfileWrapperState>(debugLabel: 'user_$userId'),
    );
  }

  /// Clear initialization state for all users (called during logout)
  static void clearInitializationState() {
    _initializedUsers.clear();
    _userKeys.clear();
  }

  /// Check if user has been initialized
  static bool isInitialized(String userId) {
    return _initializedUsers[userId] == true;
  }

  /// Mark user as initialized
  static void markInitialized(String userId) {
    _initializedUsers[userId] = true;
  }
}

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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
        if (user.isAnonymous) {
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
          return _buildUserProfileWrapper(user);
        }

        // Email/password users need verification check
        if (user.emailVerified) {
          return _buildUserProfileWrapper(user);
        }

        // Check if account is old (grandfather clause)
        final accountCreated = user.metadata.creationTime;
        if (accountCreated == null) {
          // Safety fallback - if we can't determine age, treat as old account
          return _buildUserProfileWrapper(user);
        }

        final now = DateTime.now();
        final accountAge = now.difference(accountCreated).inDays;

        // Accounts older than 7 days = existing users (grandfathered)
        // Let them in but show optional banner
        if (accountAge > 7) {
          return _buildUserProfileWrapper(user);
        }

        // New account (< 7 days old) - REQUIRE verification
        return const EmailVerificationScreen();
      },
    );
  }

  /// Build the user profile wrapper with migration support
  Widget _buildUserProfileWrapper(User user) {
    // Use GlobalKey to preserve widget state across rebuilds
    final key = AuthWrapperState.getKeyForUser(user.uid);
    return _UserProfileWrapper(key: key, user: user);
  }
}

/// Stateful wrapper to handle cloud migration
class _UserProfileWrapper extends StatefulWidget {
  final User user;

  const _UserProfileWrapper({super.key, required this.user});

  @override
  State<_UserProfileWrapper> createState() => _UserProfileWrapperState();
}

class _UserProfileWrapperState extends State<_UserProfileWrapper> {
  final CloudMigrationService _migrationService = CloudMigrationService();
  // Start as true since restoration already happened during splash screen
  bool _restorationComplete = true;
  bool? _hasCompletedOnboarding;
  bool? _hasPremiumSubscription;

  // Cache the onboarding flow widget to prevent recreation on rebuilds
  Widget? _cachedOnboardingFlow;

  @override
  void initState() {
    super.initState();
    // Check onboarding status (restoration and subscription already done during splash)
    _checkOnboardingAndInitialize();
    // Assume premium since subscription was validated during splash
    // If they didn't have premium, they wouldn't have made it this far
    _hasPremiumSubscription = true;
  }

  @override
  void dispose() {
    _migrationService.dispose();
    super.dispose();
  }

  Future<void> _checkOnboardingAndInitialize() async {
    // Prevent re-initialization if already done for this user
    final userId = widget.user.uid;
    if (AuthWrapperState.isInitialized(userId)) {
      // Just check onboarding status - restoration already done during splash
      final completed = await _checkOnboardingStatus(userId);
      if (mounted) {
        setState(() {
          _hasCompletedOnboarding = completed;
        });
      }
      return;
    }
    AuthWrapperState.markInitialized(userId);

    // NOTE: Providers and data restoration are now handled during splash screen
    // in AuthGate._initializeApp() to provide a seamless user experience.
    // We only need to check onboarding status here.

    // Check if user is brand new (first sign-in)
    final creationTime = widget.user.metadata.creationTime;
    final lastSignInTime = widget.user.metadata.lastSignInTime;
    final isBrandNewUser =
        creationTime != null &&
        lastSignInTime != null &&
        lastSignInTime.difference(creationTime).inSeconds < 5;

    if (isBrandNewUser) {
      // Brand new user - skip migration and go straight to onboarding
      // CRITICAL: Clear Hive data if it belongs to a different user
      // BUT: Don't clear onboarding flags - user may have completed offline
      await AuthService.clearHiveIfDifferentUser(widget.user.uid);
    }

    // Check onboarding status (will use "completion wins" logic)
    final completed = await _checkOnboardingStatus(widget.user.uid);

    if (mounted) {
      setState(() {
        _hasCompletedOnboarding = completed;
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

    if (!hasCompletedOnboarding) {
      // New user or hasn't completed onboarding - show onboarding flow
      // Cache the onboarding flow to prevent recreation on theme changes
      _cachedOnboardingFlow ??= ConsolidatedOnboardingFlow(
        key: ValueKey('onboarding_${widget.user.uid}'),
        userId: widget.user.uid,
      );
      return _cachedOnboardingFlow!;
    }

    // User has completed onboarding - check subscription
    // Subscription was pre-checked during splash, so we optimistically show home
    if (_hasPremiumSubscription == false) {
      // Only show paywall if we have confirmed NO premium
      return const StuffritePaywallScreen();
    }

    // User has premium (or check in progress) - show home
    // Use stable key based on user ID
    return HomeScreenWrapper(key: ValueKey('home_${widget.user.uid}'));
  }

  /// Check if user has completed onboarding
  /// Check onboarding completion with "completion wins" conflict resolution
  /// If EITHER local or cloud says completed, trust it and sync both
  Future<bool> _checkOnboardingStatus(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Check local first (instant, works offline)
      final localCompleted = prefs.getBool('hasCompletedOnboarding_$userId') ?? false;

      // 2. Try to check Firestore (requires network)
      bool? cloudCompleted;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data();
          cloudCompleted = data?['hasCompletedOnboarding'] as bool?;
        }
      } catch (e) {
        debugPrint('[AuthWrapper] Firestore check failed (offline?): $e');
        // Continue with local value only
      }

      // 3. CONFLICT RESOLUTION: "Completion wins"
      // If EITHER says completed, both should say completed
      if (localCompleted == true || cloudCompleted == true) {
        // Sync both to completed
        if (!localCompleted) {
          debugPrint('[AuthWrapper] 🔄 Cloud says completed, syncing to local');
          await prefs.setBool('hasCompletedOnboarding_$userId', true);
        }

        if (cloudCompleted != true) {
          debugPrint('[AuthWrapper] 🔄 Local says completed, syncing to cloud');
          // Fire-and-forget sync (don't block UI)
          UserService(FirebaseFirestore.instance, userId)
              .updateUserProfile(hasCompletedOnboarding: true)
              .catchError((e) {
            debugPrint('[AuthWrapper] ⚠️ Cloud sync failed (offline?): $e');
          });
        }

        return true;
      }

      // 4. Both say incomplete (or no data)
      return false;
    } catch (e) {
      debugPrint('[AuthWrapper] Error checking onboarding status: $e');
      // Fallback to local only
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('hasCompletedOnboarding_$userId') ?? false;
    }
  }
}
