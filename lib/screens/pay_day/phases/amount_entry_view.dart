// lib/screens/pay_day/phases/amount_entry_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/pay_day_cockpit_provider.dart';
import '../../../providers/font_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../widgets/common/smart_text_field.dart';
import '../../../utils/calculator_helper.dart';

class AmountEntryView extends StatefulWidget {
  const AmountEntryView({super.key});

  @override
  State<AmountEntryView> createState() => _AmountEntryViewState();
}

class _AmountEntryViewState extends State<AmountEntryView> {
  final TextEditingController _amountController = TextEditingController(
    text: '0.00',
  );
  final FocusNode _amountFocus = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PayDayCockpitProvider>();
      if (provider.externalInflow > 0) {
        setState(() {
          _amountController.text = provider.externalInflow.toStringAsFixed(2);
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    // Debounce the updates (50ms as specified)
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      final amount = double.tryParse(value.replaceAll(',', '')) ?? 0.0;
      context.read<PayDayCockpitProvider>().updateExternalInflow(amount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PayDayCockpitProvider>();
    final theme = Theme.of(context);
    final fontProvider = context.read<FontProvider>();
    final locale = context.read<LocaleProvider>();
    final media = MediaQuery.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: media.size.height * 0.05),

            // Money icon "Outside the Wall"
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade300, width: 3),
              ),
              child: Column(
                children: [
                  const Text(
                    '💰',
                    style: TextStyle(fontSize: 100),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Make it rain',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Title
            Text(
              'External Inflow',
              style: fontProvider.getTextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              provider.isAccountMode
                  ? 'Money arriving to ${provider.defaultAccount?.name ?? 'your account'}'
                  : 'Money arriving to the Horizon Pool',
              style: fontProvider.getTextStyle(
                fontSize: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 48),

            // Amount input with FittedBox
            SizedBox(
              height: 120,
              child: FittedBox(
                fit: BoxFit.contain,
                child: IntrinsicWidth(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 200,
                      maxWidth: 600,
                    ),
                    child: SmartTextField(
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
                      onChanged: _onAmountChanged,
                      decoration: InputDecoration(
                        prefixText: '${locale.currencySymbol} ',
                        prefixStyle: fontProvider.getTextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                        ),
                        suffixIcon: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.calculate,
                              color: theme.colorScheme.onPrimary,
                            ),
                            onPressed: () async {
                              final result =
                                  await CalculatorHelper.showCalculator(
                                    context,
                                  );
                              if (result != null && mounted) {
                                setState(() {
                                  _amountController.text = result;
                                  _onAmountChanged(result);
                                });
                              }
                            },
                            tooltip: 'Open Calculator',
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 3,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                      ),
                      onTap: () {
                        _amountController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _amountController.text.length,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 48),

            // Mode indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    provider.isAccountMode
                        ? Icons.account_balance
                        : Icons.wallet,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      provider.isAccountMode
                          ? 'Account Mode: Money flows to ${provider.defaultAccount?.name ?? 'account'}, then to envelopes'
                          : 'Simple Mode: Money flows directly to Horizon Pool',
                      style: fontProvider.getTextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // Continue button
            FilledButton(
              onPressed: () => provider.proceedToStrategyReview(),
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
                  Flexible(
                    child: Text(
                      'Review Strategy',
                      style: fontProvider.getTextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
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

            if (provider.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Text(
                  provider.error!,
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
