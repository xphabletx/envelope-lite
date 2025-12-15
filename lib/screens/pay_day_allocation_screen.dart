// lib/screens/pay_day_allocation_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/envelope.dart';
import '../services/envelope_repo.dart';
import '../services/group_repo.dart';
import '../providers/font_provider.dart';
import 'pay_day_stuffing_screen.dart';

class PayDayAllocationScreen extends StatefulWidget {
  const PayDayAllocationScreen({
    super.key,
    required this.repo,
    required this.groupRepo,
    required this.totalAmount,
  });

  final EnvelopeRepo repo;
  final GroupRepo groupRepo;
  final double totalAmount;

  @override
  State<PayDayAllocationScreen> createState() => _PayDayAllocationScreenState();
}

class _PayDayAllocationScreenState extends State<PayDayAllocationScreen> {
  Map<String, double> allocations = {};
  List<Envelope> autoPayEnvelopes = [];
  double autoPayTotal = 0.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAutoPayEnvelopes();
  }

  Future<void> _loadAutoPayEnvelopes() async {
    try {
      // Use the SAME path structure as envelope_repo.dart
      final snapshot = await widget.repo.db
          .collection('users')
          .doc(widget.repo.currentUserId)
          .collection('solo')
          .doc('data')
          .collection('envelopes')
          .get();

      // Filter in Dart for autoFillEnabled=true AND autoFillAmount>0
      final envelopes = snapshot.docs
          .map((doc) => Envelope.fromFirestore(doc))
          .where(
            (e) =>
                e.autoFillEnabled == true &&
                e.autoFillAmount != null &&
                e.autoFillAmount! > 0,
          )
          .toList();

      // Sort by name
      envelopes.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      double total = 0.0;
      final Map<String, double> initialAllocations = {};

      for (final env in envelopes) {
        final amount = env.autoFillAmount!;
        initialAllocations[env.id] = amount;
        total += amount;
      }

      if (mounted) {
        setState(() {
          autoPayEnvelopes = envelopes;
          allocations = initialAllocations;
          autoPayTotal = total;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading auto-pay envelopes: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading envelopes: $e')));
      }
    }
  }

  double get remainingAmount {
    final allocated = allocations.values.fold(0.0, (a, b) => a + b);
    return widget.totalAmount - allocated;
  }

  void _startStuffing() {
    if (allocations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No envelopes to fill!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PayDayStuffingScreen(
          repo: widget.repo,
          allocations: allocations,
          envelopes: autoPayEnvelopes,
          totalAmount: widget.totalAmount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: '£');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pay Day',
              style: fontProvider.getTextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            Text(
              currency.format(widget.totalAmount),
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Auto-pay section header
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Auto-Fill Envelopes',
                        style: fontProvider.getTextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Show message if no auto-pay envelopes
                if (autoPayEnvelopes.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 48,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No Auto-Fill Envelopes',
                          style: fontProvider.getTextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enable auto-fill on your envelopes to see them here!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.orange.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                // Auto-pay envelopes list
                ...autoPayEnvelopes.map((env) {
                  final amount = allocations[env.id] ?? 0.0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Emoji
                        Text(
                          env.emoji ?? '📨',
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(width: 12),

                        // Name
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                env.name,
                                style: fontProvider.getTextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (env.subtitle != null &&
                                  env.subtitle!.isNotEmpty)
                                Text(
                                  env.subtitle!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Amount
                        Text(
                          currency.format(amount),
                          style: fontProvider.getTextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // Remaining amount display
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.secondaryContainer,
                        theme.colorScheme.secondaryContainer.withValues(
                          alpha: 0.5,
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.secondary,
                      width: 3,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '💵 Remaining',
                        style: fontProvider.getTextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currency.format(remainingAmount),
                        style: fontProvider.getTextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      if (remainingAmount < 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '⚠️ You\'re over budget!',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Info card about remaining funds
                if (remainingAmount > 0)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You have ${currency.format(remainingAmount)} left over! '
                            'You can manually add it to other envelopes after this.',
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 80),
              ],
            ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _startStuffing,
              backgroundColor: theme.colorScheme.secondary,
              icon: const Icon(Icons.celebration, size: 28),
              label: Text(
                'Start Stuffing! 🎉',
                style: fontProvider.getTextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }
}
