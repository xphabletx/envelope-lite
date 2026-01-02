// lib/screens/groups_home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../services/envelope_repo.dart';
import '../services/group_repo.dart';
import '../services/workspace_helper.dart';
import '../widgets/group_editor.dart' as editor;
import '../widgets/partner_badge.dart';
import 'envelope/envelopes_detail_screen.dart';
import '../services/localization_service.dart';
import '../providers/font_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/time_machine_provider.dart';
import '../theme/app_themes.dart';
import '../screens/pay_day/pay_day_amount_screen.dart';
import '../services/account_repo.dart';
import '../widgets/tutorial_wrapper.dart';
import '../widgets/time_machine_indicator.dart';
import '../data/tutorial_sequences.dart';
import '../utils/responsive_helper.dart';
import '../widgets/budget/auto_fill_list_screen.dart';
import 'envelope/multi_target_screen.dart';
import 'stats_history_screen.dart';

class GroupsHomeScreen extends StatefulWidget {
  const GroupsHomeScreen({
    super.key,
    required this.repo,
    required this.groupRepo,
    this.initialBinderId,
  });

  final EnvelopeRepo repo;
  final GroupRepo groupRepo;
  final String? initialBinderId; // Optional: scroll to this binder on load

  @override
  State<GroupsHomeScreen> createState() => _GroupsHomeScreenState();
}

