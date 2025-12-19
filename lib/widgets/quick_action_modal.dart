// lib/widgets/quick_action_modal.dart
// DEPRECATION FIX: .withOpacity -> .withValues(alpha: )

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // NEW IMPORT
import '../models/envelope.dart';
import '../models/transaction.dart';
import '../services/envelope_repo.dart';
import '../services/workspace_helper.dart';
import '../providers/font_provider.dart'; // NEW IMPORT
import '../utils/calculator_helper.dart';
import '../widgets/partner_badge.dart';

class QuickActionModal extends StatefulWidget {
  const QuickActionModal({
    super.key,
    required this.envelope,
    required this.allEnvelopes,
    required this.repo,
    required this.type,
  });

  final Envelope envelope;
  final List<Envelope> allEnvelopes;
  final EnvelopeRepo repo;
  final TransactionType type;

  @override
  State<QuickActionModal> createState() => _QuickActionModalState();
}

class _QuickActionModalState extends State<QuickActionModal> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedTargetId; // For transfers only
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _showCalculator() async {
    final result = await CalculatorHelper.showCalculator(context);

    if (result != null && mounted) {
      setState(() {
        _amountController.text = result;
      });
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if ((widget.type == TransactionType.withdrawal ||
            widget.type == TransactionType.transfer) &&
        amount > widget.envelope.currentAmount) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Insufficient funds')));
      return;
    }

    if (widget.type == TransactionType.transfer && _selectedTargetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination envelope')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.type == TransactionType.deposit) {
        await widget.repo.deposit(
          envelopeId: widget.envelope.id,
          amount: amount,
          description: _descController.text.trim(),
          date: _selectedDate,
        );
      } else if (widget.type == TransactionType.withdrawal) {
        await widget.repo.withdraw(
          envelopeId: widget.envelope.id,
          amount: amount,
          description: _descController.text.trim(),
          date: _selectedDate,
        );
      } else if (widget.type == TransactionType.transfer) {
        await widget.repo.transfer(
          fromEnvelopeId: widget.envelope.id,
          toEnvelopeId: _selectedTargetId!,
          amount: amount,
          description: _descController.text.trim(),
          date: _selectedDate,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaction successful')));
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
    final isTransfer = widget.type == TransactionType.transfer;
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    String title;
    IconData icon;
    Color color;

    switch (widget.type) {
      case TransactionType.deposit:
        title = 'Add Money';
        icon = Icons.add_circle;
        color = Colors.green;
        break;
      case TransactionType.withdrawal:
        title = 'Spend Money';
        icon = Icons.remove_circle;
        color = Colors.red;
        break;
      case TransactionType.transfer:
        title = 'Move Money';
        icon = Icons.swap_horiz;
        color = Colors.blue;
        break;
    }

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    // UPDATED: FontProvider
                    style: fontProvider.getTextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Balance: ${NumberFormat.currency(symbol: '£').format(widget.envelope.currentAmount)}',
                    style: fontProvider.getTextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withAlpha(179),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Amount
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // UPDATED: FontProvider
            style: fontProvider.getTextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '£',
              suffixIcon: IconButton(
                icon: const Icon(Icons.calculate),
                onPressed: _showCalculator,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            autofocus: true,
          ),

          if (isTransfer) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedTargetId,
              decoration: InputDecoration(
                labelText: 'To Envelope',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: widget.allEnvelopes
                  .where((e) => e.id != widget.envelope.id)
                  .map(
                    (e) {
                      final isPartner = e.userId != widget.repo.currentUserId;
                      return DropdownMenuItem(
                        value: e.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            e.getIconWidget(Theme.of(context), size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                e.name,
                                overflow: TextOverflow.ellipsis,
                                // UPDATED: FontProvider
                                style: fontProvider.getTextStyle(fontSize: 16),
                              ),
                            ),
                            if (isPartner) ...[
                              const SizedBox(width: 8),
                              FutureBuilder<String>(
                                future: WorkspaceHelper.getUserDisplayName(
                                  e.userId,
                                  widget.repo.currentUserId,
                                ),
                                builder: (context, snapshot) {
                                  return PartnerBadge(
                                    partnerName: snapshot.data ?? 'Partner',
                                    size: PartnerBadgeSize.small,
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedTargetId = v),
            ),
          ],

          const SizedBox(height: 16),

          // Description
          TextField(
            controller: _descController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            // UPDATED: FontProvider
            style: fontProvider.getTextStyle(fontSize: 16),
          ),

          const SizedBox(height: 16),

          // Date Picker
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('MMM dd, yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Submit Button
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Confirm',
                    // UPDATED: FontProvider
                    style: fontProvider.getTextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
