// lib/screens/groups_home_screen.dart
// FONT PROVIDER INTEGRATED: All GoogleFonts.caveat() replaced with FontProvider
// All button text wrapped in FittedBox to prevent wrapping

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // NEW IMPORT
import 'package:google_fonts/google_fonts.dart'; // Kept as requested
import 'package:intl/intl.dart';

import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../services/envelope_repo.dart';
import '../services/group_repo.dart';
import '../services/workspace_helper.dart';
import '../widgets/group_editor.dart' as editor;
import '../widgets/partner_visibility_toggle.dart';
import '../widgets/partner_badge.dart';
import 'group_detail_screen.dart';
import 'envelope/envelopes_detail_screen.dart';
import 'pay_day_preview_screen.dart';
import '../services/localization_service.dart';
import '../providers/font_provider.dart'; // NEW IMPORT

class GroupsHomeScreen extends StatefulWidget {
  const GroupsHomeScreen({
    super.key,
    required this.repo,
    required this.groupRepo,
  });

  final EnvelopeRepo repo;
  final GroupRepo groupRepo;

  @override
  State<GroupsHomeScreen> createState() => _GroupsHomeScreenState();
}

class _GroupsHomeScreenState extends State<GroupsHomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _showPartnerBinders = true; // NEW: Partner visibility toggle

  Map<String, dynamic> _statsFor(EnvelopeGroup g, List<Envelope> envs) {
    final inGroup = envs.where((e) => e.groupId == g.id).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final totSaved = inGroup.fold(0.0, (s, e) => s + e.currentAmount);

    return {'totalSaved': totSaved, 'envelopes': inGroup};
  }

  void _openGroupDetail(EnvelopeGroup group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupDetailScreen(
          group: group,
          groupRepo: widget.groupRepo,
          envelopeRepo: widget.repo,
        ),
      ),
    );
  }

  Future<void> _openGroupEditor(EnvelopeGroup? group) async {
    await editor.showGroupEditor(
      context: context,
      groupRepo: widget.groupRepo,
      envelopeRepo: widget.repo,
      group: group,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'en_GB');
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return StreamBuilder<List<Envelope>>(
      stream: widget.repo.envelopesStream(
        showPartnerEnvelopes: _showPartnerBinders,
      ),
      builder: (_, s1) {
        final envs = s1.data ?? [];
        return StreamBuilder<List<EnvelopeGroup>>(
          stream: widget.repo.groupsStream,
          builder: (_, s2) {
            // Filter groups based on partner visibility toggle
            final allGroups = s2.data ?? [];
            final groups = allGroups.where((g) {
              // Always show my groups
              if (g.userId == widget.repo.currentUserId) return true;
              // Show partner groups only if toggle is on AND group is shared
              if (!_showPartnerBinders) return false;
              return (g.isShared ?? true);
            }).toList();

            if (groups.isEmpty) {
              return Scaffold(
                backgroundColor: theme.scaffoldBackgroundColor,
                appBar: AppBar(
                  title: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PayDayPreviewScreen(
                                repo: widget.repo,
                                groupRepo: widget.groupRepo,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.monetization_on, size: 20),
                        label: FittedBox(
                          // UPDATED: FittedBox
                          fit: BoxFit.scaleDown,
                          child: Text(
                            tr('home_pay_day_button'),
                            // UPDATED: FontProvider
                            style: fontProvider.getTextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: theme.scaffoldBackgroundColor,
                  elevation: 0,
                ),
                body: Column(
                  children: [
                    // Partner visibility toggle (only in workspace)
                    if (widget.repo.inWorkspace)
                      PartnerVisibilityToggle(
                        isEnvelopes: false,
                        onChanged: (show) {
                          setState(() => _showPartnerBinders = show);
                        },
                      ),

                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_off_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              tr('group_no_binders'),
                              // UPDATED: FontProvider
                              style: fontProvider.getTextStyle(
                                fontSize: 28,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr('group_create_first_binder'),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                floatingActionButton: FloatingActionButton.extended(
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: FittedBox(
                    // UPDATED: FittedBox
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tr('group_create_binder'),
                      // UPDATED: FontProvider
                      style: fontProvider.getTextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onPressed: () => _openGroupEditor(null),
                ),
              );
            }

            return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              appBar: AppBar(
                title: Text(
                  tr('group_binders_title'),
                  // UPDATED: FontProvider
                  style: fontProvider.getTextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
              ),
              body: Column(
                children: [
                  // Partner visibility toggle (only in workspace)
                  if (widget.repo.inWorkspace)
                    PartnerVisibilityToggle(
                      isEnvelopes: false,
                      onChanged: (show) {
                        setState(() => _showPartnerBinders = show);
                      },
                    ),

                  // Page indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.chevron_left,
                            color: _currentPage > 0
                                ? theme.colorScheme.primary
                                : Colors.grey.shade400,
                          ),
                          onPressed: _currentPage > 0
                              ? () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              : null,
                        ),
                        Text(
                          '${_currentPage + 1} of ${groups.length}', // Interpolation kept
                          // UPDATED: FontProvider
                          style: fontProvider.getTextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.chevron_right,
                            color: _currentPage < groups.length - 1
                                ? theme.colorScheme.primary
                                : Colors.grey.shade400,
                          ),
                          onPressed: _currentPage < groups.length - 1
                              ? () {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),

                  // Binder page view
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: groups.length,
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        final stats = _statsFor(group, envs);
                        final groupEnvelopes =
                            stats['envelopes'] as List<Envelope>;
                        final totalSaved = stats['totalSaved'] as double;

                        final groupColor = GroupColors.getThemedColor(
                          group.colorName,
                          theme.colorScheme,
                        );
                        final textColor = GroupColors.getContrastingTextColor(
                          groupColor,
                        );
                        final leftPageColor = GroupColors.getLeftPageColor(
                          groupColor,
                        );
                        final rightPageColor = GroupColors.getRightPageColor(
                          groupColor,
                        );
                        final envelopeCardColor =
                            GroupColors.getEnvelopeCardColor(groupColor);
                        final accentTextColor = GroupColors.getAccentTextColor(
                          groupColor,
                        );

                        // Check if this is a partner's binder
                        final isPartner =
                            group.userId != widget.repo.currentUserId;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Stack(
                            children: [
                              _BinderSpread(
                                group: group,
                                groupColor: groupColor,
                                textColor: textColor,
                                leftPageColor: leftPageColor,
                                rightPageColor: rightPageColor,
                                envelopeCardColor: envelopeCardColor,
                                accentTextColor: accentTextColor,
                                envelopes: groupEnvelopes,
                                totalSaved: totalSaved,
                                currency: currency,
                                onEdit: () => _openGroupEditor(group),
                                onViewDetails: () => _openGroupDetail(group),
                                theme: theme,
                                repo: widget.repo,
                              ),
                              // Partner badge
                              if (isPartner)
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: FutureBuilder<String>(
                                    future: WorkspaceHelper.getUserDisplayName(
                                      group.userId,
                                      widget.repo.currentUserId,
                                    ),
                                    builder: (context, snapshot) {
                                      return PartnerBadge(
                                        partnerName: snapshot.data ?? 'Partner',
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: FittedBox(
                  // UPDATED: FittedBox
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tr('group_create_binder'),
                    // UPDATED: FontProvider
                    style: fontProvider.getTextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onPressed: () => _openGroupEditor(null),
              ),
            );
          },
        );
      },
    );
  }
}

// Binder spread widget
class _BinderSpread extends StatefulWidget {
  final EnvelopeGroup group;
  final Color groupColor;
  final Color textColor;
  final Color leftPageColor;
  final Color rightPageColor;
  final Color envelopeCardColor;
  final Color accentTextColor;
  final List<Envelope> envelopes;
  final double totalSaved;
  final NumberFormat currency;
  final VoidCallback onEdit;
  final VoidCallback onViewDetails;
  final ThemeData theme;
  final EnvelopeRepo repo;

  const _BinderSpread({
    required this.group,
    required this.groupColor,
    required this.textColor,
    required this.leftPageColor,
    required this.rightPageColor,
    required this.envelopeCardColor,
    required this.accentTextColor,
    required this.envelopes,
    required this.totalSaved,
    required this.currency,
    required this.onEdit,
    required this.onViewDetails,
    required this.theme,
    required this.repo,
  });

  @override
  State<_BinderSpread> createState() => _BinderSpreadState();
}

class _BinderSpreadState extends State<_BinderSpread> {
  int? _selectedIndex;
  int _tapCount = 0;

  void _handleEnvelopeTap(int index) {
    if (_selectedIndex == index) {
      _tapCount++;
      if (_tapCount == 2) {
        // Second tap - open detail
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EnvelopeDetailScreen(
              envelopeId: widget.envelopes[_selectedIndex!].id,
              repo: widget.repo,
            ),
          ),
        );
        // Reset
        setState(() {
          _tapCount = 0;
        });
      }
    } else {
      // First tap or different envelope
      setState(() {
        _selectedIndex = index;
        _tapCount = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedEnvelope =
        _selectedIndex != null && _selectedIndex! < widget.envelopes.length
        ? widget.envelopes[_selectedIndex!]
        : null;
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        color: widget.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: widget.groupColor.withAlpha(51),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            // LEFT PAGE - Dynamic envelope stack
            Expanded(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(color: widget.leftPageColor),
                child: widget.envelopes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.mail_outline,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              tr('home_no_envelopes'),
                              // UPDATED: FontProvider
                              style: fontProvider.getTextStyle(
                                fontSize: 20,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.mail,
                                  size: 16,
                                  color: widget.accentTextColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tr('home_envelopes_tab'),
                                  // UPDATED: FontProvider
                                  style: fontProvider.getTextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: widget.accentTextColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Dynamic fan stack
                            Expanded(
                              child: _DynamicEnvelopeStack(
                                envelopes: widget.envelopes,
                                selectedIndex: _selectedIndex,
                                groupColor: widget.groupColor,
                                envelopeCardColor: widget.envelopeCardColor,
                                accentTextColor: widget.accentTextColor,
                                currency: widget.currency,
                                theme: widget.theme,
                                onTap: _handleEnvelopeTap,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            // BINDER SPINE
            Container(
              width: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    widget.groupColor.withAlpha(77),
                    widget.groupColor.withAlpha(153),
                    widget.groupColor.withAlpha(77),
                  ],
                ),
              ),
            ),

            // RIGHT PAGE - Group info with optional selected envelope
            Expanded(
              flex: 1,
              child: Container(
                color: widget.rightPageColor,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top section
                    Column(
                      children: [
                        // Group emoji
                        Container(
                          width: 55,
                          height: 55,
                          decoration: BoxDecoration(
                            color: widget.envelopeCardColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.groupColor,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              widget.group.emoji ?? '📁',
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Group name
                        Text(
                          widget.group.name,
                          // UPDATED: FontProvider
                          style: fontProvider.getTextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: widget.accentTextColor,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),

                        // Group total (clean, no box)
                        Column(
                          children: [
                            Text(
                              tr('group_binder_total'),
                              style: TextStyle(
                                fontSize: 8,
                                color: widget.theme.colorScheme.onSurface
                                    .withAlpha(153),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.currency.format(widget.totalSaved),
                                // UPDATED: FontProvider
                                style: fontProvider.getTextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: widget.groupColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Selected envelope section (if any)
                    if (selectedEnvelope != null)
                      Column(
                        children: [
                          Divider(color: widget.groupColor.withAlpha(77)),
                          const SizedBox(height: 8),
                          Icon(
                            Icons.mail,
                            size: 20,
                            color: widget.groupColor.withAlpha(128),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            selectedEnvelope.name,
                            // UPDATED: FontProvider
                            style: fontProvider.getTextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: widget.accentTextColor,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.currency.format(
                                selectedEnvelope.currentAmount,
                              ),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: widget.groupColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tr('tap_again_for_details'),
                            style: TextStyle(
                              fontSize: 9,
                              color: widget.theme.colorScheme.onSurface
                                  .withAlpha(128),
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),

                    // Bottom section - Action buttons
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.groupColor,
                              // FIX: Use contrasting color for text/icon
                              foregroundColor:
                                  GroupColors.getContrastingTextColor(
                                    widget.groupColor,
                                  ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.edit, size: 16),
                            label: FittedBox(
                              // UPDATED: FittedBox
                              fit: BoxFit.scaleDown,
                              child: Text(
                                tr('edit'),
                                // UPDATED: FontProvider
                                style: fontProvider.getTextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            onPressed: widget.onEdit,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: widget.groupColor,
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: Icon(
                              Icons.analytics,
                              size: 16,
                              color: widget.groupColor,
                            ),
                            label: FittedBox(
                              // UPDATED: FittedBox
                              fit: BoxFit.scaleDown,
                              child: Text(
                                tr('group_history'),
                                // UPDATED: FontProvider
                                style: fontProvider.getTextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: widget.groupColor,
                                ),
                              ),
                            ),
                            onPressed: widget.onViewDetails,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dynamic envelope stack with smart overlap
class _DynamicEnvelopeStack extends StatelessWidget {
  final List<Envelope> envelopes;
  final int? selectedIndex;
  final Color groupColor;
  final Color envelopeCardColor;
  final Color accentTextColor;
  final NumberFormat currency;
  final ThemeData theme;
  final Function(int) onTap;

  const _DynamicEnvelopeStack({
    required this.envelopes,
    required this.selectedIndex,
    required this.groupColor,
    required this.envelopeCardColor,
    required this.accentTextColor,
    required this.currency,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final envelopeCount = envelopes.length;

        // Calculate dynamic spacing
        final envelopeHeight = 50.0;

        // Calculate spacing needed to fit all envelopes
        double spacing;
        if (envelopeCount == 1) {
          spacing = 0;
        } else {
          // Total height needed = first envelope full height + (remaining * peek height)
          // availableHeight = envelopeHeight + ((envelopeCount - 1) * spacing)
          // Solve for spacing
          final remainingSpace = availableHeight - envelopeHeight;
          spacing = remainingSpace / (envelopeCount - 1);

          // Clamp between reasonable values
          spacing = spacing.clamp(20.0, envelopeHeight + 8);
        }

        // Reorder: selected first, then rest
        final orderedEnvelopes = <MapEntry<int, Envelope>>[];
        if (selectedIndex != null && selectedIndex! < envelopes.length) {
          orderedEnvelopes.add(
            MapEntry(selectedIndex!, envelopes[selectedIndex!]),
          );
        }
        for (var i = 0; i < envelopes.length; i++) {
          if (i != selectedIndex) {
            orderedEnvelopes.add(MapEntry(i, envelopes[i]));
          }
        }

        return Stack(
          children: orderedEnvelopes.asMap().entries.map((entry) {
            final displayIndex = entry.key;
            final originalIndex = entry.value.key;
            final envelope = entry.value.value;
            final isSelected = selectedIndex == originalIndex;
            final isTop = displayIndex == 0;

            return Positioned(
              top: isTop ? 0 : displayIndex * spacing,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => onTap(originalIndex),
                child: Container(
                  height: envelopeHeight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: envelopeCardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? groupColor
                          : groupColor.withAlpha(128),
                      width: isSelected ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: groupColor.withAlpha(isSelected ? 51 : 26),
                        blurRadius: isSelected ? 6 : 3,
                        offset: Offset(0, isSelected ? 3 : 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          envelope.name.length > 14
                              ? '${envelope.name.substring(0, 14)}...'
                              : envelope.name,
                          // UPDATED: FontProvider
                          style: fontProvider.getTextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: accentTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
