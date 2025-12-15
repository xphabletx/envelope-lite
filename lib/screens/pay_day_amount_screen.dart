// lib/screens/pay_day_amount_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/envelope_repo.dart';
import '../services/group_repo.dart';
import '../providers/font_provider.dart';
import 'pay_day_allocation_screen.dart';

class PayDayAmountScreen extends StatefulWidget {
  const PayDayAmountScreen({
    super.key,
    required this.repo,
    required this.groupRepo,
  });

  final EnvelopeRepo repo;
  final GroupRepo groupRepo;

  @override
  State<PayDayAmountScreen> createState() => _PayDayAmountScreenState();
}

class _PayDayAmountScreenState extends State<PayDayAmountScreen> {
  final _amountController = TextEditingController(text: '0.00');
  final _amountFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus and select all when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _amountFocus.requestFocus();
        _amountController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _amountController.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _continue() {
    final rawAmount = _amountController.text.replaceAll(',', '').trim();
    final amount = double.tryParse(rawAmount);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PayDayAllocationScreen(
          repo: widget.repo,
          groupRepo: widget.groupRepo,
          totalAmount: amount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Close',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: media.size.height * 0.1),

              // Money emoji
              const Text(
                '💰',
                style: TextStyle(fontSize: 100),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Pay Day!',
                style: fontProvider.getTextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Subtitle
              Text(
                'How much did you get paid?',
                style: fontProvider.getTextStyle(
                  fontSize: 24,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Amount input
              TextField(
                controller: _amountController,
                focusNode: _amountFocus,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.center,
                style: fontProvider.getTextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
                decoration: InputDecoration(
                  prefixText: '£ ',
                  prefixStyle: fontProvider.getTextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 3,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.secondary,
                      width: 3,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                ),
                onSubmitted: (_) => _continue(),
                onTap: () {
                  // Select all text when tapped
                  _amountController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _amountController.text.length,
                  );
                },
              ),
              const SizedBox(height: 48),

              // Continue button
              FilledButton(
                onPressed: _continue,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: theme.colorScheme.secondary,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: fontProvider.getTextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.arrow_forward,
                      size: 28,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),

              SizedBox(height: media.size.height * 0.1),

              // Optional: Add stats here later
              // TODO: Show last pay day amount and average
            ],
          ),
        ),
      ),
    );
  }
}