class _GroupsHomeScreenState extends State<GroupsHomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _mineOnly = false;
  String _sortBy = 'name';
  bool _hasScrolledToInitialBinder = false;

  Map<String, dynamic> _statsFor(EnvelopeGroup g, List<Envelope> envs, TimeMachineProvider timeMachine) {
    final inGroup = envs.where((e) => e.groupId == g.id).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    // Apply Time Machine projections if active
    final projectedEnvelopes = inGroup.map((e) => timeMachine.getProjectedEnvelope(e)).toList();
    final totSaved = projectedEnvelopes.fold(0.0, (s, e) => s + e.currentAmount);

    debugPrint('[GroupsHome] Binder ${g.name} total: $totSaved (${inGroup.length} envelopes, TimeMachine: ${timeMachine.isActive})');

    return {'totalSaved': totSaved, 'envelopes': projectedEnvelopes};
  }

  Future<void> _openGroupEditor(EnvelopeGroup? group) async {
    // Check Time Machine mode - block modifications
    final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);
    if (timeMachine.shouldBlockModifications()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(timeMachine.getBlockedActionMessage()),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    await editor.showGroupEditor(
      context: context,
      groupRepo: widget.groupRepo,
      envelopeRepo: widget.repo,
      group: group,
    );
  }

  BinderColorOption _getBinderColors(int colorIndex, String themeId) {
    final themeColors = ThemeBinderColors.getColorsForTheme(themeId);
    if (colorIndex >= 0 && colorIndex < themeColors.length) {
      return themeColors[colorIndex];
    }
    return themeColors.first;
  }

  List<EnvelopeGroup> _sortGroups(List<EnvelopeGroup> groups, List<Envelope> envs, TimeMachineProvider timeMachine) {
    final sorted = groups.toList();
    switch (_sortBy) {
      case 'name':
        sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'total':
        sorted.sort((a, b) {
          final valA = _statsFor(a, envs, timeMachine)['totalSaved'] as double;
          final valB = _statsFor(b, envs, timeMachine)['totalSaved'] as double;
          return valB.compareTo(valA);
        });
        break;
      case 'created':
        sorted.sort((a, b) {
          final dateA = a.createdAt ?? DateTime(2000);
          final dateB = b.createdAt ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });
        break;
    }
    return sorted;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final timeMachine = Provider.of<TimeMachineProvider>(context);
    final isWorkspace = widget.repo.inWorkspace;

    return StreamBuilder<List<Envelope>>(
      initialData: widget.repo.getEnvelopesSync(showPartnerEnvelopes: !_mineOnly),
      stream: widget.repo.envelopesStream(
        showPartnerEnvelopes: !_mineOnly,
      ),
      builder: (_, s1) {
        final envs = s1.data ?? [];
        return StreamBuilder<List<EnvelopeGroup>>(
          initialData: widget.repo.getGroupsSync(),
          stream: widget.repo.groupsStream,
          builder: (_, s2) {
            // Don't show anything until we have data from the stream
            if (!s2.hasData) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final allGroups = s2.data ?? [];
            final filteredGroups = allGroups.where((g) {
              if (g.userId == widget.repo.currentUserId) return true;
              if (_mineOnly) return false;
              return g.isShared;
            }).toList();

            final groups = _sortGroups(filteredGroups, envs, timeMachine);

            // Scroll to initial binder if specified (only once)
            if (!_hasScrolledToInitialBinder && widget.initialBinderId != null && groups.isNotEmpty) {
              final initialIndex = groups.indexWhere((g) => g.id == widget.initialBinderId);
              if (initialIndex != -1) {
                _currentPage = initialIndex;
                // Use post-frame callback to ensure PageView is built before jumping
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_pageController.hasClients) {
                    _pageController.jumpToPage(initialIndex);
                  }
                });
              }
              _hasScrolledToInitialBinder = true;
            }

            if (_currentPage >= groups.length && groups.isNotEmpty) {
              _currentPage = groups.length - 1;
            }

            if (groups.isEmpty) {
              return TutorialWrapper(
                tutorialSequence: bindersTutorial,
                child: Scaffold(
                  backgroundColor: theme.scaffoldBackgroundColor,
                  appBar: AppBar(
                  title: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          final accountRepo = Provider.of<AccountRepo>(context, listen: false);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PayDayAmountScreen(
                                repo: widget.repo,
                                groupRepo: widget.groupRepo,
                                accountRepo: accountRepo,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.monetization_on, size: 20),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            tr('home_pay_day_button'),
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
                    // Time Machine Indicator at the top
                    const TimeMachineIndicator(),

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
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tr('group_create_binder'),
                      style: fontProvider.getTextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onPressed: () => _openGroupEditor(null),
                ),
              ),
            );
            }

            return TutorialWrapper(
              tutorialSequence: bindersTutorial,
              child: Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              appBar: AppBar(
                title: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr('group_binders_title'),
                    style: fontProvider.getTextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
                actions: [
                  if (isWorkspace)
                    Row(
                      children: [
                        Text(
                          'Mine Only',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Switch(
                          value: _mineOnly,
                          activeTrackColor: theme.colorScheme.primary,
                          onChanged: (val) => setState(() => _mineOnly = val),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  PopupMenuButton<String>(
                    tooltip: tr('sort_by'),
                    icon: Icon(Icons.sort, color: theme.colorScheme.primary),
                    onSelected: (value) => setState(() => _sortBy = value),
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'name', child: Text(tr('sort_az'))),
                      PopupMenuItem(value: 'total', child: const Text('Total Saved')),
                      PopupMenuItem(value: 'created', child: const Text('Date Created')),
                    ],
                  ),
                ],
              ),
              body: Column(
                children: [
                  // Time Machine Indicator at the top
                  const TimeMachineIndicator(),

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
                          '${_currentPage + 1} of ${groups.length}',
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

                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: groups.length,
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        final stats = _statsFor(group, envs, timeMachine);
                        final groupEnvelopes =
                            stats['envelopes'] as List<Envelope>;
                        final totalSaved = stats['totalSaved'] as double;

                        final binderColors = _getBinderColors(
                          group.colorIndex,
                          themeProvider.currentThemeId,
                        );

                        final isPartner =
                            group.userId != widget.repo.currentUserId;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: _BinderSpread(
                            group: group,
                            binderColors: binderColors,
                            envelopes: groupEnvelopes,
                            totalSaved: totalSaved,
                            currency: currency,
                            onEdit: () => _openGroupEditor(group),
                            theme: theme,
                            repo: widget.repo,
                            isPartner: isPartner && !_mineOnly,
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
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tr('group_create_binder'),
                    style: fontProvider.getTextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onPressed: () => _openGroupEditor(null),
              ),
            ),
            );
          },
        );
      },
    );
  }
}

