// lib/widgets/future_transaction_tile.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../providers/font_provider.dart';
import '../providers/locale_provider.dart';

class FutureTransactionTile extends StatelessWidget {
  const FutureTransactionTile({
    super.key,
    required this.transaction,
  });

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);
    final dateFormat = DateFormat('MMM d, yyyy');

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
          Icon(
            Icons.schedule,
            color: theme.colorScheme.secondary.withValues(alpha: 0.7),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        transaction.description.isNotEmpty
                            ? transaction.description
                            : 'Scheduled Payment',
                        style: fontProvider.getTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
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
                        'FUTURE',
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
          Text(
            '${transaction.type == TransactionType.withdrawal ? '-' : '+'}${currency.format(transaction.amount)}',
            style: fontProvider.getTextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: transaction.type == TransactionType.withdrawal
                  ? Colors.red.shade300
                  : Colors.green.shade300,
            ),
          ),
        ],
      ),
    );
  }
}
