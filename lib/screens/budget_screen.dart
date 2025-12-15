// lib/screens/budget_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/envelope.dart';
import '../services/envelope_repo.dart';
import '../services/localization_service.dart';
import '../providers/font_provider.dart';
// NEW: Import the analytics widget
import '../widgets/analytics_dashboard.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key, required this.repo});

  final EnvelopeRepo repo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          tr('budget_overview_title'),
          style: fontProvider.getTextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      body: StreamBuilder<List<Envelope>>(
        stream: repo.envelopesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final envelopes = snapshot.data ?? [];
          final totalSaved = envelopes.fold<double>(
            0.0,
            (sum, e) => sum + e.currentAmount,
          );

          // Use the new reusable widget
          return AnalyticsDashboard(
            envelopes: envelopes,
            totalSaved: totalSaved,
            currencySymbol: '£', // Or fetch from LocaleProvider
          );
        },
      ),
    );
  }
}
