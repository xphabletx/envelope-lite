// lib/screens/envelope/envelope_transaction_list.dart
// DEPRECATION FIX: .withOpacity -> .withValues(alpha: )
// FONT PROVIDER INTEGRATED: Removed GoogleFonts

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/transaction.dart';
import '../../../models/account.dart';
import '../../../models/envelope.dart';
import '../../../providers/font_provider.dart';
import '../../../providers/time_machine_provider.dart';
import '../../widgets/future_transaction_tile.dart';
import '../../widgets/transactions/transaction_list_item.dart';

class EnvelopeTransactionList extends StatelessWidget {
  const EnvelopeTransactionList({
    super.key,
    required this.transactions,
    this.onTransactionTap,
    this.accounts,
    this.envelopes,
  });

  final List<Transaction> transactions;
  final Function(Transaction)? onTransactionTap;
  final List<Account>? accounts;
  final List<Envelope>? envelopes;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const _EmptyState();
    }

    final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);

    // Group transactions by date
    final grouped = _groupByDate(transactions, timeMachine);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped.entries.elementAt(index);
        return _TransactionGroup(
          groupName: entry.key,
          transactions: entry.value,
          onTransactionTap: onTransactionTap,
          accounts: accounts,
          envelopes: envelopes,
        );
      },
    );
  }

  Map<String, List<Transaction>> _groupByDate(List<Transaction> txs, TimeMachineProvider timeMachine) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    // If time machine is active, use different grouping
    if (timeMachine.isActive && timeMachine.futureDate != null) {
      final targetDate = timeMachine.futureDate!;
      final monthStart = DateTime(targetDate.year, targetDate.month, 1);
      final monthEnd = DateTime(targetDate.year, targetDate.month + 1, 0, 23, 59, 59, 999);

      final Map<String, List<Transaction>> grouped = {
        'This Month': [],
        'Projected': [],
      };

      for (final tx in txs) {
        if (tx.isFuture) {
          grouped['Projected']!.add(tx);
        } else {
          final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
          if (txDate.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
              txDate.isBefore(monthEnd.add(const Duration(seconds: 1)))) {
            grouped['This Month']!.add(tx);
          }
        }
      }

      // Remove empty groups
      grouped.removeWhere((key, value) => value.isEmpty);

      return grouped;
    }

    // Normal grouping for present time
    final Map<String, List<Transaction>> grouped = {
      'Today': [],
      'Yesterday': [],
      'This Week': [],
      'Earlier': [],
    };

    for (final tx in txs) {
      final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);

      if (txDate.isAtSameMomentAs(today)) {
        grouped['Today']!.add(tx);
      } else if (txDate.isAtSameMomentAs(yesterday)) {
        grouped['Yesterday']!.add(tx);
      } else if (txDate.isAfter(weekAgo)) {
        grouped['This Week']!.add(tx);
      } else {
        grouped['Earlier']!.add(tx);
      }
    }

    // Remove empty groups
    grouped.removeWhere((key, value) => value.isEmpty);

    return grouped;
  }
}

class _TransactionGroup extends StatelessWidget {
  const _TransactionGroup({
    required this.groupName,
    required this.transactions,
    this.onTransactionTap,
    this.accounts,
    this.envelopes,
  });

  final String groupName;
  final List<Transaction> transactions;
  final Function(Transaction)? onTransactionTap;
  final List<Account>? accounts;
  final List<Envelope>? envelopes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            groupName,
            // UPDATED: FontProvider
            style: fontProvider.getTextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),

        // Transactions in this group
        ...transactions.map(
          (tx) {
            // Use FutureTransactionTile for projected transactions
            if (tx.isFuture) {
              return FutureTransactionTile(
                transaction: tx,
                accounts: accounts,
                envelopes: envelopes,
              );
            }

            // Use regular tile for real transactions
            return TransactionListItem(
              transaction: tx,
              accounts: accounts ?? [],
              envelopes: envelopes ?? [],
              onTap: onTransactionTap != null
                  ? () => onTransactionTap!(tx)
                  : null,
            );
          },
        ),

        const SizedBox(height: 8),
      ],
    );
  }
}


class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            // FIX: withOpacity -> withValues
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            // UPDATED: FontProvider
            style: fontProvider.getTextStyle(
              fontSize: 24,
              // FIX: withOpacity -> withValues
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add money to get started!',
            style: TextStyle(
              fontSize: 14,
              // FIX: withOpacity -> withValues
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
