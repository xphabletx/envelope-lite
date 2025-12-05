// lib/screens/calendar_screen_v2.dart
// FONT PROVIDER INTEGRATED: All GoogleFonts.caveat() replaced with FontProvider
// All button text wrapped in FittedBox to prevent wrapping

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // NEW IMPORT
import 'package:google_fonts/google_fonts.dart'; // Kept as requested
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/scheduled_payment.dart';
import '../services/envelope_repo.dart';
import '../services/scheduled_payment_repo.dart';
import 'add_scheduled_payment_screen.dart';
import '../services/localization_service.dart';
import '../providers/font_provider.dart'; // NEW IMPORT

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

  late final ScheduledPaymentRepo _paymentRepo;

  @override
  void initState() {
    super.initState();
    _paymentRepo = ScheduledPaymentRepo(
      widget.repo.db,
      widget.repo.currentUserId,
    );
    _selectedDay = _focusedDay;
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

    // FIX: Use isBefore instead of !isAfter to prevent including the end date
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
      startRange = baseDate.subtract(Duration(days: baseDate.weekday - 1));
      endRange = startRange.add(const Duration(days: 6));
    } else {
      startRange = DateTime(baseDate.year, baseDate.month, 1);
      endRange = DateTime(baseDate.year, baseDate.month + 1, 0);
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
    if (date.day % 10 == 1 && date.day != 11)
      suffix = 'st';
    else if (date.day % 10 == 2 && date.day != 12)
      suffix = 'nd';
    else if (date.day % 10 == 3 && date.day != 13)
      suffix = 'rd';

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
            // Keep default font here for symbol clarity at small size
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
                title: Text(
                  tr('calendar_title'),
                  // UPDATED: FontProvider
                  style: fontProvider.getTextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _focusedDay = DateTime.now();
                        _selectedDay = DateTime.now();
                      });
                    },
                    child: FittedBox(
                      // UPDATED: FittedBox
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tr('calendar_today'),
                        // UPDATED: FontProvider
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
                  // Calendar
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
                      calendarFormat: CalendarFormat.month,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        // UPDATED: FontProvider
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
                          color: theme.colorScheme.secondary.withAlpha(77),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: theme.colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                        // UPDATED: FontProvider for calendar days
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
                          color: theme.colorScheme.onSurface.withAlpha(179),
                          fontSize: 18,
                        ),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        // UPDATED: FontProvider
                        weekdayStyle: fontProvider.getTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                        weekendStyle: fontProvider.getTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary.withAlpha(179),
                        ),
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
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

                  // View toggle
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
                            onTap: () => setState(() => _showWeekView = false),
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
                                // UPDATED: FontProvider
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
                            onTap: () => setState(() => _showWeekView = true),
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
                                // UPDATED: FontProvider
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

                  // Events list
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
                                  // UPDATED: FontProvider
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
                                      // UPDATED: FontProvider
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
                                              // UPDATED: FontProvider
                                              style: fontProvider.getTextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          // KEEPING DEFAULT FONT FOR SUMS
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
                                              // UPDATED: FontProvider
                                              style: fontProvider.getTextStyle(
                                                fontSize: 16,
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withAlpha(150),
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
}
