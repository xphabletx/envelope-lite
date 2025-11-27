import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../models/envelope.dart';
import '../models/transaction.dart';
import '../services/envelope_repo.dart';

class EnvelopeDetailScreen extends StatelessWidget {
  const EnvelopeDetailScreen({
    super.key,
    required this.envelope,
    required this.repo,
  });

  final Envelope envelope;
  final EnvelopeRepo repo;

  void _showEnvelopeSettings(BuildContext context, Envelope envelope) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EnvelopeSettingsSheet(envelope: envelope, repo: repo),
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
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: theme.colorScheme.primary),
            onPressed: () => _showEnvelopeSettings(context, envelope),
          ),
        ],
      ),
      body: StreamBuilder<List<Envelope>>(
        stream: repo.envelopesStream,
        builder: (context, envelopeSnap) {
          final liveEnvelope = envelopeSnap.data?.firstWhere(
            (e) => e.id == envelope.id,
            orElse: () => envelope,
          );

          if (liveEnvelope == null || !envelopeSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<List<Transaction>>(
            stream: repo.transactionsStream,
            builder: (context, txSnap) {
              final Map<String, String> envMap = {
                for (final e in (envelopeSnap.data ?? <Envelope>[]))
                  e.id: e.name,
              };
              final allTxs = txSnap.data ?? [];
              final transactions =
                  allTxs.where((t) => t.envelopeId == envelope.id).toList()
                    ..sort((a, b) => b.date.compareTo(a.date));

              double totalDeposited = transactions
                  .where((t) => t.type == TransactionType.deposit)
                  .fold(0.0, (sum, t) => sum + t.amount);
              double totalWithdrawn = transactions
                  .where((t) => t.type == TransactionType.withdrawal)
                  .fold(0.0, (sum, t) => sum + t.amount);
              double totalTransferred = transactions
                  .where((t) => t.type == TransactionType.transfer)
                  .fold(0.0, (sum, t) => sum + t.amount);

              // Calculate progress percentage
              double progressPercent = 0.0;
              if (liveEnvelope.targetAmount != null &&
                  liveEnvelope.targetAmount! > 0) {
                progressPercent =
                    (liveEnvelope.currentAmount / liveEnvelope.targetAmount!)
                        .clamp(0.0, 1.0);
              }

              return SingleChildScrollView(
                child: Column(
                  children: [
                    // Illustrated Envelope Hero Section
                    _buildEnvelopeHero(
                      context,
                      liveEnvelope,
                      progressPercent,
                      currencyFormatter,
                      theme,
                    ),

                    // Progress Bar
                    if (liveEnvelope.targetAmount != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        child: _buildProgressBar(progressPercent, theme),
                      ),

                    const SizedBox(height: 24),

                    // Lifetime Summary Stats
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lifetime Summary',
                            style: GoogleFonts.caveat(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                _buildStatRow(
                                  'Target Amount',
                                  liveEnvelope.targetAmount ?? 0.0,
                                  theme.colorScheme.primary,
                                  currencyFormatter,
                                ),
                                const Divider(height: 24),
                                _buildStatRow(
                                  'Amount until Target',
                                  (liveEnvelope.targetAmount ?? 0.0) -
                                      liveEnvelope.currentAmount,
                                  theme.colorScheme.secondary,
                                  currencyFormatter,
                                ),
                                const Divider(height: 24),
                                _buildStatRow(
                                  'Total Deposited',
                                  totalDeposited,
                                  Colors.green.shade700,
                                  currencyFormatter,
                                ),
                                const Divider(height: 24),
                                _buildStatRow(
                                  'Total Withdrawn',
                                  totalWithdrawn,
                                  Colors.red.shade700,
                                  currencyFormatter,
                                ),
                                const Divider(height: 24),
                                _buildStatRow(
                                  'Total Transferred Out',
                                  totalTransferred,
                                  Colors.blue.shade700,
                                  currencyFormatter,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Transaction Ledger
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Transaction Ledger',
                                style: GoogleFonts.caveat(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondary.withAlpha(
                                    51,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${transactions.length}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (transactions.isEmpty && !txSnap.hasData)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          if (transactions.isEmpty && txSnap.hasData)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No transactions yet',
                                      style: GoogleFonts.caveat(
                                        fontSize: 20,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ...transactions.map(
                              (t) => _buildTransactionTile(
                                t,
                                currencyFormatter,
                                envMap,
                                theme,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEnvelopeHero(
    BuildContext context,
    Envelope envelope,
    double progressPercent,
    NumberFormat currencyFormatter,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          // Envelope name in Caveat
          Text(
            envelope.name,
            style: GoogleFonts.caveat(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),

          // Subtitle if exists
          if (envelope.subtitle != null && envelope.subtitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '"${envelope.subtitle}"',
              style: GoogleFonts.caveat(
                fontSize: 22,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withAlpha(179),
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 32),

          // Illustrated Envelope
          SizedBox(
            height: 280,
            child: CustomPaint(
              size: const Size(double.infinity, 280),
              painter: EnvelopePainter(
                primaryColor: theme.colorScheme.primary,
                secondaryColor: theme.colorScheme.secondary,
                surfaceColor: theme.colorScheme.surface,
                emoji: envelope.emoji ?? '📨',
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Current amount (large)
          Text(
            currencyFormatter.format(envelope.currentAmount),
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          ),

          // Target info
          if (envelope.targetAmount != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'of ${currencyFormatter.format(envelope.targetAmount)}',
                  style: TextStyle(
                    fontSize: 18,
                    color: theme.colorScheme.onSurface.withAlpha(179),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(progressPercent * 100).toInt()}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar(double percent, ThemeData theme) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 12,
            backgroundColor: theme.colorScheme.surface,
            valueColor: AlwaysStoppedAnimation(theme.colorScheme.secondary),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(
    String label,
    double amount,
    Color color,
    NumberFormat currencyFormatter,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 15)),
        Text(
          currencyFormatter.format(amount),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: amount < 0 ? Colors.red : color,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(
    Transaction t,
    NumberFormat currencyFormatter,
    Map<String, String> envMap,
    ThemeData theme,
  ) {
    late final IconData icon;
    late final Color color;
    late final String sign;
    late final String titleText;

    if (t.type == TransactionType.transfer) {
      final isIn = t.transferDirection == TransferDirection.in_;
      icon = Icons.swap_horiz;
      color = Colors.blue.shade700;
      sign = isIn ? '+' : '-';

      if (t.sourceEnvelopeName != null && t.targetEnvelopeName != null) {
        final sourceOwner = t.sourceOwnerDisplayName ?? 'Unknown';
        final targetOwner = t.targetOwnerDisplayName ?? 'Unknown';
        final sourceName = t.sourceEnvelopeName!;
        final targetName = t.targetEnvelopeName!;
        titleText = '$sourceOwner: $sourceName → $targetOwner: $targetName';
      } else {
        final peerName = envMap[t.transferPeerEnvelopeId ?? ''] ?? 'Unknown';
        titleText = isIn ? 'From $peerName' : 'To $peerName';
      }
    } else if (t.type == TransactionType.deposit) {
      icon = Icons.add_circle;
      color = Colors.green.shade700;
      sign = '+';
      titleText = 'Deposit';
    } else {
      icon = Icons.remove_circle;
      color = Colors.red.shade700;
      sign = '-';
      titleText = 'Withdrawal';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (t.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    t.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withAlpha(153),
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM dd, yyyy · hh:mm a').format(t.date),
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withAlpha(128),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$sign${currencyFormatter.format(t.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Simple envelope painter - sealed, clean design
class EnvelopePainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final Color surfaceColor;
  final String emoji;

  EnvelopePainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.surfaceColor,
    required this.emoji,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final envelopeWidth = size.width * 0.75;
    final envelopeHeight = envelopeWidth * 0.6;

    // Draw envelope body
    _drawEnvelopeBody(canvas, centerX, centerY, envelopeWidth, envelopeHeight);

    // Draw sealed flap on top
    _drawSealedFlap(canvas, centerX, centerY, envelopeWidth, envelopeHeight);

    // Draw emoji
    _drawEmoji(canvas, centerX, centerY + envelopeHeight * 0.15);
  }

  void _drawEnvelopeBody(
    Canvas canvas,
    double cx,
    double cy,
    double width,
    double height,
  ) {
    final bodyPaint = Paint()
      ..color = surfaceColor
      ..style = PaintingStyle.fill;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: width, height: height),
      const Radius.circular(8),
    );

    canvas.drawRRect(bodyRect, bodyPaint);

    final borderPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(bodyRect, borderPaint);
  }

  void _drawSealedFlap(
    Canvas canvas,
    double cx,
    double cy,
    double width,
    double height,
  ) {
    final flapPaint = Paint()
      ..color = primaryColor.withAlpha(230)
      ..style = PaintingStyle.fill;

    final flapTipY = cy - height * 0.35;

    final flapPath = Path()
      ..moveTo(cx - width / 2, cy - height / 2)
      ..lineTo(cx, flapTipY)
      ..lineTo(cx + width / 2, cy - height / 2)
      ..close();

    canvas.drawPath(flapPath, flapPaint);

    final flapBorderPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawPath(flapPath, flapBorderPaint);
  }

  void _drawEmoji(Canvas canvas, double cx, double cy) {
    final textPainter = TextPainter(
      text: TextSpan(text: emoji, style: const TextStyle(fontSize: 52)),
      textDirection: ui.TextDirection.ltr,
    );

    textPainter.layout();

    textPainter.paint(
      canvas,
      Offset(cx - textPainter.width / 2, cy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(EnvelopePainter oldDelegate) {
    return oldDelegate.emoji != emoji ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}

// Envelope Settings Sheet
class _EnvelopeSettingsSheet extends StatefulWidget {
  const _EnvelopeSettingsSheet({required this.envelope, required this.repo});

  final Envelope envelope;
  final EnvelopeRepo repo;

  @override
  State<_EnvelopeSettingsSheet> createState() => _EnvelopeSettingsSheetState();
}

class _EnvelopeSettingsSheetState extends State<_EnvelopeSettingsSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _targetCtrl;
  late TextEditingController _subtitleCtrl;
  late TextEditingController _autoFillAmountCtrl;
  late bool _autoFillEnabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.envelope.name);
    _targetCtrl = TextEditingController(
      text: widget.envelope.targetAmount?.toStringAsFixed(2) ?? '',
    );
    _subtitleCtrl = TextEditingController(text: widget.envelope.subtitle ?? '');
    _autoFillAmountCtrl = TextEditingController(
      text: widget.envelope.autoFillAmount?.toStringAsFixed(2) ?? '',
    );
    _autoFillEnabled = widget.envelope.autoFillEnabled;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _subtitleCtrl.dispose();
    _autoFillAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }

    double? target;
    if (_targetCtrl.text.trim().isNotEmpty) {
      target = double.tryParse(_targetCtrl.text.trim());
      if (target == null || target < 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid target amount')));
        return;
      }
    }

    final subtitle = _subtitleCtrl.text.trim();

    double? autoFillAmount;
    if (_autoFillEnabled) {
      if (_autoFillAmountCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto-fill amount required when enabled'),
          ),
        );
        return;
      }
      autoFillAmount = double.tryParse(_autoFillAmountCtrl.text.trim());
      if (autoFillAmount == null || autoFillAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid auto-fill amount')),
        );
        return;
      }
    }

    setState(() => _saving = true);

    try {
      await widget.repo.updateEnvelope(
        envelopeId: widget.envelope.id,
        name: name,
        targetAmount: target,
        subtitle: subtitle.isEmpty ? null : subtitle,
        autoFillEnabled: _autoFillEnabled,
        autoFillAmount: _autoFillEnabled ? autoFillAmount : null,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Envelope updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: media.viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Envelope Settings',
                      style: GoogleFonts.caveat(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _subtitleCtrl,
                  maxLength: 50,
                  decoration: const InputDecoration(
                    labelText: 'Subtitle (optional)',
                    hintText: 'e.g., "Weekly shopping"',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _targetCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Target Amount (£)',
                    hintText: 'e.g., 1000.00',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withAlpha(51),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.monetization_on,
                            color: theme.colorScheme.secondary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Pay Day Auto-Fill',
                            style: GoogleFonts.caveat(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const Spacer(),
                          Switch(
                            value: _autoFillEnabled,
                            onChanged: (value) {
                              setState(() => _autoFillEnabled = value);
                            },
                            activeColor: theme.colorScheme.secondary,
                          ),
                        ],
                      ),
                      if (_autoFillEnabled) ...[
                        const SizedBox(height: 8),
                        Text(
                          'This envelope will be automatically filled on Pay Day',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withAlpha(179),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _autoFillAmountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Amount to add each Pay Day (£)',
                            hintText: 'e.g., 50.00',
                            border: const OutlineInputBorder(),
                            prefixIcon: Icon(
                              Icons.add_circle_outline,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Save Changes',
                            style: GoogleFonts.caveat(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
