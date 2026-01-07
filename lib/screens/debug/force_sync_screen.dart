// lib/screens/debug/force_sync_screen.dart
// Debug screen to force sync all local data to Firebase

import 'package:flutter/material.dart';
import '../../services/force_sync_service.dart';
import '../../services/envelope_repo.dart';

class ForceSyncScreen extends StatefulWidget {
  final EnvelopeRepo repo;

  const ForceSyncScreen({super.key, required this.repo});

  @override
  State<ForceSyncScreen> createState() => _ForceSyncScreenState();
}

class _ForceSyncScreenState extends State<ForceSyncScreen> {
  final ForceSyncService _forceSyncService = ForceSyncService();
  bool _syncing = false;
  ForceSyncResult? _result;

  Future<void> _forceSync() async {
    setState(() {
      _syncing = true;
      _result = null;
    });

    try {
      final result = await _forceSyncService.forceSyncAll(
        userId: widget.repo.currentUserId,
        workspaceId: widget.repo.workspaceId,
      );

      // Wait for sync queue to complete
      await _forceSyncService.waitForCompletion();

      setState(() {
        _result = result;
        _syncing = false;
      });
    } catch (e) {
      setState(() {
        _result = ForceSyncResult()
          ..success = false
          ..error = e.toString();
        _syncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Force Sync to Firebase'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Force Sync Tool',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This will upload ALL local data (Hive) to Firebase.\n\n'
                      'Use this to:\n'
                      '• Recover from sync failures\n'
                      '• Push offline changes to cloud\n'
                      '• Resolve data divergence\n\n'
                      'Note: This uses "last write wins" - local data will overwrite Firebase.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _syncing ? null : _forceSync,
              icon: _syncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(_syncing ? 'Syncing...' : 'Force Sync All Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            if (_result != null) ...[
              Card(
                color: _result!.success ? Colors.green.shade50 : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _result!.success ? Icons.check_circle : Icons.error,
                            color: _result!.success ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _result!.success ? 'Sync Complete!' : 'Sync Failed',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _result!.success ? Colors.green.shade900 : Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),
                      if (_result!.success) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        _buildStatRow('Envelopes', _result!.envelopesSynced),
                        _buildStatRow('Groups', _result!.groupsSynced),
                        _buildStatRow('Accounts', _result!.accountsSynced),
                        _buildStatRow('Transactions', _result!.transactionsSynced),
                        _buildStatRow('Scheduled Payments', _result!.scheduledPaymentsSynced),
                        const Divider(),
                        _buildStatRow('TOTAL', _result!.totalItemsSynced, bold: true),
                      ],
                      if (!_result!.success && _result!.error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Error: ${_result!.error}',
                          style: TextStyle(color: Colors.red.shade900),
                        ),
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

  Widget _buildStatRow(String label, int count, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
