// lib/screens/migration_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hive_migration_service.dart';

class MigrationScreen extends StatefulWidget {
  const MigrationScreen({super.key});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  final _migrationService = HiveMigrationService(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  );

  bool _migrating = false;
  bool _migrated = false;
  Map<String, dynamic>? _verificationResult;

  Future<void> _runMigration() async {
    setState(() {
      _migrating = true;
      _migrated = false;
      _verificationResult = null;
    });

    final success = await _migrationService.migrate();

    setState(() {
      _migrating = false;
      _migrated = success;
    });

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Migration failed. Check logs for details.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _verifyMigration() async {
    setState(() => _migrating = true);

    final result = await _migrationService.verifyMigration();

    setState(() {
      _migrating = false;
      _verificationResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Migration'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Explainer
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offline-First Storage',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your data will be stored locally on your device. '
                      'This makes the app faster and work offline. '
                      'Your data only syncs to the cloud when you join a workspace.',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Migrate Button
            if (!_migrated)
              FilledButton(
                onPressed: _migrating ? null : _runMigration,
                child: _migrating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Start Migration'),
              ),

            // Success Message
            if (_migrated) ...[
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Migration complete! Your data is now stored locally.',
                          style: TextStyle(color: Colors.green.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _migrating ? null : _verifyMigration,
                child: const Text('Verify Migration'),
              ),
            ],

            // Verification Results
            if (_verificationResult != null) ...[
              const SizedBox(height: 16),
              Card(
                color: _verificationResult!['success'] == true
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _verificationResult!['success'] == true
                                ? Icons.check_circle
                                : Icons.error,
                            color: _verificationResult!['success'] == true
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _verificationResult!['success'] == true
                                ? 'Verification Passed'
                                : 'Verification Failed',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _verificationResult!['success'] == true
                                  ? Colors.green.shade900
                                  : Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Envelopes: ${_verificationResult!['envelopes'] ?? 0}'),
                      Text('Accounts: ${_verificationResult!['accounts'] ?? 0}'),
                      Text('Transactions: ${_verificationResult!['transactions'] ?? 0}'),
                      if (_verificationResult!['mismatches'] != null &&
                          (_verificationResult!['mismatches'] as List).isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Mismatches:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...(_verificationResult!['mismatches'] as List)
                            .map((m) => Text('• $m')),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
