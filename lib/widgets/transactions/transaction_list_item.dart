// lib/widgets/transactions/transaction_list_item.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../models/envelope.dart';
import '../../models/account.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';

/// Visual transaction display types with distinct colors and icons
enum TransactionDisplayType {
  withdrawal,      // Money out (red ↓)
  deposit,         // Money in (green ↑)
  transfer,        // Between envelopes/accounts (blue ⇄)
  autopilot,       // Scheduled transaction (purple 🔄)
  cashFlow,        // Pay Day Cash Flow (green ↑)
  initialBalance,  // Starting balance (neutral)
}

/// Display information for a transaction with visual styling
class TransactionDisplayInfo {
  final TransactionDisplayType type;
  final String actionText;        // "Sent to Main Account", "Received from Savings"
  final IconData icon;            // Envelope or Account icon
  final IconData arrowIcon;       // Arrow type
  final Color amountColor;        // Red, Green, Blue, Purple
  final String amountPrefix;      // "+", "-", or "⇄"
  final String sourceName;        // Name of envelope/account
  final bool isEnvelope;          // true = envelope, false = account

  const TransactionDisplayInfo({
    required this.type,
    required this.actionText,
    required this.icon,
    required this.arrowIcon,
    required this.amountColor,
    required this.amountPrefix,
    required this.sourceName,
    required this.isEnvelope,
  });
}

class TransactionListItem extends StatelessWidget {
  final Transaction transaction;
  final List<Envelope> envelopes;
  final List<Account> accounts;
  final VoidCallback? onTap;

