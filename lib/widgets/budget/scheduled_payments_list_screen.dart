import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/scheduled_payment.dart';
import '../../services/envelope_repo.dart';
import '../../services/scheduled_payment_repo.dart';
import '../../providers/font_provider.dart';
import '../../screens/add_scheduled_payment_screen.dart';

class ScheduledPaymentsListScreen extends StatelessWidget {
  const ScheduledPaymentsListScreen({
    super.key,
    required this.paymentRepo,
    required this.envelopeRepo,
  });

  final ScheduledPaymentRepo paymentRepo;
  final EnvelopeRepo envelopeRepo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final currency = NumberFormat.simpleCurrency(locale: 'en_GB');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Scheduled Payments',
          style: fontProvider.getTextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
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

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final payment = payments[index];
              return _PaymentCard(
                payment: payment,
                currency: currency,
                envelopeRepo: envelopeRepo,
              );
            },
          );
        },
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.currency,
    required this.envelopeRepo,
  });

  final ScheduledPayment payment;
  final NumberFormat currency;
  final EnvelopeRepo envelopeRepo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

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
                      DateFormat(
                        'MMM',
                      ).format(payment.nextDueDate).toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(payment.colorValue),
                      ),
                    ),
                    Text(
                      DateFormat('d').format(payment.nextDueDate),
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
