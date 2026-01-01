// lib/screens/envelope/envelope_transaction_list.dart
// DEPRECATION FIX: .withOpacity -> .withValues(alpha: )
// FONT PROVIDER INTEGRATED: Removed GoogleFonts

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/transaction.dart';
import '../../../models/account.dart';
import '../../../models/envelope.dart';
import '../../../providers/font_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../providers/time_machine_provider.dart';
import '../../widgets/future_transaction_tile.dart';

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
            return _TransactionTile(
              transaction: tx,
              accounts: accounts,
              envelopes: envelopes,
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

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    this.onTap,
    this.accounts,
    this.envelopes,
  });

  final Transaction transaction;
  final VoidCallback? onTap;
  final List<Account>? accounts;
  final List<Envelope>? envelopes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    final t = transaction;

    // Find related envelope if exists
    final envelope = (envelopes ?? []).firstWhere(
      (e) => e.id == t.envelopeId,
      orElse: () => Envelope(id: '', name: '', userId: ''),
    );

    // Determine display properties based on transaction type
    String title;
    Widget leadingIcon;
    Color color;
    String amountStr;

    // Transaction type 1: Envelope Auto-Fill Deposits (from linked account)
    if (t.type == TransactionType.deposit && t.description.contains('Auto-fill deposit from')) {
      // Extract account name from description
      final match = RegExp(r'Auto-fill deposit from (.+)').firstMatch(t.description);
      final accountName = match?.group(1) ?? 'Unknown Account';

      title = '${envelope.name} - Auto-fill deposit from $accountName';
      leadingIcon = envelope.id.isNotEmpty
          ? envelope.getIconWidget(theme, size: 24)
          : Icon(Icons.mail_outline, size: 24, color: theme.colorScheme.primary);
      color = Colors.green.shade700;
      amountStr = '+${currency.format(t.amount)}';
    }
    // Transaction type 2: Scheduled Payments (from envelopes)
    else if (t.type == TransactionType.scheduledPayment) {
      title = '${envelope.name} - Scheduled payment';
      leadingIcon = envelope.id.isNotEmpty
          ? envelope.getIconWidget(theme, size: 24)
          : Icon(Icons.mail_outline, size: 24, color: theme.colorScheme.primary);
      color = Colors.purple.shade700;
      amountStr = '-${currency.format(t.amount)}';
    }
    // Transaction type 3: Pay Day (income to default account)
    else if (t.type == TransactionType.deposit && t.envelopeId.isEmpty && t.description == 'PAY DAY!') {
      // Find default account
      final defaultAccount = (accounts ?? []).firstWhere(
        (a) => a.isDefault,
        orElse: () => (accounts?.isNotEmpty ?? false) ? accounts!.first : Account(
          id: '', name: 'Main', currentBalance: 0, userId: '',
          createdAt: DateTime.now(), lastUpdated: DateTime.now()
        ),
      );

      title = '${defaultAccount.name} - PAY DAY!';
      leadingIcon = defaultAccount.getIconWidget(theme, size: 24);
      color = Colors.green.shade700;
      amountStr = '+${currency.format(t.amount)}';
    }
    // Transaction type 5 & 6: Withdrawal auto-fill (to envelope or account)
    else if (t.type == TransactionType.withdrawal && t.description.contains(' - Withdrawal auto-fill')) {
      // Extract entity name from description "[Entity Name] - Withdrawal auto-fill"
      final entityName = t.description.replaceAll(' - Withdrawal auto-fill', '');

      // Try to find envelope first
      final env = (envelopes ?? []).firstWhere(
        (e) => e.name == entityName,
        orElse: () => Envelope(id: '', name: '', userId: ''),
      );

      if (env.id.isNotEmpty) {
        // Transaction type 5: Money leaving to envelope
        title = '$entityName - Withdrawal auto-fill';
        leadingIcon = env.getIconWidget(theme, size: 24);
      } else {
        // Transaction type 6: Money leaving to another account
        final account = (accounts ?? []).firstWhere(
          (a) => a.name == entityName,
          orElse: () => Account(
            id: '', name: entityName, currentBalance: 0, userId: '',
            createdAt: DateTime.now(), lastUpdated: DateTime.now()
          ),
        );
        title = '$entityName - Withdrawal auto-fill';
        leadingIcon = account.getIconWidget(theme, size: 24);
      }

      color = Colors.red.shade700;
      amountStr = '-${currency.format(t.amount)}';
    }
    // Regular envelope transactions (deposit/withdrawal)
    else if (t.type == TransactionType.deposit || t.type == TransactionType.withdrawal) {
      title = t.description.isNotEmpty ? t.description : (t.type == TransactionType.deposit ? 'Deposit' : 'Withdrawal');
      leadingIcon = envelope.id.isNotEmpty
          ? envelope.getIconWidget(theme, size: 24)
          : Icon(Icons.mail_outline, size: 24, color: theme.colorScheme.primary);

      if (t.type == TransactionType.deposit) {
        color = Colors.green.shade700;
        amountStr = '+${currency.format(t.amount)}';
      } else {
        color = Colors.red.shade700;
        amountStr = '-${currency.format(t.amount)}';
      }
    }
    // Transfer transactions
    else {
      if (t.transferDirection == TransferDirection.in_) {
        title = 'From: ${t.sourceEnvelopeName ?? "Unknown"}';
      } else {
        title = 'To: ${t.targetEnvelopeName ?? "Unknown"}';
      }
      leadingIcon = Icon(Icons.swap_horiz, size: 24, color: theme.colorScheme.primary);
      color = Colors.blue.shade700;
      amountStr = '→${currency.format(t.amount)}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SizedBox(width: 24, height: 24, child: leadingIcon),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amountStr,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('HH:mm').format(t.date),
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