  const TransactionListItem({
    super.key,
    required this.transaction,
    required this.envelopes,
    required this.accounts,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    // Get display info
    final displayInfo = _getDisplayInfo(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            // ICON (Envelope or Account)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: displayInfo.isEnvelope
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                displayInfo.icon,
                size: 24,
                color: displayInfo.isEnvelope
                    ? theme.colorScheme.primary
                    : theme.colorScheme.secondary,
              ),
            ),

            const SizedBox(width: 12),

            // CONTENT (Name, Action, Date)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NAME (bold, prominent)
                  Text(
                    displayInfo.sourceName,
                    style: fontProvider.getTextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // ACTION (with arrow icon)
                  Row(
                    children: [
                      Icon(
                        displayInfo.arrowIcon,
                        size: 16,
                        color: displayInfo.amountColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          displayInfo.actionText,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // DATE/TIME with EXTERNAL/INTERNAL badge
                  Row(
                    children: [
                      Text(
                        _formatDateTime(transaction.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      if (transaction.impact != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: transaction.isExternal
                                ? Colors.orange.shade700.withValues(alpha: 0.2)
                                : Colors.blue.shade700.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            transaction.getImpactBadge(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: transaction.isExternal
                                  ? Colors.orange.shade700
                                  : Colors.blue.shade700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // AMOUNT (bold, colored)
            Text(
              '${displayInfo.amountPrefix}${currency.format(transaction.amount)}',
              style: fontProvider.getTextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: displayInfo.amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  TransactionDisplayInfo _getDisplayInfo(BuildContext context) {
    final theme = Theme.of(context);
    final t = transaction;

    // Determine if this is envelope or account
    final isEnvelope = t.envelopeId.isNotEmpty;

    // Get name
    String sourceName;
    if (isEnvelope) {
      final envelope = envelopes.firstWhere(
        (e) => e.id == t.envelopeId,
        orElse: () => Envelope(id: '', name: 'Unknown Envelope', userId: ''),
      );
      sourceName = envelope.name;
    } else if (t.accountId != null && t.accountId!.isNotEmpty) {
      final account = accounts.firstWhere(
        (a) => a.id == t.accountId,
        orElse: () => Account(
          id: '', name: 'Unknown Account', currentBalance: 0, userId: '',
          createdAt: DateTime.now(), lastUpdated: DateTime.now(),
        ),
      );
      sourceName = account.name;
    } else {
      sourceName = 'Unknown';
    }

    // Determine icon
    IconData icon;
    if (isEnvelope) {
      icon = Icons.mail_outline;
    } else {
      // For account, use credit card icon
      icon = Icons.credit_card;
    }

    // Determine type and action text based on transaction type
    switch (t.type) {
      case TransactionType.deposit:
        // Check for special deposit types
        if (t.description.toLowerCase().contains('cash flow')) {
          return TransactionDisplayInfo(
            type: TransactionDisplayType.cashFlow,
            actionText: 'Cash Flow',
            icon: icon,
            arrowIcon: Icons.arrow_upward,
            amountColor: Colors.green.shade600,
            amountPrefix: '+',
            sourceName: sourceName,
            isEnvelope: isEnvelope,
          );
        } else if (t.description.toLowerCase().contains('pay day') ||
                   t.description == 'PAY DAY!') {
          return TransactionDisplayInfo(
            type: TransactionDisplayType.deposit,
            actionText: 'Pay Day Deposit',
            icon: icon,
            arrowIcon: Icons.arrow_upward,
            amountColor: Colors.green.shade600,
            amountPrefix: '+',
            sourceName: sourceName,
            isEnvelope: isEnvelope,
          );
        } else if (t.description.toLowerCase() == 'initial balance') {
          return TransactionDisplayInfo(
            type: TransactionDisplayType.initialBalance,
            actionText: 'Initial Balance',
            icon: icon,
            arrowIcon: Icons.circle_outlined,
            amountColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            amountPrefix: '',
            sourceName: sourceName,
            isEnvelope: isEnvelope,
          );
        } else {
          // Show the description if available, otherwise "Deposit"
          final actionText = t.description.isNotEmpty ? t.description : 'Deposit';
          return TransactionDisplayInfo(
            type: TransactionDisplayType.deposit,
            actionText: actionText,
            icon: icon,
            arrowIcon: Icons.arrow_upward,
            amountColor: Colors.green.shade600,
            amountPrefix: '+',
            sourceName: sourceName,
            isEnvelope: isEnvelope,
          );
        }

      case TransactionType.withdrawal:
        if (t.description.toLowerCase().contains('autopilot')) {
          return TransactionDisplayInfo(
            type: TransactionDisplayType.autopilot,
            actionText: 'Autopilot Payment',
            icon: icon,
            arrowIcon: Icons.autorenew,
            amountColor: Colors.purple.shade600,
            amountPrefix: '',
            sourceName: sourceName,
            isEnvelope: isEnvelope,
          );
        } else if (t.description.toLowerCase().contains('auto-fill') ||
                   t.description.toLowerCase().contains('autofill') ||
                   t.description.toLowerCase().contains('envelope auto-fill')) {
          return TransactionDisplayInfo(
            type: TransactionDisplayType.autopilot,
            actionText: 'Envelope Auto-Fill',
            icon: icon,
            arrowIcon: Icons.autorenew,
            amountColor: Colors.purple.shade600,
            amountPrefix: '-',
            sourceName: sourceName,
            isEnvelope: isEnvelope,
          );
        } else {
          // Show the description if available, otherwise "Withdrawal"
          final actionText = t.description.isNotEmpty ? t.description : 'Withdrawal';
          return TransactionDisplayInfo(
            type: TransactionDisplayType.withdrawal,
            actionText: actionText,
            icon: icon,
            arrowIcon: Icons.arrow_downward,
            amountColor: Colors.red.shade600,
            amountPrefix: '-',
            sourceName: sourceName,
            isEnvelope: isEnvelope,
          );
        }

      case TransactionType.transfer:
        // Check for Pay Day Cash Flow transfers
        if (t.description == 'Cash Flow') {
          // Pay Day Cash Flow - show in purple like the cash flow card
          String targetName = t.targetEnvelopeName ?? 'Unknown';
          String sourceTransferName = t.sourceEnvelopeName ?? 'Unknown';
          bool isOutgoing = t.transferDirection == TransferDirection.out_;

          return TransactionDisplayInfo(
            type: TransactionDisplayType.cashFlow,
            actionText: isOutgoing
                ? 'Cash Flow to $targetName'
                : 'Cash Flow from $sourceTransferName',
            icon: icon,
            arrowIcon: Icons.arrow_upward,
            amountColor: Colors.purple,
            amountPrefix: '+',
            sourceName: sourceName,
            isEnvelope: isEnvelope,
          );
        }

        // Regular transfers
        String targetName = t.targetEnvelopeName ?? 'Unknown';
        String sourceTransferName = t.sourceEnvelopeName ?? 'Unknown';

        // For transfers, show "Sent to" or "Received from" based on direction
        bool isOutgoing = t.transferDirection == TransferDirection.out_;

        return TransactionDisplayInfo(
          type: TransactionDisplayType.transfer,
          actionText: isOutgoing
              ? 'Sent to $targetName'
              : 'Received from $sourceTransferName',
          icon: icon,
          arrowIcon: Icons.swap_horiz,
          amountColor: Colors.blue.shade600,
          amountPrefix: '⇄',
          sourceName: sourceName,
          isEnvelope: isEnvelope,
        );

      case TransactionType.scheduledPayment:
        return TransactionDisplayInfo(
          type: TransactionDisplayType.autopilot,
          actionText: 'Autopilot Payment',
          icon: icon,
          arrowIcon: Icons.autorenew,
          amountColor: Colors.purple.shade600,
          amountPrefix: '',
          sourceName: sourceName,
          isEnvelope: isEnvelope,
        );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transactionDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (transactionDate == today) {
      dateStr = 'Today';
    } else if (transactionDate == yesterday) {
      dateStr = 'Yesterday';
    } else {
      dateStr = DateFormat('MMM d, yyyy').format(dateTime);
    }

    final timeStr = DateFormat('h:mm a').format(dateTime);

    return '$dateStr • $timeStr';
  }
}
