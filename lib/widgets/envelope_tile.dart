// lib/widgets/envelope_tile.dart
// FIXED - removed defaultEmoji parameter

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/envelope.dart';
import '../services/envelope_repo.dart';
import 'emoji_pie_chart.dart';
import 'quick_action_modal.dart';
import '../models/transaction.dart';
import '../services/localization_service.dart';
import '../providers/font_provider.dart';
import '../providers/locale_provider.dart';
import '../services/workspace_helper.dart';

class EnvelopeTile extends StatefulWidget {
  const EnvelopeTile({
    super.key,
    required this.envelope,
    required this.allEnvelopes,
    required this.repo,
    this.isSelected = false,
    this.onLongPress,
    this.onTap,
    this.isMultiSelectMode = false,
  });

  final Envelope envelope;
  final List<Envelope> allEnvelopes;
  final EnvelopeRepo repo;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final bool isMultiSelectMode;

  @override
  State<EnvelopeTile> createState() => _EnvelopeTileState();
}

class _EnvelopeTileState extends State<EnvelopeTile>
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
      builder: (ctx) => QuickActionModal(
        envelope: widget.envelope,
        allEnvelopes: widget.allEnvelopes,
        repo: widget.repo,
        type: type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currencyFormat = NumberFormat.currency(symbol: locale.currencySymbol);
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    final isMyEnvelope = widget.envelope.userId == widget.repo.currentUserId;

    double? percentage;
    if (widget.envelope.targetAmount != null &&
        widget.envelope.targetAmount! > 0) {
      percentage =
          (widget.envelope.currentAmount / widget.envelope.targetAmount!).clamp(
            0.0,
            1.0,
          );
    }

    final tileContent = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.isSelected
            ? theme.colorScheme.primary.withAlpha(51)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withAlpha(26),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Show checkbox in multi-select mode
                if (widget.isMultiSelectMode) ...[
                  Checkbox(
                    value: widget.isSelected,
                    onChanged: (_) => widget.onTap?.call(),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                SizedBox(
                  width: 44,
                  height: 44,
                  child: widget.envelope.getIconWidget(theme, size: 44),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMyEnvelope)
                        FutureBuilder<bool>(
                          future: WorkspaceHelper.isCurrentlyInWorkspace(),
                          builder: (context, snapshot) {
                            final inWorkspace = snapshot.data ?? false;
                            if (!inWorkspace) return const SizedBox.shrink();

                            return FutureBuilder<String>(
                              future: widget.repo.getUserDisplayName(
                                widget.envelope.userId,
                              ),
                              builder: (context, nameSnapshot) {
                                final ownerName =
                                    nameSnapshot.data ?? tr('unknown_user');
                                return Text(
                                  ownerName,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontSize: 11,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      Text(
                        widget.envelope.name,
                        style: fontProvider.getTextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (percentage != null) ...[
                  const SizedBox(width: 12),
                  EmojiPieChart(percentage: percentage, size: 60),
                ],
              ],
            ),
            if (widget.envelope.subtitle != null &&
                widget.envelope.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: Text(
                  '"${widget.envelope.subtitle}"',
                  style: fontProvider
                      .getTextStyle(fontSize: 16)
                      .copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurface.withAlpha(179),
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      currencyFormat.format(widget.envelope.currentAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (widget.envelope.targetAmount != null) ...[
                    Flexible(
                      child: Text(
                        ' / ${currencyFormat.format(widget.envelope.targetAmount)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: theme.colorScheme.onSurface.withAlpha(179),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.isMultiSelectMode) {
      return GestureDetector(
        onTap: widget.onTap,
        // REMOVED: onLongPress in multi-select mode (only tap to toggle)
        child: tileContent,
      );
    }

    return GestureDetector(
      onHorizontalDragEnd: (details) async {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity!.abs() > 300) {
            // Swipe logic
            _toggleReveal();
          }
        }
      },
      onTap: () {
        if (_isRevealed) {
          _hideButtons();
        } else {
          widget.onTap?.call();
        }
      },
      // REMOVED: onLongPress in normal mode (use FAB to enter selection mode)
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
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
                child: tileContent,
              );
            },
          ),
        ],
      ),
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