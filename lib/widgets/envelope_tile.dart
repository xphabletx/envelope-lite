import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/envelope.dart';
import '../services/envelope_repo.dart';
import 'emoji_pie_chart.dart';
import 'quick_action_modal.dart';
import '../models/transaction.dart';

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
      end: const Offset(-0.45, 0),
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(EnvelopeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update local state if envelope data changes
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

  Future<void> _pickEmoji() async {
    final controller = TextEditingController(text: _customEmoji ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose emoji'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tap the box below and select an emoji from your keyboard',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 60),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                onChanged: (value) {
                  if (value.characters.length > 1) {
                    controller.text = value.characters.first;
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: controller.text.length),
                    );
                  }
                },
                onSubmitted: (value) {
                  Navigator.pop(context);
                  final emoji = value.characters.isEmpty
                      ? null
                      : value.characters.first;
                  setState(() => _customEmoji = emoji);
                  widget.repo.updateEnvelope(
                    envelopeId: widget.envelope.id,
                    emoji: emoji,
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _customEmoji = null);
              widget.repo.updateEnvelope(
                envelopeId: widget.envelope.id,
                emoji: null,
              );
            },
            child: const Text('Remove'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final emoji = controller.text.characters.isEmpty
                  ? null
                  : controller.text.characters.first;
              setState(() => _customEmoji = emoji);
              widget.repo.updateEnvelope(
                envelopeId: widget.envelope.id,
                emoji: emoji,
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _editSubtitle() async {
    final controller = TextEditingController(text: _subtitle ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add subtitle'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g., "Weekly shopping"',
            border: OutlineInputBorder(),
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
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

    final isMyEnvelope = widget.envelope.userId == widget.repo.currentUserId;
    final showOwnerLabel = widget.repo.inWorkspace && !isMyEnvelope;

    double? percentage;
    if (widget.envelope.targetAmount != null &&
        widget.envelope.targetAmount! > 0) {
      percentage =
          (widget.envelope.currentAmount / widget.envelope.targetAmount!).clamp(
            0.0,
            1.0,
          );
    }

    // Main tile content
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
                      if (showOwnerLabel)
                        FutureBuilder<String>(
                          future: widget.repo.getUserDisplayName(
                            widget.envelope.userId,
                          ),
                          builder: (context, snapshot) {
                            final ownerName = snapshot.data ?? 'Unknown';
                            return Text(
                              ownerName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontSize: 11,
                              ),
                            );
                          },
                        ),
                      Text(
                        widget.envelope.name,
                        style: GoogleFonts.caveat(
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
                    style: GoogleFonts.caveat(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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

    // If multi-select mode is active, disable swipe
    if (widget.isMultiSelectMode) {
      return GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: tileContent,
      );
    }

    // Otherwise, wrap in swipeable stack with action buttons
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity!.abs() > 300) {
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
          // Background action buttons
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
          // Foreground sliding tile
          SlideTransition(position: _slideAnimation, child: tileContent),
        ],
      ),
    );
  }
}

// Circular action button for swipe actions
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
