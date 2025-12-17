import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../../services/envelope_repo.dart';
import '../../../../../widgets/calculator_widget.dart';

class WithdrawModal extends StatefulWidget {
  const WithdrawModal({
    super.key,
    required this.repo,
    required this.envelopeId,
    required this.envelopeName,
    required this.currentAmount,
  });

  final EnvelopeRepo repo;
  final String envelopeId;
  final String envelopeName;
  final double currentAmount;

  @override
  State<WithdrawModal> createState() => _WithdrawModalState();
}

class _WithdrawModalState extends State<WithdrawModal> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showCalculator() async {
    final result = await showDialog<double>(
      context: context,
      builder: (context) => const Dialog(child: CalculatorWidget()),
    );

    if (result != null && mounted) {
      setState(() {
        _amountController.text = result.toStringAsFixed(2);
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _withdraw() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an amount')));
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (amount > widget.currentAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient funds in envelope')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await widget.repo.withdraw(
        envelopeId: widget.envelopeId,
        amount: amount,
        description: _descriptionController.text.trim(),
        date: _selectedDate,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Removed ${NumberFormat.currency(symbol: '£').format(amount)}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header - FIX: Use theme colors
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.remove_circle,
                      color: theme.colorScheme.onPrimary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Take Money',
                          style: GoogleFonts.caveat(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          widget.envelopeName,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Available balance
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Available: ${NumberFormat.currency(symbol: '£').format(widget.currentAmount)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Amount field with calculator button
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '£',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calculate),
                    onPressed: _showCalculator,
                    tooltip: 'Open Calculator',
                  ),
                ),
                autofocus: true,
              ),

              const SizedBox(height: 16),

              // Description field
              TextField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Date picker
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('MMM dd, yyyy').format(_selectedDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_drop_down,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Withdraw button - FIX: Use theme colors
              ElevatedButton(
                onPressed: _isLoading ? null : _withdraw,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : Text(
                        'Take Money',
                        style: GoogleFonts.caveat(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
