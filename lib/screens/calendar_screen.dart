// lib/screens/calendar/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/scheduled_payment.dart';
import '../../models/pay_day_settings.dart';
import '../../services/envelope_repo.dart';
import '../../services/scheduled_payment_repo.dart';
import '../../services/pay_day_settings_service.dart';
import '../../services/notification_repo.dart';
import '../../providers/locale_provider.dart';
import '../../providers/time_machine_provider.dart';
import '../../widgets/time_machine_indicator.dart';
import 'add_scheduled_payment_screen.dart';
import '../../services/localization_service.dart';
import '../../providers/font_provider.dart';
import 'notifications_screen.dart';
import '../screens/home_screen.dart';
import '../../utils/responsive_helper.dart';
import 'envelope/envelopes_detail_screen.dart';

class _PayDayOccurrence {
  final double amount;
  final DateTime date;
  final String frequency;

  _PayDayOccurrence(this.amount, this.date, this.frequency);
}

/// Unified class to hold either a scheduled payment or a pay day occurrence
class _CalendarEvent {
  final ScheduledPayment? payment;
  final _PayDayOccurrence? payDay;
  final DateTime date;

  _CalendarEvent.fromPayment(this.payment, this.date) : payDay = null;
  _CalendarEvent.fromPayDay(this.payDay, this.date) : payment = null;

  bool get isPayDay => payDay != null;

  String get name => isPayDay ? '💰 Pay Day' : payment!.name;
  double get amount => isPayDay ? payDay!.amount : payment!.amount;
  int get colorValue => isPayDay ? 0xFF4CAF50 : payment!.colorValue; // Green for pay day
  String get frequencyString {
    if (isPayDay) {
      switch (payDay!.frequency) {
        case 'weekly':
          return 'Weekly';
        case 'biweekly':
          return 'Bi-weekly';
        case 'fourweekly':
          return '4-weekly';
        case 'monthly':
          return 'Monthly';
        default:
          return payDay!.frequency;
      }
    }
    return payment!.frequencyString;
  }
}

class CalendarScreenV2 extends StatefulWidget {
  const CalendarScreenV2({
    super.key,
    required this.repo,
    this.notificationRepo,
  });

  final EnvelopeRepo repo;
  final NotificationRepo? notificationRepo;

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
  late final PayDaySettingsService _payDayService;

