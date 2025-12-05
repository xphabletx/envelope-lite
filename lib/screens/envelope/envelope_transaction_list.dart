import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../models/transaction.dart';

class EnvelopeTransactionList extends StatelessWidget {
  const EnvelopeTransactionList({
    super.key,
    required this.transactions,
    this.onTransactionTap,
  });

  final List<Transaction> transactions;
  final Function(Transaction)? onTransactionTap;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const _EmptyState();
    }

    // Group transactions by date
    final grouped = _groupByDate(transactions);

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
        );
      },
    );
  }

  Map<String, List<Transaction>> _groupByDate(List<Transaction> txs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

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
  });

  final String groupName;
  final List<Transaction> transactions;
  final Function(Transaction)? onTransactionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            groupName,
            style: GoogleFonts.caveat(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),

        // Transactions in this group
        ...transactions.map(
          (tx) => _TransactionTile(
            transaction: tx,
            onTap: onTransactionTap != null
                ? () => onTransactionTap!(tx)
                : null,
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction, this.onTap});

  final Transaction transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(symbol: '£');

    // Determine transaction display based on type
    IconData icon;
    Color color;
    String prefix;

    switch (transaction.type) {
      case TransactionType.deposit:
        icon = Icons.add_circle;
        color = Colors.green.shade700;
        prefix = '+';
        break;
      case TransactionType.withdrawal:
        icon = Icons.remove_circle;
        color = Colors.red.shade700;
        prefix = '-';
        break;
      case TransactionType.transfer:
        if (transaction.transferDirection == TransferDirection.in_) {
          icon = Icons.arrow_downward;
          color = Colors.blue.shade700;
          prefix = '+';
        } else {
          icon = Icons.arrow_upward;
          color = Colors.orange.shade700;
          prefix = '-';
        }
        break;
    }

    // Build description based on transaction type
    String description = transaction.description;
    String? subtitle;

    if (transaction.type == TransactionType.transfer) {
      if (transaction.transferDirection == TransferDirection.in_) {
        subtitle = 'From: ${transaction.sourceEnvelopeName ?? "Unknown"}';
        if (transaction.sourceOwnerDisplayName != null) {
          subtitle += ' (${transaction.sourceOwnerDisplayName})';
        }
      } else {
        subtitle = 'To: ${transaction.targetEnvelopeName ?? "Unknown"}';
        if (transaction.targetOwnerDisplayName != null) {
          subtitle += ' (${transaction.targetOwnerDisplayName})';
        }
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          description.isEmpty ? 'No description' : description,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: subtitle != null
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subtitle,
                  style: GoogleFonts.caveat(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              )
            : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$prefix${currencyFormatter.format(transaction.amount.abs())}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('HH:mm').format(transaction.date),
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: GoogleFonts.caveat(
              fontSize: 24,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add money to get started!',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
