import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/envelope.dart';
import '../services/envelope_repo.dart';

// Model for scheduled transaction
class ScheduledTransaction {
  final String id;
  final String envelopeId;
  final String envelopeName;
  final double amount;
  final String description;
  final DateTime nextDueDate;
  final RecurringFrequency frequency;
  final bool isAutomatic; // Auto-execute on due date?

  ScheduledTransaction({
    required this.id,
    required this.envelopeId,
    required this.envelopeName,
    required this.amount,
    required this.description,
    required this.nextDueDate,
    required this.frequency,
    this.isAutomatic = false,
  });
}

enum RecurringFrequency { weekly, biweekly, monthly, quarterly, yearly }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.repo});

  final EnvelopeRepo repo;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // PROTOTYPE DATA - Replace with Firestore later
  final List<ScheduledTransaction> _scheduledTransactions = [
    ScheduledTransaction(
      id: '1',
      envelopeId: 'env1',
      envelopeName: 'Rent',
      amount: -850.00,
      description: 'Monthly rent payment',
      nextDueDate: DateTime.now().add(const Duration(days: 2)),
      frequency: RecurringFrequency.monthly,
      isAutomatic: false,
    ),
    ScheduledTransaction(
      id: '2',
      envelopeId: 'env2',
      envelopeName: 'Electric Bill',
      amount: -65.00,
      description: 'Electricity',
      nextDueDate: DateTime.now().add(const Duration(days: 5)),
      frequency: RecurringFrequency.monthly,
      isAutomatic: true,
    ),
    ScheduledTransaction(
      id: '3',
      envelopeId: 'env3',
      envelopeName: 'Netflix',
      amount: -15.99,
      description: 'Streaming subscription',
      nextDueDate: DateTime.now().add(const Duration(days: 8)),
      frequency: RecurringFrequency.monthly,
      isAutomatic: true,
    ),
    ScheduledTransaction(
      id: '4',
      envelopeId: 'env4',
      envelopeName: 'Salary',
      amount: 2500.00,
      description: 'Monthly salary',
      nextDueDate: DateTime.now().add(const Duration(days: 15)),
      frequency: RecurringFrequency.monthly,
      isAutomatic: false,
    ),
  ];

  Map<String, List<ScheduledTransaction>> _groupByDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekFromNow = today.add(const Duration(days: 7));

    final Map<String, List<ScheduledTransaction>> grouped = {
      'Overdue': [],
      'Today': [],
      'Tomorrow': [],
      'This Week': [],
      'Later': [],
    };

    for (final tx in _scheduledTransactions) {
      final dueDate = DateTime(
        tx.nextDueDate.year,
        tx.nextDueDate.month,
        tx.nextDueDate.day,
      );

      if (dueDate.isBefore(today)) {
        grouped['Overdue']!.add(tx);
      } else if (dueDate.isAtSameMomentAs(today)) {
        grouped['Today']!.add(tx);
      } else if (dueDate.isAtSameMomentAs(tomorrow)) {
        grouped['Tomorrow']!.add(tx);
      } else if (dueDate.isBefore(weekFromNow)) {
        grouped['This Week']!.add(tx);
      } else {
        grouped['Later']!.add(tx);
      }
    }

    // Remove empty groups
    grouped.removeWhere((key, value) => value.isEmpty);

    return grouped;
  }

  String _formatFrequency(RecurringFrequency freq) {
    switch (freq) {
      case RecurringFrequency.weekly:
        return 'Weekly';
      case RecurringFrequency.biweekly:
        return 'Bi-weekly';
      case RecurringFrequency.monthly:
        return 'Monthly';
      case RecurringFrequency.quarterly:
        return 'Quarterly';
      case RecurringFrequency.yearly:
        return 'Yearly';
    }
  }

  void _markAsPaid(ScheduledTransaction tx) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Marked "${tx.description}" as paid'),
        action: SnackBarAction(label: 'UNDO', onPressed: () {}),
      ),
    );
    // TODO: Execute transaction and reschedule next occurrence
  }

  void _skipTransaction(ScheduledTransaction tx) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Skipped "${tx.description}"'),
        action: SnackBarAction(label: 'UNDO', onPressed: () {}),
      ),
    );
    // TODO: Move to next occurrence without executing
  }

  void _addScheduledTransaction() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add Scheduled Transaction - Coming soon!')),
    );
    // TODO: Show dialog to create new scheduled transaction
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(symbol: '£');
    final grouped = _groupByDate();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Upcoming Transactions',
          style: GoogleFonts.caveat(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: theme.colorScheme.primary),
            onPressed: _addScheduledTransaction,
            tooltip: 'Add Scheduled Transaction',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: grouped.entries.map((entry) {
          final groupName = entry.key;
          final transactions = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group header
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
                child: Text(
                  groupName,
                  style: GoogleFonts.caveat(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: groupName == 'Overdue'
                        ? Colors.red.shade700
                        : theme.colorScheme.primary,
                  ),
                ),
              ),

              // Transactions in this group
              ...transactions.map((tx) {
                final isIncome = tx.amount > 0;
                final color = isIncome
                    ? Colors.green.shade700
                    : Colors.red.shade700;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withAlpha(51),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withAlpha(26),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isIncome ? Icons.add_circle : Icons.remove_circle,
                        color: color,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            tx.description,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (tx.isAutomatic)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary.withAlpha(51),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.autorenew,
                                  size: 12,
                                  color: theme.colorScheme.secondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'AUTO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          tx.envelopeName,
                          style: GoogleFonts.caveat(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface.withAlpha(179),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: theme.colorScheme.onSurface.withAlpha(128),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM dd, yyyy').format(tx.nextDueDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withAlpha(
                                  128,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.repeat,
                              size: 12,
                              color: theme.colorScheme.onSurface.withAlpha(128),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatFrequency(tx.frequency),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withAlpha(
                                  128,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currencyFormatter.format(tx.amount.abs()),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => _markAsPaid(tx),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _skipTransaction(tx),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.skip_next,
                                  size: 16,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}
