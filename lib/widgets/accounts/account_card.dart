import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/account.dart';
import '../../services/account_repo.dart';
import '../../providers/font_provider.dart';

class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.account,
    required this.accountRepo,
    required this.onTap,
  });

  final Account account;
  final AccountRepo accountRepo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: '£');

    return FutureBuilder<double>(
      future: accountRepo.getAssignedAmount(account.id),
      builder: (context, snapshot) {
        final assigned = snapshot.data ?? 0.0;
        final available = account.currentBalance - assigned;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Emoji + Name + Default Star
                    Row(
                      children: [
                        Text(
                          account.emoji ?? '💳',
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            account.name,
                            style: fontProvider.getTextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (account.isDefault)
                          const Icon(Icons.star, color: Colors.amber, size: 24),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Main Balance Display
                    Text(
                      'Balance',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    Text(
                      currency.format(account.currentBalance),
                      style: fontProvider.getTextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (isLoading)
                      const LinearProgressIndicator()
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assigned',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                Text(
                                  currency.format(assigned),
                                  style: fontProvider.getTextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Available ✨',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                Text(
                                  currency.format(available),
                                  style: fontProvider.getTextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
