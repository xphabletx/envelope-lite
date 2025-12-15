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
import '../services/workspace_helper.dart';
import 'emoji_picker_sheet.dart';
// TUTORIAL IMPORT
import '../services/tutorial_controller.dart';

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
  String? _customEmoji;
  String? _subtitle;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  bool _isRevealed = false;

  static const double _actionButtonsWidth = 164.0;

  @override
  void initState() {
    super.initState();
    _customEmoji = widget.envelope.emoji;
    _subtitle = widget.envelope.subtitle;

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
  void didUpdateWidget(EnvelopeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.envelope.emoji != widget.envelope.emoji) {
      _customEmoji = widget.envelope.emoji;
    }
    if (oldWidget.envelope.subtitle != widget.envelope.subtitle) {
      _subtitle = widget.envelope.subtitle;
    }
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

  // FIXED: Removed defaultEmoji parameter
  Future<void> _pickEmoji() async {
    final result = await showEmojiPickerSheet(
      context: context,
      initialEmoji: _customEmoji,
    );

    if (result != null) {
      setState(() {
        // If result is empty string, that means reset/clear
        _customEmoji = result.isEmpty ? null : result;
      });

      await widget.repo.updateEnvelope(
        envelopeId: widget.envelope.id,
        emoji: result.isEmpty ? null : result,
      );
    }
  }

  Future<void> _editSubtitle() async {
    final controller = TextEditingController(text: _subtitle ?? '');
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          tr('envelope_add_subtitle'),
          style: fontProvider.getTextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          style: fontProvider
              .getTextStyle(fontSize: 18)
              .copyWith(fontStyle: FontStyle.italic),
          decoration: InputDecoration(
            hintText: tr('envelope_subtitle_hint'),
            hintStyle: fontProvider
                .getTextStyle(fontSize: 16, color: Colors.grey)
                .copyWith(fontStyle: FontStyle.italic),
            border: const OutlineInputBorder(),
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tr('clear'),
                style: fontProvider.getTextStyle(fontSize: 18),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tr('cancel'),
                style: fontProvider.getTextStyle(fontSize: 18),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tr('save'),
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() => _subtitle = result.isEmpty ? null : result);
      await widget.repo.updateEnvelope(
        envelopeId: widget.envelope.id,
        subtitle: result.isEmpty ? null : result,
      );
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
    final currencyFormat = NumberFormat.currency(symbol: '£');
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
            ? theme.colorScheme.primary.withValues(alpha: 0.2)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
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
                GestureDetector(
                  onTap: _pickEmoji,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _customEmoji ?? '📨',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
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
            if (_subtitle != null && _subtitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: GestureDetector(
                  onTap: _editSubtitle,
                  child: Text(
                    '"$_subtitle"',
                    style: fontProvider
                        .getTextStyle(fontSize: 16)
                        .copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: Row(
                children: [
                  Text(
                    currencyFormat.format(widget.envelope.currentAmount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  if (widget.envelope.targetAmount != null) ...[
                    Text(
                      ' / ${currencyFormat.format(widget.envelope.targetAmount)}',
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
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
        onLongPress: widget.onLongPress,
        child: tileContent,
      );
    }

    return GestureDetector(
      onHorizontalDragEnd: (details) async {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity!.abs() > 300) {
            // TUTORIAL LOGIC
            // Check if we need to advance the tutorial on swipe
            final tutorialController = Provider.of<TutorialController>(
              context,
              listen: false,
            );

            // UPDATED: Use swipeGesture (new step name) and show completion dialog
            if (tutorialController.isActive &&
                tutorialController.currentStep == TutorialStep.swipeGesture) {
              // Advance tutorial
              await tutorialController.nextStep();

              // Show completion dialog
              if (context.mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) => AlertDialog(
                    title: Row(
                      children: const [
                        Text('Tutorial Complete! '),
                        Text('🎉', style: TextStyle(fontSize: 24)),
                      ],
                    ),
                    content: const Text(
                      'You\'re all set! Feel free to explore Envelope Lite.\n\n'
                      'Need help? Check Settings → Help anytime!',
                    ),
                    actions: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          tutorialController.complete();
                        },
                        child: const Text('Get Started!'),
                      ),
                    ],
                  ),
                );
              }
            }

            // Normal swipe logic
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
      onLongPress: widget.onLongPress,
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
            color: primaryColor.withValues(alpha: 0.15),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Icon(icon, color: primaryColor, size: 22),
        ),
      ),
    );
  }
}
