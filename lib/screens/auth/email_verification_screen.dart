import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

/// Email Verification Screen
///
/// Shown to NEW email/password users who need to verify their email before accessing the app.
/// Features:
/// - Auto-checks verification status every 3 seconds
/// - Resend email button with 60-second cooldown
/// - Manual "I've Verified" button
/// - Sign out option
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({Key? key}) : super(key: key);

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isResendingEmail = false;
  bool _isCheckingVerification = false;
  Timer? _timer;
  int _secondsUntilResend = 0;

  @override
  void initState() {
    super.initState();
    // Don't auto-check - causes continuous rebuilds in AuthWrapper
    // User can manually check with "I've Verified" button
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    if (_isCheckingVerification) return;

    setState(() => _isCheckingVerification = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isCheckingVerification = false);
        return;
      }

      // Reload user to get latest emailVerified status
      await user.reload();

      // Get fresh user instance after reload
      final updatedUser = FirebaseAuth.instance.currentUser;

      if (updatedUser?.emailVerified ?? false) {
        debugPrint('[EmailVerification] ✅ Email verified!');

        // Cancel timer when verified
        _timer?.cancel();

        // Don't manually navigate - let AuthWrapper's authStateChanges handle it
        // The reload above will trigger authStateChanges which will route correctly
      }
    } catch (e) {
      debugPrint('[EmailVerification] Error checking verification: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingVerification = false);
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_secondsUntilResend > 0) return;

    setState(() => _isResendingEmail = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();

      debugPrint('[EmailVerification] ✅ Verification email resent');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Verification email sent! Check your inbox.')),
        );

        // Start 60 second countdown
        setState(() => _secondsUntilResend = 60);
        Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_secondsUntilResend > 0) {
            if (mounted) {
              setState(() => _secondsUntilResend--);
            }
          } else {
            timer.cancel();
          }
        });
      }
    } catch (e) {
      debugPrint('[EmailVerification] ❌ Error resending email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResendingEmail = false);
      }
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              const SizedBox(height: 48),
              // Email icon
              Icon(
                Icons.mark_email_unread_outlined,
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Verify Your Email',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Instruction text
              Text(
                'We sent a verification link to:',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Email address
              Text(
                email,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Instructions
              const Text(
                '1. Check your email inbox AND spam/junk folder\n'
                '2. Click the verification link\n'
                '3. Return to this app',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Checking status
              if (_isCheckingVerification)
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Checking verification status...'),
                  ],
                ),

              const SizedBox(height: 24),

              // Resend button
              FilledButton.icon(
                onPressed: _secondsUntilResend > 0 || _isResendingEmail
                    ? null
                    : _resendVerificationEmail,
                icon: _isResendingEmail
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  _secondsUntilResend > 0
                      ? 'Resend in $_secondsUntilResend seconds'
                      : 'Resend Email',
                ),
              ),

              const SizedBox(height: 16),

              // Manual check button
              OutlinedButton.icon(
                onPressed: _isCheckingVerification ? null : _checkEmailVerified,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('I\'ve Verified'),
              ),

              const SizedBox(height: 32),

              // Help text
              Text(
                'Didn\'t receive the email?\nCheck your spam/junk folder first,\nthen tap "Resend Email"',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
