// lib/screens/onboarding/onboarding_account_setup.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/account_repo.dart';
import '../../services/envelope_repo.dart';
import '../../providers/font_provider.dart';

class OnboardingAccountSetup extends StatefulWidget {
  const OnboardingAccountSetup({super.key, required this.envelopeRepo});

  final EnvelopeRepo envelopeRepo;

  @override
  State<OnboardingAccountSetup> createState() => _OnboardingAccountSetupState();
}

class _OnboardingAccountSetupState extends State<OnboardingAccountSetup> {
  final _nameController = TextEditingController(text: 'Main Account');
  final _balanceController = TextEditingController(text: '0.00');
  final _payAmountController = TextEditingController(text: '0.00');

  String _payFrequency = 'monthly';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _payAmountController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (_saving) return;

    final balance = double.tryParse(_balanceController.text);
    final payAmount = double.tryParse(_payAmountController.text);

    if (balance == null || balance < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid balance')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // FIXED: Pass EnvelopeRepo, not String
      final accountRepo = AccountRepo(
        widget.envelopeRepo.db,
        widget.envelopeRepo,
      );

      // Create account
      await accountRepo.createAccount(
        name: _nameController.text.trim(),
        startingBalance: balance,
        emoji: '💳',
        isDefault: true,
      );

      // Save pay day settings if provided
      if (payAmount != null && payAmount > 0) {
        final userId = widget.envelopeRepo.currentUserId;
        await widget.envelopeRepo.db
            .collection('users')
            .doc(userId)
            .collection('payDaySettings')
            .doc('settings')
            .set({
              'userId': userId,
              'lastPayAmount': payAmount,
              'payFrequency': _payFrequency,
              'payDayOfMonth': 1,
              'lastPayDate': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
            });
      }

      if (mounted) {
        // Navigate to main app
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Header
              const Text('💳', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(
                'Set up your account',
                style: fontProvider.getTextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Track your money by linking your bank account',
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),

              const SizedBox(height: 40),

              // Account name
              Text(
                'Account Name',
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: fontProvider.getTextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Main Account',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Starting balance
              Text(
                'Current Balance',
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _balanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: fontProvider.getTextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixText: '£ ',
                  prefixStyle: fontProvider.getTextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onTap: () {
                  _balanceController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _balanceController.text.length,
                  );
                },
              ),

              const SizedBox(height: 40),

              // Divider
              Divider(color: theme.colorScheme.outline),
              const SizedBox(height: 24),

              // Optional: Pay Day info
              Text(
                'Pay Day Info (Optional)',
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Help us predict your future balances',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),

              // Pay amount
              TextField(
                controller: _payAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: fontProvider.getTextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: 'How much do you get paid?',
                  hintText: '0.00',
                  prefixText: '£ ',
                  prefixStyle: fontProvider.getTextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Pay frequency
              DropdownButtonFormField<String>(
                initialValue: _payFrequency,
                decoration: InputDecoration(
                  labelText: 'How often?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'weekly',
                    child: Text(
                      'Weekly',
                      style: fontProvider.getTextStyle(fontSize: 18),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'biweekly',
                    child: Text(
                      'Biweekly',
                      style: fontProvider.getTextStyle(fontSize: 18),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'monthly',
                    child: Text(
                      'Monthly',
                      style: fontProvider.getTextStyle(fontSize: 18),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _payFrequency = value);
                  }
                },
              ),

              const SizedBox(height: 40),

              // Complete button
              FilledButton(
                onPressed: _saving ? null : _complete,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Get Started',
                        style: fontProvider.getTextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),

              const SizedBox(height: 16),

              // Skip button
              TextButton(
                onPressed: () {
                  // Skip and go to main app
                  Navigator.pushReplacementNamed(context, '/home');
                },
                child: Text(
                  'Skip for now',
                  style: fontProvider.getTextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
