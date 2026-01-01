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
import 'group_detail_screen.dart';
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
  bool _mineOnly = false;
  String _sortBy = 'name';

  // TUTORIAL KEYS
  final GlobalKey _viewHistoryButtonKey = GlobalKey();

  Map<String, dynamic> _statsFor(EnvelopeGroup g, List<Envelope> envs, TimeMachineProvider timeMachine) {
    final inGroup = envs.where((e) => e.groupId == g.id).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    // Apply Time Machine projections if active
    final projectedEnvelopes = inGroup.map((e) => timeMachine.getProjectedEnvelope(e)).toList();
    final totSaved = projectedEnvelopes.fold(0.0, (s, e) => s + e.currentAmount);

    debugPrint('[GroupsHome] Binder ${g.name} total: $totSaved (${inGroup.length} envelopes, TimeMachine: ${timeMachine.isActive})');

    return {'totalSaved': totSaved, 'envelopes': projectedEnvelopes};
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
      stream: widget.repo.envelopesStream(
        showPartnerEnvelopes: !_mineOnly,
      ),
      builder: (_, s1) {
        final envs = s1.data ?? [];
        return StreamBuilder<List<EnvelopeGroup>>(
          stream: widget.repo.groupsStream,
          builder: (_, s2) {
            final allGroups = s2.data ?? [];
            final filteredGroups = allGroups.where((g) {
              if (g.userId == widget.repo.currentUserId) return true;
              if (_mineOnly) return false;
              return g.isShared;
            }).toList();

            final groups = _sortGroups(filteredGroups, envs, timeMachine);

            if (_currentPage >= groups.length && groups.isNotEmpty) {
              _currentPage = groups.length - 1;
            }

            if (groups.isEmpty) {
              return TutorialWrapper(
                tutorialSequence: bindersTutorial,
                spotlightKeys: {
                  'view_history_button': _viewHistoryButtonKey,
                },
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
              spotlightKeys: {
                'view_history_button': _viewHistoryButtonKey,
              },
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
                            onViewDetails: () => _openGroupDetail(group),
                            theme: theme,
                            repo: widget.repo,
                            isPartner: isPartner && !_mineOnly,
                            viewHistoryButtonKey: index == 0 ? _viewHistoryButtonKey : null,
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
  final VoidCallback onViewDetails;
  final ThemeData theme;
  final EnvelopeRepo repo;
  final bool isPartner;
  final GlobalKey? viewHistoryButtonKey;

  const _BinderSpread({
    required this.group,
    required this.binderColors,
    required this.envelopes,
    required this.totalSaved,
    required this.currency,
    required this.onEdit,
    required this.onViewDetails,
    required this.theme,
    required this.repo,
    required this.isPartner,
    this.viewHistoryButtonKey,
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
        final envelope = widget.envelopes[_selectedIndex!];
        // Prevent access to partner's envelopes
        if (envelope.userId != widget.repo.currentUserId) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("You cannot view details of your partner's envelopes"),
            ),
          );
          setState(() {
            _tapCount = 0;
          });
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EnvelopeDetailScreen(
              envelopeId: widget.envelopes[_selectedIndex!].id,
              repo: widget.repo,
            ),
          ),
        );
        setState(() {
          _tapCount = 0;
        });
      }
    } else {
      setState(() {
        _selectedIndex = index;
        _tapCount = 1;
      });
    }
  }

  Widget _buildInfoChips(BuildContext context, FontProvider fontProvider) {
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);

    // Calculate auto-fill stats
    final autoFillEnvelopes = widget.envelopes.where((e) => e.autoFillEnabled && (e.autoFillAmount ?? 0) > 0).toList();
    final autoFillTotal = autoFillEnvelopes.fold(0.0, (sum, e) => sum + (e.autoFillAmount ?? 0));

    // Calculate target stats
    final targetEnvelopes = widget.envelopes.where((e) => e.targetAmount != null && e.targetAmount! > 0).toList();
    final totalTargetAmount = targetEnvelopes.fold(0.0, (sum, e) => sum + (e.targetAmount ?? 0));
    final totalCurrentAmount = targetEnvelopes.fold(0.0, (sum, e) => sum + e.currentAmount);
    final targetProgress = totalTargetAmount > 0 ? (totalCurrentAmount / totalTargetAmount * 100) : 0.0;

    return Column(
      children: [
        // Auto-fill Chip
        if (autoFillEnvelopes.isNotEmpty)
          GestureDetector(
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
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: widget.binderColors.binderColor.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.binderColors.binderColor.withAlpha(77),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.autorenew,
                        size: 12,
                        color: widget.binderColors.binderColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${autoFillEnvelopes.length} Auto Fill',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: widget.binderColors.binderColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      currency.format(autoFillTotal),
                      style: fontProvider.getTextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: widget.binderColors.envelopeTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Target Chip
        if (targetEnvelopes.isNotEmpty)
          GestureDetector(
            onTap: () {
              // TODO: Navigate to target screen with binder filter
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Target screen navigation coming soon')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: widget.binderColors.binderColor.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.binderColors.binderColor.withAlpha(77),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.track_changes,
                        size: 12,
                        color: widget.binderColors.binderColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Target',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: widget.binderColors.binderColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      currency.format(totalTargetAmount),
                      style: fontProvider.getTextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: widget.binderColors.envelopeTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${targetProgress.toStringAsFixed(1)}% (${currency.format(totalCurrentAmount)})',
                      style: TextStyle(
                        fontSize: 9,
                        color: widget.binderColors.envelopeTextColor.withAlpha(179),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final responsive = context.responsive;
    final selectedEnvelope =
        _selectedIndex != null && _selectedIndex! < widget.envelopes.length
            ? widget.envelopes[_selectedIndex!]
            : null;
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

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
              painter: _OpenBinderPainter(color: widget.binderColors.binderColor),
            ),
          ),

          // LAYER 2: The "Paper" Pages
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.isLandscape ? 12 : 16,
              vertical: responsive.isLandscape ? 12 : 16,
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
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  tr('home_no_envelopes'),
                                  style: fontProvider.getTextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.mail,
                                      size: 16,
                                      color: widget.binderColors.binderColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      tr('home_envelopes_tab'),
                                      style: fontProvider.getTextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: widget.binderColors.envelopeTextColor
                                            .withAlpha(179),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: _DynamicEnvelopeStack(
                                    envelopes: widget.envelopes,
                                    selectedIndex: _selectedIndex,
                                    binderColors: widget.binderColors,
                                    currency: widget.currency,
                                    onTap: _handleEnvelopeTap,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),

                // === SPINE GAP ===
                const SizedBox(width: 24),

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
                    padding: const EdgeInsets.all(12),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        // Binder Header
                        Column(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: widget.binderColors.paperColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: widget.binderColors.binderColor,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.binderColors.binderColor
                                        .withAlpha(51),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: widget.group.getIconWidget(theme, size: 22),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.group.name,
                              style: fontProvider.getTextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: widget.binderColors.envelopeTextColor,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: widget.binderColors.binderColor
                                    .withAlpha(26),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    tr('group_binder_total'),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: widget.binderColors.binderColor,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      widget.currency.format(widget.totalSaved),
                                      style: fontProvider.getTextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: widget.binderColors.binderColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Auto-fill and Target Info Chips
                        const SizedBox(height: 8),
                        _buildInfoChips(context, fontProvider),

                        // Selected Envelope Details
                        if (selectedEnvelope != null) ...[
                          const SizedBox(height: 8),
                          Column(
                            children: [
                              Divider(
                                color: widget.binderColors.envelopeTextColor
                                    .withAlpha(26),
                                height: 8,
                              ),
                              const SizedBox(height: 4),
                              Icon(
                                Icons.mail,
                                size: 16,
                                color: widget.binderColors.binderColor
                                    .withAlpha(179),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                selectedEnvelope.name,
                                style: fontProvider.getTextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: widget.binderColors.envelopeTextColor,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  widget.currency.format(
                                    selectedEnvelope.currentAmount,
                                  ),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: widget.binderColors.binderColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tr('tap_again_for_details'),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: widget.binderColors.envelopeTextColor
                                      .withAlpha(128),
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ],

                        // Action Buttons
                        const SizedBox(height: 8),
                        Column(
                          children: [
                            if (widget.isPartner)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: FutureBuilder<String>(
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
                                ),
                              ),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      widget.binderColors.binderColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.edit, size: 14),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    tr('edit'),
                                    style: fontProvider.getTextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                onPressed: widget.onEdit,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                key: widget.viewHistoryButtonKey,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: widget.binderColors.binderColor
                                        .withAlpha(128),
                                    width: 1.5,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: Icon(
                                  Icons.analytics,
                                  size: 14,
                                  color: widget.binderColors.binderColor,
                                ),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    tr('group_history'),
                                    style: fontProvider.getTextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: widget.binderColors.binderColor,
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _DynamicEnvelopeStack extends StatelessWidget {
  final List<Envelope> envelopes;
  final int? selectedIndex;
  final BinderColorOption binderColors;
  final NumberFormat currency;
  final Function(int) onTap;

  const _DynamicEnvelopeStack({
    required this.envelopes,
    required this.selectedIndex,
    required this.binderColors,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final theme = Theme.of(context);
    final envelopeCount = envelopes.length;

    // Use scrollable list when there are more than 8 envelopes
    if (envelopeCount > 8) {
      return ListView.builder(
        itemCount: envelopeCount,
        itemBuilder: (context, index) {
          final envelope = envelopes[index];
          final isSelected = selectedIndex == index;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: GestureDetector(
              onTap: () => onTap(index),
              child: Container(
                height: 45.0,
                padding: const EdgeInsets.symmetric(horizontal: 10),
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
                    // Envelope Icon
                    envelope.getIconWidget(theme, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        envelope.name,
                        style: fontProvider.getTextStyle(
                          fontSize: 14,
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
                    if (isSelected)
                      Text(
                        currency.format(envelope.currentAmount),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: binderColors.binderColor,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    // Original stacked layout for 8 or fewer envelopes
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;

        final envelopeHeight = 45.0; // Slightly smaller for dense look
        double spacing;
        if (envelopeCount <= 1) {
          spacing = 0;
        } else {
          final remainingSpace = availableHeight - envelopeHeight;
          spacing = remainingSpace / (envelopeCount - 1);
          spacing = spacing.clamp(15.0, envelopeHeight + 6);
        }

        return Stack(
          children: envelopes.asMap().entries.map((entry) {
            final originalIndex = entry.key;
            final envelope = entry.value;
            final isSelected = selectedIndex == originalIndex;

            return Positioned(
              top: originalIndex * spacing,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => onTap(originalIndex),
                child: Container(
                  height: envelopeHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
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
                      // Envelope Icon
                      envelope.getIconWidget(theme, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          envelope.name,
                          style: fontProvider.getTextStyle(
                            fontSize: 14,
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
                      if (isSelected)
                        Text(
                          currency.format(envelope.currentAmount),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: binderColors.binderColor,
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

// --- PAINTER: OPEN BINDER LOOK ---
class _OpenBinderPainter extends CustomPainter {
  final Color color;

  _OpenBinderPainter({required this.color});

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
    final spineWidth = 60.0;
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

    canvas.drawLine(
      Offset(size.width / 2 - 20, 0),
      Offset(size.width / 2 - 20, size.height),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width / 2 + 20, 0),
      Offset(size.width / 2 + 20, size.height),
      linePaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}