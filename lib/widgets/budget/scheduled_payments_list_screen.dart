import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/scheduled_payment.dart';
import '../../services/envelope_repo.dart';
import '../../services/scheduled_payment_repo.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/time_machine_provider.dart';
import '../../screens/add_scheduled_payment_screen.dart';

class ScheduledPaymentsListScreen extends StatelessWidget {
  const ScheduledPaymentsListScreen({
    super.key,
    required this.paymentRepo,
    required this.envelopeRepo,
    this.futureStart,
    this.futureEnd,
  });

  final ScheduledPaymentRepo paymentRepo;
  final EnvelopeRepo envelopeRepo;
  final DateTime? futureStart;
  final DateTime? futureEnd;

  // Helper to calculate all occurrences of a payment in a date range
  List<_PaymentOccurrence> _calculateOccurrences(
    ScheduledPayment payment,
    DateTime start,
    DateTime end,
  ) {
    final occurrences = <_PaymentOccurrence>[];
    DateTime cursor = payment.nextDueDate;
    int safety = 0;

    while (cursor.isBefore(end.add(const Duration(days: 1))) && safety < 100) {
      if (!cursor.isBefore(start)) {
        occurrences.add(_PaymentOccurrence(
          payment: payment,
          dueDate: cursor,
        ));
      }

      switch (payment.frequencyUnit) {
        case PaymentFrequencyUnit.days:
          cursor = cursor.add(Duration(days: payment.frequencyValue));
          break;
        case PaymentFrequencyUnit.weeks:
          cursor = cursor.add(Duration(days: payment.frequencyValue * 7));
          break;
        case PaymentFrequencyUnit.months:
          cursor = DateTime(
            cursor.year,
            cursor.month + payment.frequencyValue,
            cursor.day,
          );
          break;
        case PaymentFrequencyUnit.years:
          cursor = DateTime(
            cursor.year + payment.frequencyValue,
            cursor.month,
            cursor.day,
          );
          break;
      }
      safety++;
    }

    return occurrences;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context, listen: false);
    final currency = NumberFormat.currency(symbol: locale.currencySymbol);
    final timeMachine = Provider.of<TimeMachineProvider>(context, listen: false);

    // Determine the date range to show
    DateTime rangeStart;
    DateTime rangeEnd;
    String title;

    if (futureStart != null && futureEnd != null) {
      // Explicit range provided (from overview card in time machine)
      rangeStart = futureStart!;
      rangeEnd = futureEnd!;
      title = 'Scheduled Payments (Next 30 Days)';
    } else if (timeMachine.isActive && timeMachine.futureDate != null) {
      // Time machine active, show 30 days from target date
      rangeStart = timeMachine.futureDate!;
      rangeEnd = timeMachine.futureDate!.add(const Duration(days: 30));
      title = 'Scheduled Payments (Next 30 Days)';
    } else {
      // Normal mode - show 30 days from now
      rangeStart = DateTime.now();
      rangeEnd = DateTime.now().add(const Duration(days: 30));
      title = 'Scheduled Payments';
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: FittedBox(
          child: Text(
            title,
            style: fontProvider.getTextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('New Payment'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddScheduledPaymentScreen(repo: envelopeRepo),
            ),
          );
        },
      ),
      body: StreamBuilder<List<ScheduledPayment>>(
        initialData: const [],
        stream: paymentRepo.scheduledPaymentsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final payments = snapshot.data ?? [];

          if (payments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No scheduled payments',
                    style: fontProvider.getTextStyle(
                      fontSize: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          // Calculate all occurrences in the date range
          final allOccurrences = <_PaymentOccurrence>[];
          for (final payment in payments) {
            allOccurrences.addAll(_calculateOccurrences(payment, rangeStart, rangeEnd));
          }

          // Sort by due date
          allOccurrences.sort((a, b) => a.dueDate.compareTo(b.dueDate));

          if (allOccurrences.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No scheduled payments in this period',
                    style: fontProvider.getTextStyle(
                      fontSize: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Date range indicator
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today,
                      size: 16,
                      color: theme.colorScheme.primary
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormat('MMM d').format(rangeStart)} - ${DateFormat('MMM d, yyyy').format(rangeEnd)}',
                      style: fontProvider.getTextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${allOccurrences.length} payment${allOccurrences.length != 1 ? 's' : ''}',
                        style: fontProvider.getTextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: allOccurrences.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final occurrence = allOccurrences[index];
                    return _PaymentOccurrenceCard(
                      occurrence: occurrence,
                      currency: currency,
                      envelopeRepo: envelopeRepo,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Model class to represent a single occurrence of a scheduled payment
class _PaymentOccurrence {
  final ScheduledPayment payment;
  final DateTime dueDate;

  _PaymentOccurrence({
    required this.payment,
    required this.dueDate,
  });
}

// Widget to display a payment occurrence card
class _PaymentOccurrenceCard extends StatelessWidget {
  const _PaymentOccurrenceCard({
    required this.occurrence,
    required this.currency,
    required this.envelopeRepo,
  });

  final _PaymentOccurrence occurrence;
  final NumberFormat currency;
  final EnvelopeRepo envelopeRepo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final payment = occurrence.payment;
    final dueDate = occurrence.dueDate;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddScheduledPaymentScreen(
                repo: envelopeRepo,
                paymentToEdit: payment,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Date Box
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Color(payment.colorValue).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(payment.colorValue),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMM').format(dueDate).toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(payment.colorValue),
                      ),
                    ),
                    Text(
                      DateFormat('d').format(dueDate),
                      style: fontProvider.getTextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(payment.colorValue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.name,
                      style: fontProvider.getTextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      payment.frequencyString,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    if (payment.isAutomatic)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.autorenew,
                              size: 12,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Auto-executes',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Amount
              Text(
                currency.format(payment.amount),
                style: fontProvider.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
