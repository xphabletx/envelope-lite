// lib/screens/sign_in_screen.dart
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/tutorial_controller.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _obscurePassword = true; // Password visibility toggle

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _withGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? 'Authentication error.';
      setState(() => _error = msg);
      _showSnack(msg);
    } catch (e) {
      final msg = e.toString();
      setState(() => _error = msg);
      _showSnack(msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withApple() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.signInWithApple();
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? 'Authentication error.';
      setState(() => _error = msg);
      _showSnack(msg);
    } catch (e) {
      final msg = e.toString();
      setState(() => _error = msg);
      _showSnack(msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInEmail() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    if (email.isEmpty || pass.isEmpty) {
      const msg = 'Email and password required';
      setState(() => _error = msg);
      _showSnack(msg);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await AuthService.signInWithEmail(email: email, password: pass);
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          // Unified message for security (don't reveal which part failed)
          msg = 'Account not found or invalid credentials';
          break;
        case 'user-disabled':
          msg = 'This account has been disabled';
          break;
        case 'invalid-email':
          msg = 'Invalid email format';
          break;
        case 'too-many-requests':
          msg = 'Too many failed attempts. Please try again later';
          break;
        default:
          msg = e.message ?? 'Authentication error';
      }
      setState(() => _error = msg);
      _showSnack(msg);
    } catch (e) {
      final msg = e.toString();
      setState(() => _error = msg);
      _showSnack(msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      const msg = 'Enter your email to reset password';
      setState(() => _error = msg);
      _showSnack(msg);
      return;
    }
    try {
      await AuthService.sendPasswordReset(email);
      _showSnack('Password reset email sent');
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Failed to send reset email');
    }
  }

  // ---- CREATE ACCOUNT BOTTOM SHEET (FIXED UI) ----
  Future<void> _openCreateAccountSheet() async {
    final formKey = GlobalKey<FormState>();
    final emailCtrl = TextEditingController(text: _email.text.trim());
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    String? sheetError;
    bool sheetBusy = false;
    bool obscurePass = true;
    bool obscureConfirm = true;

    String? emailValidator(String? v) {
      final val = (v ?? '').trim();
      if (val.isEmpty) return 'Email required';
      final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(val);
      if (!ok) return 'Enter a valid email';
      return null;
    }

    String? passValidator(String? v) {
      if ((v ?? '').isEmpty) return 'Password required';
      if ((v ?? '').length < 6) return 'Min 6 characters';
      return null;
    }

    String? confirmValidator(String? v) {
      if ((v ?? '').isEmpty) return 'Confirm your password';
      if (v != passCtrl.text) return 'Passwords do not match';
      return null;
    }

    if (!mounted) return;

    // Define a clean, light theme for the modal specifically
    final modalTheme = ThemeData(
      brightness: Brightness.light,
      primaryColor: const Color(0xFF6D4C41), // Brownish
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6D4C41),
        surface: const Color(0xFFFFFBF5), // Warm white
        onSurface: Colors.black87,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6D4C41), width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.black54),
        hintStyle: const TextStyle(color: Colors.black38),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // Enforce the light theme for the modal content
        return Theme(
          data: modalTheme,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFFFBF5), // Warm neutral background
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: StatefulBuilder(
                    builder: (ctx2, setSheet) {
                      Future<void> onCreate() async {
                        if (!formKey.currentState!.validate()) return;
                        setSheet(() {
                          sheetError = null;
                          sheetBusy = true;
                        });
                        try {
                          final email = emailCtrl.text.trim();
                          await AuthService.createWithEmail(
                            email: email,
                            password: passCtrl.text,
                            displayName: null,
                          );

                          // IMPORTANT: Reset tutorial state for new users
                          // This ensures the tutorial runs when they hit home
                          if (mounted) {
                            await TutorialController.resetAll();
                          }

                          if (!ctx2.mounted) return;
                          Navigator.of(ctx2).pop();

                          // Show verification email dialog
                          if (ctx2.mounted) {
                            showDialog(
                              context: ctx2,
                              barrierDismissible: false,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Check Your Email'),
                                content: Text(
                                  'We sent a verification link to $email\n\n'
                                  'Please check your inbox and click the link to verify your account.',
                                ),
                                actions: [
                                  FilledButton(
                                    onPressed: () {
                                      Navigator.pop(dialogContext);
                                      // AuthWrapper will automatically handle showing
                                      // the verification screen
                                    },
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          }
                        } on FirebaseAuthException catch (e) {
                          switch (e.code) {
                            case 'email-already-in-use':
                              sheetError = 'That email is already in use.';
                              break;
                            case 'invalid-email':
                              sheetError = 'Invalid email format.';
                              break;
                            case 'operation-not-allowed':
                              sheetError =
                                  'Email/password sign-up is disabled.';
                              break;
                            case 'weak-password':
                              sheetError = 'Password is too weak.';
                              break;
                            default:
                              sheetError = e.message ?? 'Sign-up error.';
                          }
                          setSheet(() {});
                        } catch (e) {
                          sheetError = e.toString();
                          setSheet(() {});
                        } finally {
                          setSheet(() => sheetBusy = false);
                        }
                      }

                      return SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: modalTheme.colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start your journey with Envelope Lite',
                              style: TextStyle(
                                fontSize: 16,
                                color: modalTheme.colorScheme.onSurface
                                    .withValues(alpha:0.6),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            Form(
                              key: formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    textCapitalization: TextCapitalization.none,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                    ),
                                    validator: emailValidator,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: passCtrl,
                                    obscureText: obscurePass,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          obscurePass
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.grey,
                                        ),
                                        onPressed: () {
                                          setSheet(
                                            () => obscurePass = !obscurePass,
                                          );
                                        },
                                      ),
                                    ),
                                    validator: passValidator,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: confirmCtrl,
                                    obscureText: obscureConfirm,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Confirm Password',
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          obscureConfirm
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.grey,
                                        ),
                                        onPressed: () {
                                          setSheet(
                                            () => obscureConfirm =
                                                !obscureConfirm,
                                          );
                                        },
                                      ),
                                    ),
                                    validator: confirmValidator,
                                    onFieldSubmitted: (_) => onCreate(),
                                  ),
                                ],
                              ),
                            ),
                            if (sheetError != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha:0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha:0.3),
                                  ),
                                ),
                                child: Text(
                                  sheetError!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),
                            SizedBox(
                              height: 52,
                              child: FilledButton(
                                onPressed: sheetBusy ? null : onCreate,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF6D4C41),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: sheetBusy
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Create Account',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _busy;

    // Get the app's current theme but override font to system default
    final appTheme = Theme.of(context);
    final signInTheme = appTheme.copyWith(
      textTheme: appTheme.textTheme.apply(
        fontFamily: null, // Force system default
        bodyColor: appTheme.colorScheme.onSurface,
        displayColor: appTheme.colorScheme.onSurface,
      ),
      inputDecorationTheme: appTheme.inputDecorationTheme.copyWith(
        labelStyle: TextStyle(
          fontSize: 18,
          fontFamily: null,
          color: appTheme.colorScheme.onSurface,
        ),
        hintStyle: TextStyle(
          fontSize: 18,
          fontFamily: null,
          color: appTheme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );

    return Theme(
      data: signInTheme,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: FittedBox(
            child: Text(
              'Sign in',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                fontFamily: null, // System default
                color: appTheme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                  fontFamily: null,
                                ),
                              ),
                            ),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textCapitalization: TextCapitalization.none,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              fontSize: 18,
                              fontFamily: null,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              labelStyle: TextStyle(
                                fontSize: 18,
                                fontFamily: null,
                              ),
                            ),
                            onSubmitted: (_) =>
                                FocusScope.of(context).nextFocus(),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _pass,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(
                              fontSize: 18,
                              fontFamily: null,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: const TextStyle(
                                fontSize: 18,
                                fontFamily: null,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 24,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            onSubmitted: (_) => _signInEmail(),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: busy ? null : _forgotPassword,
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontFamily: null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: busy ? null : _signInEmail,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(
                                      0,
                                      56,
                                    ), // Increased from 52
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: const Text(
                                      'Sign in',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontFamily: null,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: busy
                                      ? null
                                      : _openCreateAccountSheet,
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(
                                      0,
                                      56,
                                    ), // Increased from 52
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: const Text(
                                      'Create account',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontFamily: null,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: appTheme.colorScheme.onSurface
                                      .withValues(alpha: 0.3),
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: appTheme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: null,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: appTheme.colorScheme.onSurface
                                      .withValues(alpha: 0.3),
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 56, // Increased from 52
                            child: OutlinedButton.icon(
                              icon: Icon(
                                Icons.g_mobiledata,
                                size: 32,
                                color: appTheme.colorScheme.onSurface,
                              ),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: const Text(
                                  'Continue with Google',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontFamily: null,
                                  ),
                                ),
                              ),
                              onPressed: busy ? null : _withGoogle,
                            ),
                          ),
                          // Only show Apple Sign-In on iOS (not required for Android)
                          if (Platform.isIOS) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 56,
                              child: FilledButton.icon(
                                icon: const Icon(
                                  Icons.apple,
                                  size: 28,
                                  color: Color(0xFFF8FAF6),
                                ),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: const Text(
                                    'Continue with Apple',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontFamily: null,
                                    ),
                                  ),
                                ),
                                onPressed: busy ? null : _withApple,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF5D4A2F),
                                  foregroundColor: const Color(0xFFF8FAF6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