class _BinderSpread extends StatefulWidget {
  final EnvelopeGroup group;
  final BinderColorOption binderColors;
  final List<Envelope> envelopes;
  final double totalSaved;
  final NumberFormat currency;
  final VoidCallback onEdit;
  final ThemeData theme;
  final EnvelopeRepo repo;
  final bool isPartner;

  const _BinderSpread({
    required this.group,
    required this.binderColors,
    required this.envelopes,
    required this.totalSaved,
    required this.currency,
    required this.onEdit,
    required this.theme,
    required this.repo,
    required this.isPartner,
  });

  @override
  State<_BinderSpread> createState() => _BinderSpreadState();
}

class _BinderSpreadState extends State<_BinderSpread> {
  int? _selectedIndex;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleEnvelopeTap(int index) async {
    // Tapping envelope - either expand or navigate to details
    if (_selectedIndex == index) {
      // Already expanded - navigate to full details
      final envelope = widget.envelopes[index];

      // Prevent access to partner's envelopes
      if (envelope.userId != widget.repo.currentUserId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You cannot view details of your partner's envelopes"),
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EnvelopeDetailScreen(
            envelopeId: envelope.id,
            repo: widget.repo,
          ),
        ),
      );
    } else {
      // Not expanded - expand it
      setState(() {
        _selectedIndex = index;
      });

      // Scroll the tapped envelope to the top
      final itemHeight = 53.0; // Envelope item height + spacing
      final scrollPosition = index * itemHeight;

      await _scrollController.animateTo(
        scrollPosition,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _toggleExpand(int index) {
    setState(() {
      if (_selectedIndex == index) {
        // Already expanded - collapse
        _selectedIndex = null;
      } else {
        // Not expanded - expand
        _selectedIndex = index;
      }
    });
  }

  Widget _buildStandardChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String amount,
    required VoidCallback onTap,
    required FontProvider fontProvider,
    required bool isLandscape,
  }) {
    final iconSize = isLandscape ? 12.0 : 14.0;
    final labelFontSize = isLandscape ? 9.0 : 10.0;
    final amountFontSize = isLandscape ? 13.0 : 16.0;
    final hintFontSize = isLandscape ? 8.0 : 9.0;
    final horizontalPadding = isLandscape ? 10.0 : 12.0;
    final verticalPadding = isLandscape ? 8.0 : 10.0;
    final spacingBetween = isLandscape ? 4.0 : 6.0;
    final hintSpacing = isLandscape ? 3.0 : 4.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
        decoration: BoxDecoration(
          color: widget.binderColors.binderColor.withAlpha(26),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: widget.binderColors.binderColor.withAlpha(77),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: widget.binderColors.binderColor,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.bold,
                      color: widget.binderColors.binderColor,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacingBetween),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                amount,
                style: fontProvider.getTextStyle(
                  fontSize: amountFontSize,
                  fontWeight: FontWeight.bold,
                  color: widget.binderColors.envelopeTextColor,
                ),
              ),
            ),
            SizedBox(height: hintSpacing),
            Text(
              'Tap for details',
              style: TextStyle(
                fontSize: hintFontSize,
                color: widget.binderColors.envelopeTextColor.withAlpha(128),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChips(BuildContext context, FontProvider fontProvider, bool isLandscape) {
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    // Calculate auto-fill stats
    final autoFillEnvelopes = widget.envelopes.where((e) => e.autoFillEnabled && (e.autoFillAmount ?? 0) > 0).toList();
    final autoFillTotal = autoFillEnvelopes.fold(0.0, (sum, e) => sum + (e.autoFillAmount ?? 0));

    // Calculate target stats
    final targetEnvelopes = widget.envelopes.where((e) => e.targetAmount != null && e.targetAmount! > 0).toList();
    final totalTargetAmount = targetEnvelopes.fold(0.0, (sum, e) => sum + (e.targetAmount ?? 0));

    // Build list of chips to show
    final chips = <Widget>[];

    // Always show Binder Total
    chips.add(
      _buildStandardChip(
        context: context,
        icon: Icons.account_balance_wallet,
        label: tr('group_binder_total'),
        amount: currency.format(widget.totalSaved),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StatsHistoryScreen(
                repo: widget.repo,
                initialGroupIds: {widget.group.id},
                title: '${widget.group.name} Stats',
              ),
            ),
          );
        },
        fontProvider: fontProvider,
        isLandscape: isLandscape,
      ),
    );

    // Auto-fill Chip
    if (autoFillEnvelopes.isNotEmpty) {
      chips.add(
        _buildStandardChip(
          context: context,
          icon: Icons.autorenew,
          label: 'Auto Fill',
          amount: currency.format(autoFillTotal),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AutoFillListScreen(
                  envelopeRepo: widget.repo,
                  groupRepo: GroupRepo(widget.repo),
                  accountRepo: AccountRepo(widget.repo),
                  groupId: widget.group.id,
                ),
              ),
            );
          },
          fontProvider: fontProvider,
          isLandscape: isLandscape,
        ),
      );
    }

    // Target Chip
    if (targetEnvelopes.isNotEmpty) {
      chips.add(
        _buildStandardChip(
          context: context,
          icon: Icons.track_changes,
          label: 'Target',
          amount: currency.format(totalTargetAmount),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MultiTargetScreen(
                  envelopeRepo: widget.repo,
                  groupRepo: GroupRepo(widget.repo),
                  accountRepo: AccountRepo(widget.repo),
                  initialGroupId: widget.group.id,
                  mode: TargetScreenMode.binderFiltered,
                  title: '${widget.group.name} Targets',
                ),
              ),
            );
          },
          fontProvider: fontProvider,
          isLandscape: isLandscape,
        ),
      );
    }

    // Space chips vertically to make use of available space
    final chipSpacing = isLandscape ? 6.0 : 8.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < chips.length; i++) ...[
          chips[i],
          if (i < chips.length - 1) SizedBox(height: chipSpacing),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final responsive = context.responsive;
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    // Landscape-specific sizing
    final horizontalPadding = responsive.isLandscape ? 8.0 : 16.0;
    final verticalPadding = responsive.isLandscape ? 8.0 : 16.0;
    final spineGap = responsive.isLandscape ? 16.0 : 24.0;
    final pagePadding = responsive.isLandscape ? 10.0 : 16.0;
    final iconSize = responsive.isLandscape ? 36.0 : 48.0;
    final headerFontSize = responsive.isLandscape ? 14.0 : 18.0;
    final settingsButtonSize = responsive.isLandscape ? 28.0 : 32.0;
    final settingsIconSize = responsive.isLandscape ? 16.0 : 18.0;

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: widget.theme.colorScheme.shadow.withAlpha(51),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // LAYER 1: The "Leather" Binder Cover (Custom Paint)
          Positioned.fill(
            child: CustomPaint(
              painter: _OpenBinderPainter(
                color: widget.binderColors.binderColor,
                spineWidth: responsive.isLandscape ? 40.0 : 60.0,
              ),
            ),
          ),

          // LAYER 2: The "Paper" Pages
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Row(
              children: [
                // === LEFT PAGE (ENVELOPES) ===
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.binderColors.paperColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                        topRight: Radius.circular(2),
                        bottomRight: Radius.circular(2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(26),
                          blurRadius: 4,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                    child: widget.envelopes.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.mail_outline,
                                  size: responsive.isLandscape ? 32 : 48,
                                  color: Colors.grey.shade400,
                                ),
                                SizedBox(height: responsive.isLandscape ? 8 : 12),
                                Text(
                                  tr('home_no_envelopes'),
                                  style: fontProvider.getTextStyle(
                                    fontSize: responsive.isLandscape ? 12 : 16,
                                    color: Colors.grey.shade500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : Padding(
                            padding: EdgeInsets.all(pagePadding),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.mail,
                                      size: responsive.isLandscape ? 14 : 16,
                                      color: widget.binderColors.binderColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      tr('home_envelopes_tab'),
                                      style: fontProvider.getTextStyle(
                                        fontSize: responsive.isLandscape ? 12 : 14,
                                        fontWeight: FontWeight.bold,
                                        color: widget.binderColors.envelopeTextColor
                                            .withAlpha(179),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: responsive.isLandscape ? 8 : 12),
                                Expanded(
                                  child: _InfiniteEnvelopeList(
                                    envelopes: widget.envelopes,
                                    selectedIndex: _selectedIndex,
                                    binderColors: widget.binderColors,
                                    currency: widget.currency,
                                    onEnvelopeTap: _handleEnvelopeTap,
                                    onToggleExpand: _toggleExpand,
                                    scrollController: _scrollController,
                                    isLandscape: responsive.isLandscape,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),

                // === SPINE GAP ===
                SizedBox(width: spineGap),

                // === RIGHT PAGE (INFO) ===
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.binderColors.paperColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(2),
                        bottomLeft: Radius.circular(2),
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(26),
                          blurRadius: 4,
                          offset: const Offset(-1, 1),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(pagePadding),
                    child: Stack(
                      children: [
                        // Settings Cog in top-right
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: widget.onEdit,
                            child: Container(
                              width: settingsButtonSize,
                              height: settingsButtonSize,
                              decoration: BoxDecoration(
                                color: widget.binderColors.binderColor.withAlpha(26),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: widget.binderColors.binderColor.withAlpha(77),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.settings,
                                size: settingsIconSize,
                                color: widget.binderColors.binderColor,
                              ),
                            ),
                          ),
                        ),
                        // Main content - use Column with spacers to distribute vertically
                        Positioned.fill(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                            // Binder Header
                            Column(
                              children: [
                                Container(
                                  width: iconSize,
                                  height: iconSize,
                                  decoration: BoxDecoration(
                                    color: widget.binderColors.paperColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: widget.binderColors.binderColor,
                                      width: responsive.isLandscape ? 2 : 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: widget.binderColors.binderColor
                                            .withAlpha(51),
                                        blurRadius: responsive.isLandscape ? 4 : 8,
                                        offset: Offset(0, responsive.isLandscape ? 2 : 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: widget.group.getIconWidget(
                                      theme,
                                      size: responsive.isLandscape ? 18 : 22,
                                    ),
                                  ),
                                ),
                                SizedBox(height: responsive.isLandscape ? 2 : 4),
                                Text(
                                  widget.group.name,
                                  style: fontProvider.getTextStyle(
                                    fontSize: headerFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: widget.binderColors.envelopeTextColor,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),

                            const Spacer(),

                            // Info Chips (Binder Total, Auto-fill, Target) - spaced out
                            _buildInfoChips(context, fontProvider, responsive.isLandscape),

                            const Spacer(),

                            // Partner Badge
                            if (widget.isPartner)
                              FutureBuilder<String>(
                                future: WorkspaceHelper.getUserDisplayName(
                                  widget.group.userId,
                                  widget.repo.currentUserId,
                                ),
                                builder: (context, nameSnapshot) {
                                  return PartnerBadge(
                                    partnerName: nameSnapshot.data ?? 'Partner',
                                    size: PartnerBadgeSize.small,
                                  );
                                },
                              )
                            else
                              const SizedBox.shrink(),
                          ],
                        ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Infinite scrollable envelope list with inline detail expansion
class _InfiniteEnvelopeList extends StatelessWidget {
  final List<Envelope> envelopes;
  final int? selectedIndex;
  final BinderColorOption binderColors;
  final NumberFormat currency;
  final Function(int) onEnvelopeTap;
  final Function(int) onToggleExpand;
  final ScrollController scrollController;
  final bool isLandscape;

  const _InfiniteEnvelopeList({
    required this.envelopes,
    required this.selectedIndex,
    required this.binderColors,
    required this.currency,
    required this.onEnvelopeTap,
    required this.onToggleExpand,
    required this.scrollController,
    required this.isLandscape,
  });

  @override
  Widget build(BuildContext context) {
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final theme = Theme.of(context);
    final timeMachine = Provider.of<TimeMachineProvider>(context);

    // Landscape-specific sizing
    final itemHeight = isLandscape ? 38.0 : 45.0;
    final horizontalPadding = isLandscape ? 8.0 : 10.0;
    final iconSize = isLandscape ? 16.0 : 18.0;
    final fontSize = isLandscape ? 12.0 : 14.0;
    final expandIconSize = isLandscape ? 14.0 : 16.0;
    final bottomPadding = isLandscape ? 6.0 : 8.0;

    return ListView.builder(
      controller: scrollController,
      itemCount: envelopes.length,
      itemBuilder: (context, index) {
        final envelope = envelopes[index];
        final isSelected = selectedIndex == index;

        return Column(
          children: [
            // Envelope Item
            Padding(
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: GestureDetector(
                onTap: () => onEnvelopeTap(index),
                child: Container(
                  height: itemHeight,
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  decoration: BoxDecoration(
                    color: binderColors.paperColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? binderColors.envelopeBorderColor
                          : binderColors.envelopeBorderColor.withAlpha(77),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: binderColors.binderColor.withAlpha(
                          isSelected ? 51 : 13,
                        ),
                        blurRadius: isSelected ? 4 : 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      envelope.getIconWidget(theme, size: iconSize),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          envelope.name,
                          style: fontProvider.getTextStyle(
                            fontSize: fontSize,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: binderColors.envelopeTextColor.withAlpha(
                              isSelected ? 255 : 204,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onToggleExpand(index),
                        child: Padding(
                          padding: EdgeInsets.all(isLandscape ? 6.0 : 8.0),
                          child: Icon(
                            isSelected ? Icons.expand_less : Icons.expand_more,
                            size: expandIconSize,
                            color: binderColors.binderColor.withAlpha(128),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Inline Envelope Details (when selected)
            if (isSelected)
              _InlineEnvelopeDetail(
                envelope: envelope,
                binderColors: binderColors,
                currency: currency,
                fontProvider: fontProvider,
                timeMachine: timeMachine,
                onTap: () => onEnvelopeTap(index),
                isLandscape: isLandscape,
              ),
          ],
        );
      },
    );
  }
}

// Inline envelope detail widget
class _InlineEnvelopeDetail extends StatelessWidget {
  final Envelope envelope;
  final BinderColorOption binderColors;
  final NumberFormat currency;
  final FontProvider fontProvider;
  final TimeMachineProvider timeMachine;
  final VoidCallback onTap;
  final bool isLandscape;

  const _InlineEnvelopeDetail({
    required this.envelope,
    required this.binderColors,
    required this.currency,
    required this.fontProvider,
    required this.timeMachine,
    required this.onTap,
    required this.isLandscape,
  });

  @override
  Widget build(BuildContext context) {
    // Apply time machine projection if active
    final projectedEnvelope = timeMachine.getProjectedEnvelope(envelope);

    // Landscape-specific sizing
    final iconSize = isLandscape ? 12.0 : 14.0;
    final mainFontSize = isLandscape ? 12.0 : 14.0;
    final detailFontSize = isLandscape ? 10.0 : 12.0;
    final hintFontSize = isLandscape ? 8.0 : 9.0;
    final padding = isLandscape ? 10.0 : 12.0;
    final bottomMargin = isLandscape ? 6.0 : 8.0;
    final itemSpacing = isLandscape ? 8.0 : 10.0;
    final hintSpacing = isLandscape ? 8.0 : 10.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: bottomMargin, left: 8, right: 8),
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: binderColors.binderColor.withAlpha(13),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: binderColors.binderColor.withAlpha(51),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Current Amount
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                size: iconSize,
                color: binderColors.binderColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    currency.format(projectedEnvelope.currentAmount),
                    style: fontProvider.getTextStyle(
                      fontSize: mainFontSize,
                      fontWeight: FontWeight.bold,
                      color: binderColors.envelopeTextColor,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Auto-fill Amount (if applicable)
          if (envelope.autoFillEnabled && (envelope.autoFillAmount ?? 0) > 0) ...[
            SizedBox(height: itemSpacing),
            Row(
              children: [
                Icon(
                  Icons.autorenew,
                  size: iconSize,
                  color: binderColors.binderColor,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      currency.format(envelope.autoFillAmount),
                      style: fontProvider.getTextStyle(
                        fontSize: detailFontSize,
                        fontWeight: FontWeight.bold,
                        color: binderColors.envelopeTextColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Target Amount (if applicable)
          if (envelope.targetAmount != null && envelope.targetAmount! > 0) ...[
            SizedBox(height: itemSpacing),
            Row(
              children: [
                Icon(
                  Icons.track_changes,
                  size: iconSize,
                  color: binderColors.binderColor,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      currency.format(envelope.targetAmount),
                      style: fontProvider.getTextStyle(
                        fontSize: detailFontSize,
                        fontWeight: FontWeight.bold,
                        color: binderColors.envelopeTextColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Target Date (if applicable)
          if (envelope.targetDate != null) ...[
            SizedBox(height: itemSpacing),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: iconSize,
                  color: binderColors.binderColor,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      DateFormat('MMM d, yyyy').format(envelope.targetDate!),
                      style: fontProvider.getTextStyle(
                        fontSize: detailFontSize,
                        fontWeight: FontWeight.bold,
                        color: binderColors.envelopeTextColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Tap hint
          SizedBox(height: hintSpacing),
          Center(
            child: Text(
              'Tap again for full details',
              style: TextStyle(
                fontSize: hintFontSize,
                color: binderColors.envelopeTextColor.withAlpha(128),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

// --- PAINTER: OPEN BINDER LOOK ---
class _OpenBinderPainter extends CustomPainter {
  final Color color;
  final double spineWidth;

  _OpenBinderPainter({
    required this.color,
    this.spineWidth = 60.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hsl = HSLColor.fromColor(color);
    final baseColor = color;
    final darkerColor =
        hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    final lighterColor =
        hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(24),
    );

    // 1. Draw Main Body (Leather Texture Effect)
    final bodyPaint = Paint()..color = baseColor;
    canvas.drawRRect(rrect, bodyPaint);

    // 2. Draw Spine (3D Cylinder Effect)
    final spineRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: spineWidth,
      height: size.height,
    );

    final spineGradient = LinearGradient(
      colors: [baseColor, darkerColor, lighterColor, darkerColor, baseColor],
      stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
    );

    final spinePaint = Paint()..shader = spineGradient.createShader(spineRect);

    // Clip the spine to the rounded corners of the binder
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(spineRect, spinePaint);

    // Add vertical lines to spine to simulate ridges
    final linePaint = Paint()
      ..color = Colors.black.withAlpha(26)
      ..strokeWidth = 1;

    final ridgeOffset = spineWidth / 3;
    canvas.drawLine(
      Offset(size.width / 2 - ridgeOffset, 0),
      Offset(size.width / 2 - ridgeOffset, size.height),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width / 2 + ridgeOffset, 0),
      Offset(size.width / 2 + ridgeOffset, size.height),
      linePaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
