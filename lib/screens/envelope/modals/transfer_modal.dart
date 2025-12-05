// lib/widgets/transfer_modal.dart
// FONT PROVIDER INTEGRATED: All GoogleFonts.caveat() replaced with FontProvider
// All button text wrapped in FittedBox to prevent wrapping

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // NEW IMPORT
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../../models/envelope.dart';
import '../../../../../services/envelope_repo.dart';
import '../../../../../widgets/calculator_widget.dart';
import '../../../services/localization_service.dart';
import '../../../../../providers/font_provider.dart'; // NEW IMPORT (Matching depth)

class TransferModal extends StatefulWidget {
  const TransferModal({
    super.key,
    required this.repo,
    required this.sourceEnvelopeId,
    required this.sourceEnvelopeName,
    required this.currentAmount,
  });

  final EnvelopeRepo repo;
  final String sourceEnvelopeId;
  final String sourceEnvelopeName;
  final double currentAmount;

  @override
  State<TransferModal> createState() => _TransferModalState();
}

class _TransferModalState extends State<TransferModal> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedTargetEnvelopeId;
  bool _isLoading = false;
  List<Envelope> _availableEnvelopes = [];

  @override
  void initState() {
    super.initState();
    _loadEnvelopes();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadEnvelopes() async {
    // Get all envelopes except the source envelope
    final subscription = widget.repo.envelopesStream().listen((envelopes) {
      if (mounted) {
        setState(() {
          _availableEnvelopes = envelopes
              .where((e) => e.id != widget.sourceEnvelopeId)
              .toList();
        });
      }
    });

    // Clean up subscription when done
    Future.delayed(const Duration(seconds: 1), () => subscription.cancel());
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

  Future<void> _transfer() async {
    if (_selectedTargetEnvelopeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('error_select_target_envelope'))),
      );
      return;
    }

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('error_enter_amount'))));
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('error_invalid_amount'))));
      return;
    }

    if (amount > widget.currentAmount) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('error_insufficient_funds'))));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await widget.repo.transfer(
        fromEnvelopeId: widget.sourceEnvelopeId,
        toEnvelopeId: _selectedTargetEnvelopeId!,
        amount: amount,
        description: _descriptionController.text.trim(),
        date: _selectedDate,
      );

      if (mounted) {
        final targetEnvelope = _availableEnvelopes.firstWhere(
          (e) => e.id == _selectedTargetEnvelopeId,
        );

        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${tr('success_moved')} ${NumberFormat.currency(symbol: '£').format(amount)} ${tr('to')} ${targetEnvelope.name}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${tr('error_generic')}: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

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
                      Icons.swap_horiz,
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
                          tr('action_move_money'),
                          // UPDATED: FontProvider
                          style: fontProvider.getTextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          '${tr('from')}: ${widget.sourceEnvelopeName}',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                    color: theme.colorScheme.primary.withOpacity(0.2),
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
                      '${tr('available')}: ${NumberFormat.currency(symbol: '£').format(widget.currentAmount)}',
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

              // Target envelope picker
              DropdownButtonFormField<String?>(
                value: _selectedTargetEnvelopeId,
                decoration: InputDecoration(
                  labelText: tr('transfer_to_envelope'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.inbox),
                ),
                items: _availableEnvelopes.map((envelope) {
                  return DropdownMenuItem(
                    value: envelope.id,
                    child: Row(
                      children: [
                        if (envelope.emoji != null)
                          Text(
                            envelope.emoji!,
                            style: const TextStyle(fontSize: 20),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            envelope.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTargetEnvelopeId = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              // Amount field with calculator button
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr('amount'),
                  prefixText: '£',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calculate),
                    onPressed: _showCalculator,
                    tooltip: tr('calculator_tooltip'),
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
                  labelText: tr('description_optional'),
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
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Transfer button - FIX: Use theme primary color to match other modals
              ElevatedButton(
                onPressed: _isLoading ? null : _transfer,
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
                    : FittedBox(
                        // UPDATED: FittedBox
                        fit: BoxFit.scaleDown,
                        child: Text(
                          tr('action_move_money'),
                          // UPDATED: FontProvider
                          style: fontProvider.getTextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
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
