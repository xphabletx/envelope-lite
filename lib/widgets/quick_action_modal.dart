// lib/widgets/quick_action_modal.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/envelope.dart';
import '../models/transaction.dart';
import '../services/envelope_repo.dart';
import './calculator_widget.dart';

class QuickActionModal extends StatefulWidget {
  final Envelope envelope;
  final TransactionType type;
  final List<Envelope> allEnvelopes;
  final EnvelopeRepo repo;

  const QuickActionModal({
    super.key,
    required this.envelope,
    required this.type,
    required this.allEnvelopes,
    required this.repo,
  });

  @override
  State<QuickActionModal> createState() => _QuickActionModalState();
}

class _QuickActionModalState extends State<QuickActionModal> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  Envelope? _target;
  bool _loading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _fetchUserNamesForEnvelopes(
    List<Envelope> envelopes,
  ) async {
    final Map<String, String> userNames = {};
    final uniqueUserIds = envelopes.map((e) => e.userId).toSet();

    for (final userId in uniqueUserIds) {
      userNames[userId] = await widget.repo.getUserDisplayName(userId);
    }

    return userNames;
  }

  String get _title => switch (widget.type) {
    TransactionType.deposit => 'Add Money',
    TransactionType.withdrawal => 'Take Money',
    TransactionType.transfer => 'Move Money',
  };

  String get _subtitle => switch (widget.type) {
    TransactionType.deposit => widget.envelope.name,
    TransactionType.withdrawal => widget.envelope.name,
    TransactionType.transfer => 'From: ${widget.envelope.name}',
  };

  IconData get _icon => switch (widget.type) {
    TransactionType.deposit => Icons.add_circle,
    TransactionType.withdrawal => Icons.remove_circle,
    TransactionType.transfer => Icons.swap_horiz,
  };

  String get _buttonText => switch (widget.type) {
    TransactionType.deposit => 'Add Money',
    TransactionType.withdrawal => 'Take Money',
    TransactionType.transfer => 'Move Money',
  };

  bool get _isOwner => widget.envelope.userId == widget.repo.currentUserId;

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

  Future<void> _submit() async {
    // Check ownership for non-transfer actions
    if (widget.type != TransactionType.transfer && !_isOwner) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the owner can perform this action.'),
        ),
      );
      return;
    }

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an amount')));
      return;
    }

    final a = double.tryParse(amountText);
    if (a == null || a <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (widget.type == TransactionType.transfer && _target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a target envelope')),
      );
      return;
    }

    if ((widget.type == TransactionType.withdrawal ||
            widget.type == TransactionType.transfer) &&
        a > widget.envelope.currentAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient funds in envelope')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      switch (widget.type) {
        case TransactionType.deposit:
          await widget.repo.deposit(
            envelopeId: widget.envelope.id,
            amount: a,
            description: _descriptionController.text.trim(),
            date: _selectedDate,
          );
          break;

        case TransactionType.withdrawal:
          await widget.repo.withdraw(
            envelopeId: widget.envelope.id,
            amount: a,
            description: _descriptionController.text.trim(),
            date: _selectedDate,
          );
          break;

        case TransactionType.transfer:
          await widget.repo.transfer(
            fromEnvelopeId: widget.envelope.id,
            toEnvelopeId: _target!.id,
            amount: a,
            description: _descriptionController.text.trim(),
            date: _selectedDate,
          );
          break;
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.type == TransactionType.transfer
                  ? 'Moved ${NumberFormat.currency(symbol: '£').format(a)} to ${_target!.name}'
                  : widget.type == TransactionType.deposit
                  ? 'Added ${NumberFormat.currency(symbol: '£').format(a)}'
                  : 'Removed ${NumberFormat.currency(symbol: '£').format(a)}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAct = _isOwner || widget.type == TransactionType.transfer;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
              // Header with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _icon,
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
                          _title,
                          style: GoogleFonts.caveat(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          _subtitle,
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

              // Warning banner if not owner
              if (!canAct) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Only the owner can perform this action.',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Available balance for withdraw/transfer
              if (widget.type == TransactionType.withdrawal ||
                  widget.type == TransactionType.transfer) ...[
                const SizedBox(height: 16),
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
                        'Available: ${NumberFormat.currency(symbol: '£').format(widget.envelope.currentAmount)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                const SizedBox(height: 24),

              const SizedBox(height: 16),

              // Target envelope picker for transfer
              if (widget.type == TransactionType.transfer) ...[
                FutureBuilder<Map<String, String>>(
                  future: _fetchUserNamesForEnvelopes(widget.allEnvelopes),
                  builder: (context, snapshot) {
                    final userNames = snapshot.data ?? {};

                    return DropdownButtonFormField<Envelope>(
                      value: _target,
                      decoration: InputDecoration(
                        labelText: 'To Envelope',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.inbox),
                      ),
                      items: widget.allEnvelopes
                          .where((e) => e.id != widget.envelope.id)
                          .map((e) {
                            final isMyEnvelope =
                                e.userId == widget.repo.currentUserId;
                            final ownerName = userNames[e.userId] ?? 'Unknown';
                            final displayText = isMyEnvelope
                                ? e.name
                                : '$ownerName - ${e.name}';

                            return DropdownMenuItem(
                              value: e,
                              child: Row(
                                children: [
                                  if (e.emoji != null)
                                    Text(
                                      e.emoji!,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      displayText,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })
                          .toList(),
                      onChanged: canAct
                          ? (v) => setState(() => _target = v)
                          : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Amount field with calculator button
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                enabled: canAct,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '£',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calculate),
                    onPressed: canAct ? _showCalculator : null,
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
                enabled: canAct,
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
                onTap: canAct ? _selectDate : null,
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

              // Action button
              ElevatedButton(
                onPressed: (canAct && !_loading) ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
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
                        _buttonText,
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
