import 'package:flutter/material.dart';
import '../../../providers/font_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../widgets/common/smart_text_field.dart';
import '../../../utils/calculator_helper.dart';
import '../horizon_controller.dart';

class HorizonControlPanel extends StatefulWidget {
  final HorizonController controller;
  final FontProvider fontProvider;
  final LocaleProvider locale;

  const HorizonControlPanel({
    super.key,
    required this.controller,
    required this.fontProvider,
    required this.locale,
  });

  @override
  State<HorizonControlPanel> createState() => _HorizonControlPanelState();
}

class _HorizonControlPanelState extends State<HorizonControlPanel> {
  final TextEditingController _totalController = TextEditingController();
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    // Initialize text field with baseline total
    final total = widget.controller.envelopeBaselines.values.fold(
      0.0,
      (a, b) => a + b,
    );
    if (total > 0) {
      _totalController.text = total.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _totalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalBaseline = widget.controller.envelopeBaselines.values.fold(
      0.0,
      (a, b) => a + b,
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (val) => setState(() => _isExpanded = val),
        title: Text(
          'Strategy Controls',
          style: widget.fontProvider.getTextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Icon(Icons.speed, color: theme.colorScheme.primary),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFundsBreakdown(theme),
                const SizedBox(height: 20),
                _buildVelocitySection(theme, totalBaseline),
                const SizedBox(height: 24),
                _buildTotalInputField(theme),
                const SizedBox(height: 16),
                _buildCommitButton(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFundsBreakdown(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _fundRow('Account Balance', widget.controller.accountBalance, theme),
          _fundRow(
            'Cashflow Reserved',
            -widget.controller.cashflowReserve,
            theme,
            isNeg: true,
          ),
          _fundRow(
            'Autopilot (Bills)',
            -widget.controller.autopilotCoverage,
            theme,
            isNeg: true,
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available to Assign',
                style: widget.fontProvider.getTextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.locale.formatCurrency(
                  widget.controller.availableForBoost,
                ),
                style: widget.fontProvider.getTextStyle(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVelocitySection(ThemeData theme, double baseline) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Strategy Velocity',
          style: widget.fontProvider.getTextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Slider(
          value: widget.controller.velocityPercentage,
          min: -100,
          max: 100,
          divisions: 20,
          label: '${widget.controller.velocityPercentage.round()}%',
          onChanged: (val) {
            widget.controller.applyVelocityAdjustment(val);
            final newTotal = baseline * (1 + (val / 100));
            _totalController.text = newTotal.toStringAsFixed(2);
          },
        ),
        Center(
          child: Text(
            widget.controller.velocityPercentage == 0
                ? 'Baseline Strategy'
                : '${widget.controller.velocityPercentage > 0 ? '+' : ''}${widget.controller.velocityPercentage.round()}% Speed',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalInputField(ThemeData theme) {
    return SmartTextField(
      controller: _totalController,
      decoration: InputDecoration(
        labelText: 'Monthly Contribution Total',
        prefixText: '${widget.locale.currencySymbol} ',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: IconButton(
          icon: const Icon(Icons.calculate),
          onPressed: () async {
            final res = await CalculatorHelper.showCalculator(context);
            if (res != null) {
              _totalController.text = res;
              // Update velocity slider based on new manual total
              // (Logic for this would be added to the controller)
            }
          },
        ),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (val) {
        // Handle manual override
      },
    );
  }

  Widget _buildCommitButton(ThemeData theme) {
    return FilledButton.icon(
      onPressed: () {
        // Logic to save these values back to the EnvelopeRepo
      },
      icon: const Icon(Icons.bolt),
      label: const Text('Update Strategy'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: theme.colorScheme.secondary,
      ),
    );
  }

  Widget _fundRow(
    String label,
    double amt,
    ThemeData theme, {
    bool isNeg = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            widget.locale.formatCurrency(amt),
            style: TextStyle(
              fontSize: 12,
              color: isNeg ? theme.colorScheme.error : null,
            ),
          ),
        ],
      ),
    );
  }
}
