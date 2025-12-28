// lib/services/pay_day_settings_service.dart
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/pay_day_settings.dart';

class PayDaySettingsService {
  PayDaySettingsService(dynamic db, this.userId);

  final String userId;

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
}
