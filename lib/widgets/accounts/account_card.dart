import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/account.dart';
import '../../models/transaction.dart';
import '../../services/account_repo.dart';
import '../../services/envelope_repo.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/time_machine_provider.dart';
import './account_quick_action_modal.dart';

class AccountCard extends StatefulWidget {
  const AccountCard({
    super.key,
    required this.account,
    required this.accountRepo,
    required this.envelopeRepo,
    required this.onTap,
  });

  final Account account;
  final AccountRepo accountRepo;
  final EnvelopeRepo envelopeRepo;
  final VoidCallback onTap;

  @override
  State<AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<AccountCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  bool _isRevealed = false;

  static const double _actionButtonsWidth = 164.0;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.0, 0),
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _toggleReveal() {
    setState(() {
      if (_isRevealed) {
        _slideController.reverse();
      } else {
        _slideController.forward();
      }
      _isRevealed = !_isRevealed;
    });
  }

  void _hideButtons() {
    if (_isRevealed) {
      setState(() {
        _slideController.reverse();
        _isRevealed = false;
      });
    }
  }

  void _showQuickAction(TransactionType type) {
    _hideButtons();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AccountQuickActionModal(
        account: widget.account,
        allAccounts: widget.accountRepo.getAccountsSync(),
        repo: widget.accountRepo,
        type: type,
        envelopeRepo: widget.envelopeRepo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);
    final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);

    // Use projected account if time machine is active
    final displayAccount = timeMachine.isActive
        ? timeMachine.getProjectedAccount(widget.account)
        : widget.account;

    return StreamBuilder<double>(
      stream: widget.accountRepo.assignedAmountStream(widget.account.id),
      builder: (context, snapshot) {
        final assigned = snapshot.data ?? 0.0;
        final available = displayAccount.currentBalance - assigned;
        final isLoading = !snapshot.hasData;

        // Debug logging for account balance calculation
        if (snapshot.hasData) {
        }

        final cardContent = Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                if (_isRevealed) {
                  _hideButtons();
                } else {
                  widget.onTap();
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline.withAlpha(51),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        widget.account.getIconWidget(theme, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.account.name,
                            style: fontProvider.getTextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (widget.account.isDefault)
                          const Icon(Icons.star, color: Colors.amber, size: 24),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Balance',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withAlpha(153),
                      ),
                    ),
                    Text(
                      currency.format(displayAccount.currentBalance),
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
                      Column(
                        children: [
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
                                        color:
                                            theme.colorScheme.onSurface.withAlpha(153),
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
                                        color:
                                            theme.colorScheme.onSurface.withAlpha(153),
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
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );

        return GestureDetector(
          onHorizontalDragEnd: (details) async {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity!.abs() > 300) {
                // Swipe logic
                _toggleReveal();
              }
            }
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _ActionButton(
                          icon: Icons.add,
                          onPressed: () =>
                              _showQuickAction(TransactionType.deposit),
                          primaryColor: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        _ActionButton(
                          icon: Icons.remove,
                          onPressed: () =>
                              _showQuickAction(TransactionType.withdrawal),
                          primaryColor: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        _ActionButton(
                          icon: Icons.swap_horiz,
                          onPressed: () =>
                              _showQuickAction(TransactionType.transfer),
                          primaryColor: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  final pixelOffset = Offset(
                    _slideAnimation.value.dx * _actionButtonsWidth,
                    0,
                  );
                  return Transform.translate(
                    offset: pixelOffset,
                    child: cardContent,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.onPressed,
    required this.primaryColor,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withAlpha(38),
            border: Border.all(
              color: primaryColor.withAlpha(77),
              width: 1.5,
            ),
          ),
          child: Icon(icon, color: primaryColor, size: 22),
        ),
      ),
    );
  }
}
