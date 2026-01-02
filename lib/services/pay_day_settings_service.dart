// lib/services/pay_day_settings_service.dart
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/pay_day_settings.dart';
import 'sync_manager.dart';

/// PayDay Settings Service - Syncs to Firebase for cloud backup
///
/// CRITICAL: PayDay settings MUST sync to prevent data loss on logout/login
/// Syncs to: /users/{userId} document (payDaySettings field)
class PayDaySettingsService {
  PayDaySettingsService(dynamic db, this.userId);

  final String userId;
  final SyncManager _syncManager = SyncManager();

  /// Get reference to pay day settings box
  Box<PayDaySettings> get _settingsBox => Hive.box<PayDaySettings>('payDaySettings');

  /// Stream of pay day settings
  Stream<PayDaySettings?> get payDaySettingsStream {
    // Get initial value directly using userId as key
    final initial = _settingsBox.get(userId);

    // Return stream that emits initial value then watches for changes
    return Stream.value(initial).asyncExpand((initialValue) async* {
      yield initialValue;

      await for (final _ in _settingsBox.watch(key: userId)) {
        yield _settingsBox.get(userId);
      }
    });
  }

  /// Get current pay day settings
  Future<PayDaySettings?> getPayDaySettings() async {
    return _settingsBox.get(userId);
  }

  /// Update pay day settings
  Future<void> updatePayDaySettings(PayDaySettings settings) async {
    try {
      // Use userId as the key in Hive
      await _settingsBox.put(settings.userId, settings);
      debugPrint('[PayDaySettingsService] ✅ Settings updated in Hive: ${settings.userId}');

      // CRITICAL: Sync to Firebase to prevent data loss
      _syncManager.pushPayDaySettings(settings, userId);
    } catch (e) {
      debugPrint('[PayDaySettingsService] ❌ Error updating settings: $e');
      rethrow;
    }
  }

  /// Delete pay day settings
  Future<void> deletePayDaySettings() async {
    try {
      // Delete using userId as key
      await _settingsBox.delete(userId);
      debugPrint('[PayDaySettingsService] ✅ Settings deleted from Hive');
    } catch (e) {
      debugPrint('[PayDaySettingsService] ❌ Error deleting settings: $e');
      rethrow;
    }
  }

  /// Check if pay day is configured
  Future<bool> isPayDayConfigured() async {
    final settings = await getPayDaySettings();
    return settings != null &&
           settings.expectedPayAmount != null &&
           settings.nextPayDate != null;
  }

  /// Get current settings (convenience method)
  Future<PayDaySettings?> getSettings() async {
    return await getPayDaySettings();
  }

  /// Update settings (convenience method)
  Future<void> updateSettings(PayDaySettings settings) async {
    return await updatePayDaySettings(settings);
  }

  /// Update next pay date after processing pay day
  Future<void> updateNextPayDate() async {
    final settings = await getPayDaySettings();
    if (settings == null) return;

    final currentNextDate = settings.nextPayDate ?? DateTime.now();
    final newNextDate = PayDaySettings.calculateNextPayDate(
      currentNextDate,
      settings.payFrequency,
    );

    await updatePayDaySettings(settings.copyWith(
      lastPayDate: currentNextDate,
      nextPayDate: newNextDate,
    ));

    debugPrint('[PayDaySettingsService] Updated next pay date to: $newNextDate');
  }
}
