import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Verification Banner Widget
///
/// Shows a dismissible banner at the top of the home screen for existing users
/// with unverified email/password accounts.
///
/// Features:
/// - Orange info banner (non-blocking)
/// - "Verify" button to send verification email
/// - Dismissible (X button)
/// - Auto-hides after sending email
class VerificationBanner extends StatefulWidget {
  const VerificationBanner({super.key});

  @override
  State<VerificationBanner> createState() => _VerificationBannerState();
}

class _VerificationBannerState extends State<VerificationBanner> {
  bool _isDismissed = false;
  bool _isSending = false;

  Future<void> _sendVerificationEmail() async {
    setState(() => _isSending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Verification email sent! Check your inbox.'),
          ),
        );

        // Dismiss banner after sending
        setState(() => _isDismissed = true);
      }
    } catch (e) {
      debugPrint('[VerificationBanner] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending email: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    return Container(
      color: Colors.orange.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade900),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Verify your email to secure your account',
              style: TextStyle(color: Colors.orange.shade900),
            ),
          ),
          if (_isSending)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: _sendVerificationEmail,
              child: const Text('Verify'),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => setState(() => _isDismissed = true),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
