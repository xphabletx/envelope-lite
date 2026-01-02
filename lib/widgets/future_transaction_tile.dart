// lib/widgets/future_transaction_tile.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import '../models/envelope.dart';
import '../providers/font_provider.dart';
import '../providers/locale_provider.dart';

class FutureTransactionTile extends StatelessWidget {
  const FutureTransactionTile({
    super.key,
    required this.transaction,
    this.accounts,
    this.envelopes,
  });

  final Transaction transaction;
  final List<Account>? accounts;
  final List<Envelope>? envelopes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);
    final dateFormat = DateFormat('MMM d, yyyy');

    final t = transaction;

    // Find related envelope if exists
    final envelope = (envelopes ?? []).firstWhere(
      (e) => e.id == t.envelopeId,
      orElse: () => Envelope(id: '', name: '', userId: ''),
    );

    // Determine display properties based on transaction type
    String title;
    Widget entityIcon;
    Color color;

    // Transaction type 1: Envelope Auto-Fill Deposits (from linked account)
    if (t.type == TransactionType.deposit && t.description.contains('Auto-fill deposit from')) {
      // Extract account name from description
      final match = RegExp(r'Auto-fill deposit from (.+)').firstMatch(t.description);
      final accountName = match?.group(1) ?? 'Unknown Account';

      title = '${envelope.name} - Auto-fill deposit from $accountName';
      entityIcon = envelope.id.isNotEmpty
          ? envelope.getIconWidget(theme, size: 24)
          : Icon(Icons.mail_outline, size: 24, color: theme.colorScheme.primary);
      color = Colors.green.shade300;
    }
    // Transaction type 2: Scheduled Payments (from envelopes)
    else if (t.type == TransactionType.scheduledPayment) {
      title = '${envelope.name} - Scheduled payment';
      entityIcon = envelope.id.isNotEmpty
          ? envelope.getIconWidget(theme, size: 24)
          : Icon(Icons.mail_outline, size: 24, color: theme.colorScheme.primary);
      color = Colors.purple.shade300;
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
      entityIcon = defaultAccount.getIconWidget(theme, size: 24);
      color = Colors.green.shade300;
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
        entityIcon = env.getIconWidget(theme, size: 24);
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
        entityIcon = account.getIconWidget(theme, size: 24);
      }

      color = Colors.red.shade300;
    }
    // Regular envelope transactions
    else if (t.type == TransactionType.deposit || t.type == TransactionType.withdrawal) {
      title = t.description.isNotEmpty ? t.description : (t.type == TransactionType.deposit ? 'Deposit' : 'Withdrawal');
      entityIcon = envelope.id.isNotEmpty
          ? envelope.getIconWidget(theme, size: 24)
          : Icon(Icons.mail_outline, size: 24, color: theme.colorScheme.primary);
      color = t.type == TransactionType.deposit ? Colors.green.shade300 : Colors.red.shade300;
    }
    // Transfer transactions
    else {
      title = 'Transfer';
      entityIcon = Icon(Icons.swap_horiz, size: 24, color: theme.colorScheme.primary);
      color = Colors.blue.shade300;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.5),
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: SizedBox(width: 24, height: 24, child: entityIcon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '⏰',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        title,
                        style: fontProvider.getTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (transaction.type == TransactionType.scheduledPayment)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'SCHEDULED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PROJECTED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(transaction.date),
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSecondaryContainer.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Text(
              _getAmountPrefix() + currency.format(transaction.amount),
              style: fontProvider.getTextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _getAmountPrefix() {
    switch (transaction.type) {
      case TransactionType.deposit:
        return '+';
      case TransactionType.withdrawal:
      case TransactionType.scheduledPayment:
        return '-';
      case TransactionType.transfer:
        return '→';
    }
  }
}
