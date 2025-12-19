// lib/screens/calendar/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/scheduled_payment.dart';
import '../../services/envelope_repo.dart';
import '../../services/scheduled_payment_repo.dart';
import 'add_scheduled_payment_screen.dart';
import '../../services/localization_service.dart';
import '../../providers/font_provider.dart';
import '../screens/home_screen.dart';

class _PaymentOccurrence {
  final ScheduledPayment payment;
  final DateTime date;

  _PaymentOccurrence(this.payment, this.date);
}

class CalendarScreenV2 extends StatefulWidget {
  const CalendarScreenV2({super.key, required this.repo});

  final EnvelopeRepo repo;

  @override
  State<CalendarScreenV2> createState() => _CalendarScreenV2State();
}

class _CalendarScreenV2State extends State<CalendarScreenV2> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _showWeekView = false;
  bool _compactCalendar = false;
  static const String _kPrefsKeyCalendarCompact = 'calendar_view_compact';

  late final ScheduledPaymentRepo _paymentRepo;

  @override
  void initState() {
    super.initState();
    _paymentRepo = ScheduledPaymentRepo(
      widget.repo.db,
      widget.repo.currentUserId,
    );
    _selectedDay = _focusedDay;
    _restoreViewPreference();
  }

  Future<void> _restoreViewPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isCompact = prefs.getBool(_kPrefsKeyCalendarCompact) ?? false;

      if (mounted) {
        setState(() {
          _compactCalendar = isCompact;
          _showWeekView = isCompact;
        });
      }
    } catch (e) {
      debugPrint('Error restoring calendar view preference: $e');
    }
  }

  void _setCalendarMode({required bool isWeekMode}) {
    setState(() {
      _compactCalendar = isWeekMode;
      _showWeekView = isWeekMode;
    });
    _saveViewPreference(isWeekMode);
  }

  Future<void> _saveViewPreference(bool isWeekMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefsKeyCalendarCompact, isWeekMode);
    } catch (e) {
      debugPrint('Error saving calendar view preference: $e');
    }
  }

  List<DateTime> _getOccurrencesInRange(
    ScheduledPayment payment,
    DateTime start,
    DateTime end,
  ) {
    final occurrences = <DateTime>[];
    DateTime current = payment.startDate;

    while (current.isBefore(start)) {
      current = _getNextOccurrence(payment, current);
    }

    while (current.isBefore(end)) {
      occurrences.add(current);
      current = _getNextOccurrence(payment, current);
    }

    return occurrences;
  }

  DateTime _getNextOccurrence(ScheduledPayment payment, DateTime from) {
    switch (payment.frequencyUnit) {
      case PaymentFrequencyUnit.days:
        return from.add(Duration(days: payment.frequencyValue));
      case PaymentFrequencyUnit.weeks:
        return from.add(Duration(days: payment.frequencyValue * 7));
      case PaymentFrequencyUnit.months:
        return DateTime(
          from.year,
          from.month + payment.frequencyValue,
          from.day,
        );
      case PaymentFrequencyUnit.years:
        return DateTime(
          from.year + payment.frequencyValue,
          from.month,
          from.day,
        );
    }
  }

  List<ScheduledPayment> _getEventsForDay(
    DateTime day,
    List<ScheduledPayment> payments,
  ) {
    final eventsOnDay = <ScheduledPayment>[];
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    for (final payment in payments) {
      final occurrences = _getOccurrencesInRange(payment, dayStart, dayEnd);
      if (occurrences.isNotEmpty) {
        eventsOnDay.add(payment);
      }
    }

    return eventsOnDay;
  }

  Map<DateTime, List<_PaymentOccurrence>> _getOccurrencesForVisibleRange(
    List<ScheduledPayment> payments,
  ) {
    DateTime startRange;
    DateTime endRange;

    final baseDate = DateTime(
      _focusedDay.year,
      _focusedDay.month,
      _focusedDay.day,
    );

    if (_showWeekView) {
      // Start on Monday
      startRange = baseDate.subtract(Duration(days: baseDate.weekday - 1));

      // FIXED: Changed from 6 to 7.
      // Previously, adding 6 days made the end range "Sunday 00:00".
      // Since the check is `isBefore(end)`, Sunday events were excluded.
      // Adding 7 days makes the end range "Monday 00:00" of next week, fully including Sunday.
      endRange = startRange.add(const Duration(days: 7));
    } else {
      startRange = DateTime(baseDate.year, baseDate.month, 1);

      // FIXED: Changed day from 0 to 1.
      // Day 0 gives the last day of the *current* month (e.g. Jan 31).
      // Since check is `isBefore`, Jan 31st events were excluded.
      // Day 1 gives the 1st of the *next* month (e.g. Feb 1), fully including Jan 31st.
      endRange = DateTime(baseDate.year, baseDate.month + 1, 1);
    }

    final occurrences = <_PaymentOccurrence>[];

    for (final payment in payments) {
      final dates = _getOccurrencesInRange(payment, startRange, endRange);
      for (final date in dates) {
        occurrences.add(_PaymentOccurrence(payment, date));
      }
    }

    occurrences.sort((a, b) => a.date.compareTo(b.date));

    final Map<DateTime, List<_PaymentOccurrence>> grouped = {};
    for (var occurrence in occurrences) {
      final dateKey = DateTime(
        occurrence.date.year,
        occurrence.date.month,
        occurrence.date.day,
      );
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(occurrence);
    }

    return grouped;
  }

  String _formatGroupDate(DateTime date) {
    String suffix = 'th';
    if (date.day % 10 == 1 && date.day != 11) {
      suffix = 'st';
    } else if (date.day % 10 == 2 && date.day != 12) {
      suffix = 'nd';
    } else if (date.day % 10 == 3 && date.day != 13) {
      suffix = 'rd';
    }

    return "${date.day}$suffix ${DateFormat('MMM').format(date)}";
  }

  void _addScheduledPayment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddScheduledPaymentScreen(repo: widget.repo),
      ),
    );
  }

  void _openProjectionForDate(DateTime date) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          repo: widget.repo,
          initialIndex: 2,
          projectionDate: date,
        ),
      ),
      (route) => false,
    );
  }

  Widget _buildEventMarker(List<ScheduledPayment> events) {
    if (events.isEmpty) return const SizedBox.shrink();

    if (events.length == 1) {
      return Container(
        margin: const EdgeInsets.only(top: 2),
        height: 3,
        decoration: BoxDecoration(
          color: Color(events.first.colorValue),
          borderRadius: BorderRadius.circular(1.5),
        ),
      );
    } else if (events.length <= 3) {
      return Container(
        margin: const EdgeInsets.only(top: 2),
        height: 3,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: events.map((e) => Color(e.colorValue)).toList(),
          ),
          borderRadius: BorderRadius.circular(1.5),
        ),
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...events
              .take(2)
              .map(
                (e) => Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(right: 2, top: 2),
                  decoration: BoxDecoration(
                    color: Color(e.colorValue),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          Container(
            margin: const EdgeInsets.only(top: 2),
            child: const Text(
              '+',
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(symbol: '£');
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return StreamBuilder<List<ScheduledPayment>>(
      stream: _paymentRepo.scheduledPaymentsStream,
      builder: (context, paymentsSnapshot) {
        return StreamBuilder<List<dynamic>>(
          stream: widget.repo.envelopesStream(),
          builder: (context, envelopesSnapshot) {
            final allPayments = paymentsSnapshot.data ?? [];
            final existingEnvelopes = envelopesSnapshot.data ?? [];
            final envelopeIds = existingEnvelopes.map((e) => e.id).toSet();

            final scheduledPayments = allPayments
                .where((payment) => envelopeIds.contains(payment.envelopeId))
                .toList();

            final groupedOccurrences = _getOccurrencesForVisibleRange(
              scheduledPayments,
            );
            final sortedDates = groupedOccurrences.keys.toList()..sort();

            return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              appBar: AppBar(
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
                scrolledUnderElevation: 0,
                title: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr('calendar_title'),
                    style: fontProvider.getTextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      _compactCalendar
                          ? Icons.calendar_view_month
                          : Icons.calendar_view_week,
                      color: theme.colorScheme.secondary,
                    ),
                    onPressed: () {
                      _setCalendarMode(isWeekMode: !_compactCalendar);
                    },
                    tooltip: _compactCalendar
                        ? 'Show Full Calendar'
                        : 'Show Week Only',
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _focusedDay = DateTime.now();
                        _selectedDay = DateTime.now();
                      });
                    },
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tr('calendar_today'),
                        style: fontProvider.getTextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add, color: theme.colorScheme.primary),
                    onPressed: _addScheduledPayment,
                    tooltip: tr('calendar_add_payment_tooltip'),
                  ),
                ],
              ),
              body: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TableCalendar(
                      firstDay: DateTime(2020),
                      lastDay: DateTime(2030),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      calendarFormat: _compactCalendar
                          ? CalendarFormat.week
                          : CalendarFormat.month,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      daysOfWeekHeight: 40.0,
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: fontProvider.getTextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                        leftChevronIcon: Icon(
                          Icons.chevron_left,
                          color: theme.colorScheme.primary,
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        todayDecoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withValues(
                            alpha: 0.3,
                          ),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: theme.colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: fontProvider.getTextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        selectedTextStyle: fontProvider.getTextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        defaultTextStyle: fontProvider.getTextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 18,
                        ),
                        weekendTextStyle: fontProvider.getTextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                          fontSize: 18,
                        ),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: fontProvider.getTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                        weekendStyle: fontProvider.getTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });

                        if (selectedDay.isAfter(DateTime.now())) {
                          _showProjectionOption(selectedDay);
                        }
                      },
                      onPageChanged: (focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                        });
                      },
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, date, events) {
                          final dayEvents = _getEventsForDay(
                            date,
                            scheduledPayments,
                          );
                          return _buildEventMarker(dayEvents);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _setCalendarMode(isWeekMode: false),
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(12),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_showWeekView
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(12),
                                ),
                              ),
                              child: Text(
                                tr('calendar_month_view'),
                                textAlign: TextAlign.center,
                                style: fontProvider.getTextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: !_showWeekView
                                      ? Colors.white
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => _setCalendarMode(isWeekMode: true),
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(12),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _showWeekView
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(12),
                                ),
                              ),
                              child: Text(
                                tr('calendar_week_view'),
                                textAlign: TextAlign.center,
                                style: fontProvider.getTextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _showWeekView
                                      ? Colors.white
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Expanded(
                    child: sortedDates.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.event_available,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _showWeekView
                                      ? tr('calendar_no_payments_week')
                                      : tr('calendar_no_payments_month'),
                                  style: fontProvider.getTextStyle(
                                    fontSize: 22,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: sortedDates.length,
                            itemBuilder: (context, index) {
                              final date = sortedDates[index];
                              final occurrences = groupedOccurrences[date]!;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 8,
                                      top: 8,
                                    ),
                                    child: Text(
                                      _formatGroupDate(date),
                                      style: fontProvider.getTextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  ...occurrences.map((occurrence) {
                                    final payment = occurrence.payment;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 8,
                                        left: 8,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: Color(payment.colorValue),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              payment.name,
                                              style: fontProvider.getTextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            currencyFormatter.format(
                                              payment.amount.abs(),
                                            ),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          SizedBox(
                                            width: 80,
                                            child: Text(
                                              payment.frequencyString,
                                              style: fontProvider.getTextStyle(
                                                fontSize: 16,
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                              textAlign: TextAlign.end,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  const Divider(height: 24),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showProjectionOption(DateTime date) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 48,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Project to ${DateFormat('MMMM d, yyyy').format(date)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'See your projected balance on this date',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openProjectionForDate(date);
              },
              icon: const Icon(Icons.rocket_launch),
              label: const Text('Open Projection Tool'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 24,
                ),
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
