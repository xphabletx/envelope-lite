// lib/services/pay_day_settings_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/pay_day_settings.dart';

class PayDaySettingsService {
  PayDaySettingsService(this._db, this.userId);

  final FirebaseFirestore _db;
  final String userId;

  /// Get reference to pay day settings document
  DocumentReference<Map<String, dynamic>> _settingsDoc() {
    return _db
        .collection('users')
        .doc(userId)
        .collection('payDaySettings')
        .doc('settings');
  }

  /// Stream of pay day settings
  Stream<PayDaySettings?> get payDaySettingsStream {
    return _settingsDoc().snapshots().map((doc) {
      if (!doc.exists) return null;
      return PayDaySettings.fromFirestore(doc);
    });
  }

  /// Get current pay day settings
  Future<PayDaySettings?> getPayDaySettings() async {
    final doc = await _settingsDoc().get();
    if (!doc.exists) return null;
    return PayDaySettings.fromFirestore(doc);
  }

  /// Update pay day settings
  Future<void> updatePayDaySettings(PayDaySettings settings) async {
    try {
      await _settingsDoc().set(settings.toFirestore());
      debugPrint('[PayDaySettingsService] ✅ Settings updated');
    } catch (e) {
      debugPrint('[PayDaySettingsService] ❌ Error updating settings: $e');
      rethrow;
    }
  }

  /// Delete pay day settings
  Future<void> deletePayDaySettings() async {
    try {
      await _settingsDoc().delete();
      debugPrint('[PayDaySettingsService] ✅ Settings deleted');
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