  @override
  void initState() {
    super.initState();
    _paymentRepo = ScheduledPaymentRepo(widget.repo.currentUserId);
    _payDayService = PayDaySettingsService(
      widget.repo.db,
      widget.repo.currentUserId,
    );

    // Check if time machine is active and jump to target date
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);
      if (timeMachine.isActive && timeMachine.futureDate != null) {
        setState(() {
          _focusedDay = timeMachine.futureDate!;
          _selectedDay = timeMachine.futureDate!;
        });
        debugPrint('[TimeMachine::CalendarScreen] Calendar Initialization:');
        debugPrint('[TimeMachine::CalendarScreen]   Jumped to future date: ${timeMachine.futureDate}');
      }
    });

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

  List<_CalendarEvent> _getEventsForDay(
    DateTime day,
    List<ScheduledPayment> payments,
    PayDaySettings? paySettings,
  ) {
    final eventsOnDay = <_CalendarEvent>[];
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // Add scheduled payment events
    for (final payment in payments) {
      final occurrences = _getOccurrencesInRange(payment, dayStart, dayEnd);
      if (occurrences.isNotEmpty) {
        eventsOnDay.add(_CalendarEvent.fromPayment(payment, dayStart));
      }
    }

    // Add pay day events
    final payDayOccurrences = _getPayDayOccurrences(paySettings, dayStart, dayEnd);
    for (final payDay in payDayOccurrences) {
      eventsOnDay.add(_CalendarEvent.fromPayDay(payDay, dayStart));
    }

    return eventsOnDay;
  }

  // Calculate pay day occurrences within a date range
  List<_PayDayOccurrence> _getPayDayOccurrences(
    PayDaySettings? paySettings,
    DateTime start,
    DateTime end,
  ) {
    if (paySettings == null || paySettings.nextPayDate == null) {
      return [];
    }

    final occurrences = <_PayDayOccurrence>[];
    DateTime current = paySettings.nextPayDate!;

    // Go back to find first occurrence before start
    while (current.isAfter(start)) {
      current = _getPreviousPayDay(paySettings, current);
    }

    // Generate occurrences within range
    while (current.isBefore(end)) {
      if (!current.isBefore(start)) {
        // Apply weekend adjustment if enabled
        final adjustedDate = paySettings.adjustForWeekends
            ? paySettings.adjustForWeekend(current)
            : current;

        occurrences.add(_PayDayOccurrence(
          paySettings.expectedPayAmount ?? 0.0,
          adjustedDate,
          paySettings.payFrequency,
        ));
      }
      current = _getNextPayDay(paySettings, current);
    }

    return occurrences;
  }

  DateTime _getNextPayDay(PayDaySettings settings, DateTime from) {
    switch (settings.payFrequency) {
      case 'weekly':
        return from.add(const Duration(days: 7));
      case 'biweekly':
        return from.add(const Duration(days: 14));
      case 'fourweekly':
        return from.add(const Duration(days: 28));
      case 'monthly':
        return DateTime(from.year, from.month + 1, from.day);
      default:
        return from.add(const Duration(days: 30));
    }
  }

  DateTime _getPreviousPayDay(PayDaySettings settings, DateTime from) {
    switch (settings.payFrequency) {
      case 'weekly':
        return from.subtract(const Duration(days: 7));
      case 'biweekly':
        return from.subtract(const Duration(days: 14));
      case 'fourweekly':
        return from.subtract(const Duration(days: 28));
      case 'monthly':
        return DateTime(from.year, from.month - 1, from.day);
      default:
        return from.subtract(const Duration(days: 30));
    }
  }

  Map<DateTime, List<_CalendarEvent>> _getOccurrencesForVisibleRange(
    List<ScheduledPayment> payments,
    PayDaySettings? paySettings,
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

    // If time machine is active, cap end range at projection date
    final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);
    if (timeMachine.isActive && timeMachine.futureDate != null) {
      if (endRange.isAfter(timeMachine.futureDate!)) {
        endRange = timeMachine.futureDate!.add(const Duration(days: 1));
        debugPrint('[TimeMachine::CalendarScreen] Event Generation:');
        debugPrint('[TimeMachine::CalendarScreen]   Capped end range at ${timeMachine.futureDate}');
      }
    }

    final events = <_CalendarEvent>[];

    // Add scheduled payment occurrences
    for (final payment in payments) {
      final dates = _getOccurrencesInRange(payment, startRange, endRange);
      for (final date in dates) {
        events.add(_CalendarEvent.fromPayment(payment, date));
      }
    }

    // Add pay day occurrences
    if (paySettings != null && paySettings.nextPayDate != null) {
      final payDayOccurrences = _getPayDayOccurrences(
        paySettings,
        startRange,
        endRange,
      );
      for (final payDay in payDayOccurrences) {
        events.add(_CalendarEvent.fromPayDay(payDay, payDay.date));
      }
      debugPrint('[Calendar] Added ${payDayOccurrences.length} pay day events to calendar');
    }

    events.sort((a, b) => a.date.compareTo(b.date));

    final Map<DateTime, List<_CalendarEvent>> grouped = {};
    for (var event in events) {
      final dateKey = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
      );
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(event);
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

  Widget _buildEventMarker(List<_CalendarEvent> events) {
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

  Widget _buildLandscapeLayout(
    ThemeData theme,
    FontProvider fontProvider,
    NumberFormat currencyFormatter,
    List<ScheduledPayment> scheduledPayments,
    PayDaySettings? paySettings,
    Map<DateTime, List<_CalendarEvent>> groupedOccurrences,
    List<DateTime> sortedDates,
  ) {
    return Column(
      children: [
        const TimeMachineIndicator(),
        Expanded(
          child: Row(
            children: [
              // Left column: Static calendar
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      // Calendar controls row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            // View toggle buttons
                            Row(
                              children: [
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
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _focusedDay = DateTime.now();
                                      _selectedDay = DateTime.now();
                                    });
                                  },
                                  child: Text(
                                    tr('calendar_today'),
                                    style: fontProvider.getTextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.secondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Notification and add buttons
                            Row(
                              children: [
                                if (widget.notificationRepo != null)
                                  StreamBuilder<int>(
                                    stream: widget.notificationRepo!.unreadCountStream,
                                    builder: (context, snapshot) {
                                      final unreadCount = snapshot.data ?? 0;
                                      return Stack(
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              Icons.notifications_outlined,
                                              color: theme.colorScheme.primary,
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => NotificationsScreen(
                                                    notificationRepo: widget.notificationRepo!,
                                                  ),
                                                ),
                                              );
                                            },
                                            tooltip: 'Notifications',
                                          ),
                                          if (unreadCount > 0)
                                            Positioned(
                                              right: 8,
                                              top: 8,
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                constraints: const BoxConstraints(
                                                  minWidth: 16,
                                                  minHeight: 16,
                                                ),
                                                child: Text(
                                                  unreadCount > 9 ? '9+' : '$unreadCount',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                IconButton(
                                  icon: Icon(Icons.add, color: theme.colorScheme.primary),
                                  onPressed: _addScheduledPayment,
                                  tooltip: tr('calendar_add_payment_tooltip'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Calendar widget
                        Flexible(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SizedBox(
                                height: constraints.maxHeight,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: TableCalendar(
                            firstDay: DateTime(2020),
                            lastDay: DateTime(2030),
                            focusedDay: _focusedDay,
                            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                            calendarFormat: _compactCalendar
                                ? CalendarFormat.week
                                : CalendarFormat.month,
                            startingDayOfWeek: StartingDayOfWeek.monday,
                            daysOfWeekHeight: 17,
                            rowHeight: 28,
                          headerStyle: HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            headerPadding: const EdgeInsets.symmetric(vertical: 2),
                            titleTextStyle: fontProvider.getTextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                            leftChevronIcon: Icon(
                              Icons.chevron_left,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            rightChevronIcon: Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          calendarStyle: CalendarStyle(
                            outsideDaysVisible: false,
                            cellMargin: const EdgeInsets.all(2),
                            todayDecoration: BoxDecoration(
                              color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: theme.colorScheme.secondary,
                              shape: BoxShape.circle,
                            ),
                            todayTextStyle: fontProvider.getTextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            selectedTextStyle: fontProvider.getTextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            defaultTextStyle: fontProvider.getTextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 12,
                            ),
                            weekendTextStyle: fontProvider.getTextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                          daysOfWeekStyle: DaysOfWeekStyle(
                            weekdayStyle: fontProvider.getTextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                            weekendStyle: fontProvider.getTextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          onDaySelected: (selectedDay, focusedDay) {
                            final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);
                            if (timeMachine.isActive && timeMachine.futureDate != null) {
                              if (selectedDay.isAfter(timeMachine.futureDate!)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Cannot select dates beyond projection date (${DateFormat('MMM dd, yyyy').format(timeMachine.futureDate!)})'),
                                    backgroundColor: Colors.orange,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                            }

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
                                paySettings,
                              );
                              return _buildEventMarker(dayEvents);
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
              // Right column: Vertical scrolling event list
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: sortedDates.length,
                          itemBuilder: (context, dateIndex) {
                            final date = sortedDates[dateIndex];
                            final occurrences = groupedOccurrences[date]!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(bottom: 8, top: dateIndex == 0 ? 0 : 16),
                                  child: Text(
                                    _formatGroupDate(date),
                                    style: fontProvider.getTextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                ...occurrences.map((event) {
                                  return InkWell(
                                    onTap: () {
                                      if (!event.isPayDay && event.payment != null) {
                                        final envelopeId = event.payment!.envelopeId;
                                        if (envelopeId != null && envelopeId.isNotEmpty) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => EnvelopeDetailScreen(
                                                envelopeId: envelopeId,
                                                repo: widget.repo,
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: Color(event.colorValue),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  event.name,
                                                  style: fontProvider.getTextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                currencyFormatter.format(event.amount.abs()),
                                                style: fontProvider.getTextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.colorScheme.onSurface,
                                                ),
                                              ),
                                              Text(
                                                event.frequencyString,
                                                style: fontProvider.getTextStyle(
                                                  fontSize: 12,
                                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout(
    ThemeData theme,
    FontProvider fontProvider,
    NumberFormat currencyFormatter,
    List<ScheduledPayment> scheduledPayments,
    PayDaySettings? paySettings,
    Map<DateTime, List<_CalendarEvent>> groupedOccurrences,
    List<DateTime> sortedDates,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive font sizes
        final titleFontSize = 24.0;
        final dayFontSize = 18.0;
        final weekdayFontSize = 16.0;
        final daysOfWeekHeight = 40.0;

        return Column(
          children: [
            // Time Machine Indicator at the top
            const TimeMachineIndicator(),

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
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: _compactCalendar
                    ? CalendarFormat.week
                    : CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.monday,
                daysOfWeekHeight: daysOfWeekHeight,
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: fontProvider.getTextStyle(
                    fontSize: titleFontSize,
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
                    color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: fontProvider.getTextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: dayFontSize,
                  ),
                  selectedTextStyle: fontProvider.getTextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: dayFontSize,
                  ),
                  defaultTextStyle: fontProvider.getTextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: dayFontSize,
                  ),
                  weekendTextStyle: fontProvider.getTextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: dayFontSize,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: fontProvider.getTextStyle(
                    fontSize: weekdayFontSize,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  weekendStyle: fontProvider.getTextStyle(
                    fontSize: weekdayFontSize,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  // Check if time machine is active and prevent selecting beyond projection date
                  final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);
                  if (timeMachine.isActive && timeMachine.futureDate != null) {
                    if (selectedDay.isAfter(timeMachine.futureDate!)) {
                      debugPrint('[TimeMachine::CalendarScreen] Date Selection:');
                      debugPrint('[TimeMachine::CalendarScreen]   Blocked selection of $selectedDay beyond ${timeMachine.futureDate}');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Cannot select dates beyond projection date (${DateFormat('MMM dd, yyyy').format(timeMachine.futureDate!)})'),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                  }

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
                      paySettings,
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
                            ...occurrences.map((event) {
                              return InkWell(
                                onTap: () {
                                  // Navigate to envelope detail screen if this is a scheduled payment
                                  if (!event.isPayDay && event.payment != null) {
                                    final envelopeId = event.payment!.envelopeId;
                                    if (envelopeId != null && envelopeId.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => EnvelopeDetailScreen(
                                            envelopeId: envelopeId,
                                            repo: widget.repo,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 8,
                                    left: 8,
                                    top: 8,
                                    right: 8,
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Color(event.colorValue),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          event.name,
                                          style: fontProvider.getTextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        currencyFormatter.format(
                                          event.amount.abs(),
                                        ),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          event.frequencyString,
                                          style: fontProvider.getTextStyle(
                                            fontSize: 16,
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ),
                                      if (!event.isPayDay)
                                        Icon(
                                          Icons.chevron_right,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                          size: 20,
                                        ),
                                    ],
                                  ),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currencyFormatter = NumberFormat.currency(symbol: locale.currencySymbol);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return StreamBuilder<PayDaySettings?>(
      initialData: null,
      stream: _payDayService.payDaySettingsStream,
      builder: (context, payDaySnapshot) {
        final paySettings = payDaySnapshot.data;

        return StreamBuilder<List<ScheduledPayment>>(
          initialData: const [],
          stream: _paymentRepo.scheduledPaymentsStream,
          builder: (context, paymentsSnapshot) {
            debugPrint('[Calendar] ========================================');
            debugPrint('[Calendar] Scheduled payments stream update');
            debugPrint('[Calendar] Has data: ${paymentsSnapshot.hasData}');
            debugPrint('[Calendar] All payments count: ${paymentsSnapshot.data?.length ?? 0}');

            return StreamBuilder<List<dynamic>>(
              initialData: widget.repo.getEnvelopesSync(),
              stream: widget.repo.envelopesStream(),
              builder: (context, envelopesSnapshot) {
                final allPayments = paymentsSnapshot.data ?? [];
                final existingEnvelopes = envelopesSnapshot.data ?? [];
                final envelopeIds = existingEnvelopes.map((e) => e.id).toSet();

                debugPrint('[Calendar] Envelope IDs: ${envelopeIds.length}');

                final scheduledPayments = allPayments
                    .where((payment) => envelopeIds.contains(payment.envelopeId))
                    .toList();

                debugPrint('[Calendar] Filtered scheduled payments: ${scheduledPayments.length}');

                // Log each payment for debugging
                for (final payment in allPayments) {
                  debugPrint('[Calendar] Payment: ${payment.name}');
                  debugPrint('[Calendar]   EnvelopeId: ${payment.envelopeId}');
                  debugPrint('[Calendar]   Start Date: ${payment.startDate}');
                  debugPrint('[Calendar]   Has matching envelope: ${envelopeIds.contains(payment.envelopeId)}');
                }
                debugPrint('[Calendar] ========================================');

                // Get all calendar events (scheduled payments + pay day)
                final groupedOccurrences = _getOccurrencesForVisibleRange(
                  scheduledPayments,
                  paySettings,
                );

                final sortedDates = groupedOccurrences.keys.toList()..sort();

                final responsive = context.responsive;
                final isLandscape = responsive.isLandscape;

                return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              appBar: AppBar(
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
                scrolledUnderElevation: 0,
                toolbarHeight: isLandscape ? 0 : kToolbarHeight,
                title: isLandscape ? null : FittedBox(
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
                actions: isLandscape ? null : [
                  // Notification badge button
                  if (widget.notificationRepo != null)
                    StreamBuilder<int>(
                      stream: widget.notificationRepo!.unreadCountStream,
                      builder: (context, snapshot) {
                        final unreadCount = snapshot.data ?? 0;
                        return Stack(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.notifications_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NotificationsScreen(
                                      notificationRepo:
                                          widget.notificationRepo!,
                                    ),
                                  ),
                                );
                              },
                              tooltip: 'Notifications',
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    unreadCount > 9 ? '9+' : '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
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
              body: isLandscape
                  ? _buildLandscapeLayout(
                      theme,
                      fontProvider,
                      currencyFormatter,
                      scheduledPayments,
                      paySettings,
                      groupedOccurrences,
                      sortedDates,
                    )
                  : _buildPortraitLayout(
                      theme,
                      fontProvider,
                      currencyFormatter,
                      scheduledPayments,
                      paySettings,
                      groupedOccurrences,
                      sortedDates,
                    ),
                );
              },
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 40,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 12),
              Text(
                'Project to ${DateFormat('MMMM d, yyyy').format(date)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'See your projected balance on this date',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _openProjectionForDate(date);
                },
                icon: const Icon(Icons.rocket_launch),
                label: const Text('Open Projection Tool'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 24,
                  ),
                  minimumSize: const Size(double.infinity, 48),
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
      ),
    );
  }
}
