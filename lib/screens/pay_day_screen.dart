import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/envelope.dart';
import '../models/transaction.dart';
import '../services/envelope_repo.dart';

class PayDayScreen extends StatefulWidget {
  const PayDayScreen({super.key, required this.repo});

  final EnvelopeRepo repo;

  @override
  State<PayDayScreen> createState() => _PayDayScreenState();
}

class _PayDayScreenState extends State<PayDayScreen> {
  final _amountCtrl = TextEditingController();
  final _amountFocus = FocusNode();
  bool _processing = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _processPayDay(
    List<Envelope> autoFillEnvelopes,
    double totalAmount,
  ) async {
    setState(() => _processing = true);

    try {
      // Process each auto-fill envelope
      for (final envelope in autoFillEnvelopes) {
        if (envelope.autoFillAmount != null && envelope.autoFillAmount! > 0) {
          // Create a new envelope with updated balance
          final updatedEnvelope = envelope.copyWith(
            currentAmount: envelope.currentAmount + envelope.autoFillAmount!,
          );

          // Create transaction
          final tx = Transaction(
            id: '', // Will be set by Firestore
            envelopeId: envelope.id,
            type: TransactionType.deposit,
            amount: envelope.autoFillAmount!,
            date: DateTime.now(),
            description: 'Pay Day Auto-Fill',
            userId: widget.repo.currentUserId,
          );

          // Record it
          await widget.repo.recordTransaction(tx, from: updatedEnvelope);
        }
      }

      if (!mounted) return;

      // Show success with confetti
      await _showSuccessDialog(autoFillEnvelopes);

      // Clear amount and go back
      _amountCtrl.clear();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error processing Pay Day: $e')));
    }
  }

  Future<void> _showSuccessDialog(List<Envelope> filled) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PayDaySuccessDialog(envelopesFilled: filled.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(symbol: '£');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<Envelope>>(
        stream: widget.repo.envelopesStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allEnvelopes = snapshot.data!;
          final autoFillEnvelopes = allEnvelopes
              .where((e) => e.autoFillEnabled && e.autoFillAmount != null)
              .toList();

          // Calculate totals
          final totalAutoFill = autoFillEnvelopes.fold<double>(
            0.0,
            (sum, e) => sum + (e.autoFillAmount ?? 0.0),
          );

          final userAmount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
          final remaining = userAmount - totalAutoFill;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      Text('💰', style: const TextStyle(fontSize: 64)),
                      const SizedBox(height: 8),
                      Text(
                        'Pay Day!',
                        style: GoogleFonts.caveat(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Allocate your earnings to envelopes',
                        style: GoogleFonts.caveat(
                          fontSize: 20,
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurface.withAlpha(179),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Total Amount Input
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.secondary.withAlpha(77),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Amount',
                        style: GoogleFonts.caveat(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amountCtrl,
                        focusNode: _amountFocus,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixIcon: Icon(
                            Icons.attach_money,
                            color: theme.colorScheme.secondary,
                            size: 32,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Auto-Fill Preview
                if (autoFillEnvelopes.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No envelopes have auto-fill enabled',
                            style: GoogleFonts.caveat(
                              fontSize: 20,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enable auto-fill in envelope settings to use Pay Day',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Text(
                    'Auto-Fill Preview',
                    style: GoogleFonts.caveat(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        ...autoFillEnvelopes.map(
                          (envelope) => _buildEnvelopePreviewTile(
                            envelope,
                            currencyFormatter,
                            theme,
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Auto-Fill',
                                style: GoogleFonts.caveat(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              Text(
                                currencyFormatter.format(totalAutoFill),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Remaining Amount Display
                if (userAmount > 0 && autoFillEnvelopes.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: remaining >= 0
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: remaining >= 0
                            ? Colors.green.shade300
                            : Colors.red.shade300,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                remaining >= 0
                                    ? 'Remaining to Allocate'
                                    : 'Over Budget!',
                                style: GoogleFonts.caveat(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: remaining >= 0
                                      ? Colors.green.shade800
                                      : Colors.red.shade800,
                                ),
                              ),
                              if (remaining >= 0)
                                Text(
                                  'You can manually fill other envelopes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                  ),
                                )
                              else
                                Text(
                                  'Auto-fill exceeds your amount',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          currencyFormatter.format(remaining.abs()),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: remaining >= 0
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),

                // Process Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed:
                        (userAmount > 0 &&
                            autoFillEnvelopes.isNotEmpty &&
                            !_processing &&
                            remaining >= 0)
                        ? () => _processPayDay(autoFillEnvelopes, userAmount)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _processing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, size: 28),
                              const SizedBox(width: 12),
                              Text(
                                'Process Pay Day',
                                style: GoogleFonts.caveat(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Help text
                Center(
                  child: Text(
                    'This will add deposits to all auto-fill envelopes',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withAlpha(128),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnvelopePreviewTile(
    Envelope envelope,
    NumberFormat formatter,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Emoji
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withAlpha(51),
              ),
            ),
            child: Center(
              child: Text(
                envelope.emoji ?? '📨',
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  envelope.name,
                  style: GoogleFonts.caveat(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (envelope.subtitle != null &&
                    envelope.subtitle!.isNotEmpty) ...[
                  Text(
                    envelope.subtitle!,
                    style: GoogleFonts.caveat(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withAlpha(153),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Amount
          Row(
            children: [
              const Icon(Icons.add, color: Colors.green, size: 16),
              const SizedBox(width: 4),
              Text(
                formatter.format(envelope.autoFillAmount ?? 0.0),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Success Dialog with Confetti
class _PayDaySuccessDialog extends StatefulWidget {
  const _PayDaySuccessDialog({required this.envelopesFilled});

  final int envelopesFilled;

  @override
  State<_PayDaySuccessDialog> createState() => _PayDaySuccessDialogState();
}

class _PayDaySuccessDialogState extends State<_PayDaySuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();

    // Auto-dismiss after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Confetti emoji
            const Text('🎉', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            Text(
              'Pay Day Complete!',
              style: GoogleFonts.caveat(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.envelopesFilled} ${widget.envelopesFilled == 1 ? 'envelope' : 'envelopes'} filled successfully',
              style: GoogleFonts.caveat(
                fontSize: 20,
                color: theme.colorScheme.onSurface.withAlpha(179),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
