// lib/models/envelope.dart
// UPDATED: Using Google Favicons + Cached Network Image

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive/hive.dart';
import '../data/material_icons_database.dart';

part 'envelope.g.dart';

@HiveType(typeId: 0)
class Envelope {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  final String userId;

  @HiveField(3)
  double currentAmount;

  @HiveField(4)
  double? targetAmount;

  @HiveField(5)
  DateTime? targetDate;

  @HiveField(6)
  String? groupId;

  // OLD: Single emoji field (keep for backwards compatibility)
  @HiveField(7)
  final String? emoji;

  // NEW: Icon system
  @HiveField(8)
  final String? iconType; // 'emoji', 'materialIcon', 'companyLogo'

  @HiveField(9)
  final String? iconValue; // emoji char, icon name, or domain

  @HiveField(10)
  final int? iconColor; // For material icons (Color.value)

  @HiveField(11)
  final String? subtitle;

  @HiveField(12)
  final bool autoFillEnabled;

  @HiveField(13)
  final double? autoFillAmount;

  @HiveField(14)
  final bool isShared;

  @HiveField(15)
  final String? linkedAccountId;

  // NEW: Debt tracking fields
  @HiveField(20)
  final bool isDebtEnvelope;

  @HiveField(21)
  final double? startingDebt;

  // NEW: Time-based goal tracking (for loan terms)
  @HiveField(22)
  final DateTime? termStartDate;

  @HiveField(23)
  final int? termMonths;

  @HiveField(24)
  final double? monthlyPayment;

  // NEW: Sync tracking fields (nullable for backward compatibility)
  @HiveField(25)
  final bool? isSynced;

  @HiveField(26)
  final DateTime? lastUpdated;

  Envelope({
    required this.id,
    required this.name,
    required this.userId,
    this.currentAmount = 0.0,
    this.targetAmount,
    this.targetDate,
    this.groupId,
    this.emoji,
    this.iconType,
    this.iconValue,
    this.iconColor,
    this.subtitle,
    this.autoFillEnabled = false,
    this.autoFillAmount,
    this.isShared = true,
    this.linkedAccountId,
    this.isDebtEnvelope = false,
    this.startingDebt,
    this.termStartDate,
    this.termMonths,
    this.monthlyPayment,
    this.isSynced,
    this.lastUpdated,
  });

  /// Get icon widget for display
  Widget getIconWidget(ThemeData theme, {double size = 40}) {
    // New icon system
    if (iconType != null && iconValue != null) {
      switch (iconType) {
        case 'emoji':
          return Text(iconValue!, style: TextStyle(fontSize: size * 0.8));

        case 'materialIcon':
          final iconData = _getIconDataFromName(iconValue!);
          return Icon(
            iconData,
            size: size,
            color: iconColor != null
                ? Color(iconColor!)
                : theme.colorScheme.primary,
          );

        case 'companyLogo':
          // FIXED: Using Google Favicons with caching!
          final logoUrl =
              'https://www.google.com/s2/favicons?sz=128&domain=${iconValue!}';

          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: logoUrl,
              width: size,
              height: size,
              fit: BoxFit.contain,
              placeholder: (context, url) => SizedBox(
                width: size,
                height: size,
                child: Center(
                  child: SizedBox(
                    width: size * 0.5,
                    height: size * 0.5,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              errorWidget: (context, url, error) {
                // Fallback to emoji if available, otherwise business icon
                if (emoji != null) {
                  return Text(emoji!, style: TextStyle(fontSize: size * 0.8));
                }
                return Icon(
                  Icons.business,
                  size: size,
                  color: theme.colorScheme.primary,
                );
              },
            ),
          );
      }
    }

    // Fallback to old emoji system
    if (emoji != null) {
      return Text(emoji!, style: TextStyle(fontSize: size * 0.8));
    }

    // Default fallback
    return Icon(
      Icons.account_balance_wallet,
      size: size,
      color: theme.colorScheme.primary,
    );
  }

  /// Helper to convert icon name string to IconData
  IconData _getIconDataFromName(String name) {
    return materialIconsDatabase[name]?['icon'] as IconData? ?? Icons.circle;
  }

  // =========================================================================
  // DEBT TRACKING HELPERS
  // =========================================================================

  /// Whether this envelope is tracking debt (negative balance)
  bool get isDebt => currentAmount < 0;

  /// Progress for debt payoff (if tracking debt)
  /// Returns percentage of debt paid off (0.0 to 1.0)
  double? get debtPayoffProgress {
    if (!isDebtEnvelope || startingDebt == null || startingDebt! >= 0) {
      return null;
    }

    // Example: Started at -£5,000, now at -£3,000 = 40% paid off
    final amountPaid = startingDebt! - currentAmount; // £2,000 paid
    final totalDebt = startingDebt!.abs(); // £5,000 total
    return (amountPaid / totalDebt).clamp(0.0, 1.0);
  }

  /// Remaining debt (absolute value)
  double get remainingDebt => currentAmount < 0 ? currentAmount.abs() : 0.0;

  /// Amount paid off from starting debt
  double get amountPaidOff {
    if (!isDebtEnvelope || startingDebt == null) return 0.0;
    return (startingDebt! - currentAmount).abs();
  }

  // =========================================================================
  // TIME-BASED PROGRESS HELPERS
  // =========================================================================

  /// Calculate time-based progress (for loans with fixed terms)
  /// Returns percentage of term elapsed (0.0 to 1.0)
  double? get termProgress {
    if (termStartDate == null || termMonths == null) return null;

    final now = DateTime.now();
    final monthsElapsed = _monthsBetween(termStartDate!, now);

    return (monthsElapsed / termMonths!).clamp(0.0, 1.0);
  }

  /// Months remaining in term
  int? get monthsRemaining {
    if (termStartDate == null || termMonths == null) return null;

    final now = DateTime.now();
    final monthsElapsed = _monthsBetween(termStartDate!, now);

    return (termMonths! - monthsElapsed).clamp(0, termMonths!);
  }

  /// Expected completion date based on term
  DateTime? get expectedCompletionDate {
    if (termStartDate == null || termMonths == null) return null;

    return DateTime(
      termStartDate!.year,
      termStartDate!.month + termMonths!,
      termStartDate!.day,
    );
  }

  /// Whether user is on track with payments
  /// Compares actual payments to expected payments based on monthly payment and elapsed time
  bool? get isOnTrack {
    if (!isDebtEnvelope || startingDebt == null || monthlyPayment == null) {
      return null;
    }

    final monthsElapsed = termProgress != null
        ? (termProgress! * termMonths!).round()
        : 0;

    final expectedPaid = monthlyPayment! * monthsElapsed;
    final actualPaid = (startingDebt! - currentAmount).abs();

    // On track if paid at least 90% of expected amount
    return actualPaid >= (expectedPaid * 0.9);
  }

  /// Helper: Calculate months between two dates
  int _monthsBetween(DateTime start, DateTime end) {
    return (end.year - start.year) * 12 + (end.month - start.month);
  }

  Envelope copyWith({
    String? id,
    String? name,
    String? userId,
    double? currentAmount,
    double? targetAmount,
    DateTime? targetDate,
    String? groupId,
    String? emoji,
    String? iconType,
    String? iconValue,
    int? iconColor,
    String? subtitle,
    bool? autoFillEnabled,
    double? autoFillAmount,
    bool? isShared,
    String? linkedAccountId,
    bool? isDebtEnvelope,
    double? startingDebt,
    DateTime? termStartDate,
    int? termMonths,
    double? monthlyPayment,
    bool? isSynced,
    DateTime? lastUpdated,
  }) {
    return Envelope(
      id: id ?? this.id,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      currentAmount: currentAmount ?? this.currentAmount,
      targetAmount: targetAmount ?? this.targetAmount,
      targetDate: targetDate ?? this.targetDate,
      groupId: groupId ?? this.groupId,
      emoji: emoji ?? this.emoji,
      iconType: iconType ?? this.iconType,
      iconValue: iconValue ?? this.iconValue,
      iconColor: iconColor ?? this.iconColor,
      subtitle: subtitle ?? this.subtitle,
      autoFillEnabled: autoFillEnabled ?? this.autoFillEnabled,
      autoFillAmount: autoFillAmount ?? this.autoFillAmount,
      isShared: isShared ?? this.isShared,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      isDebtEnvelope: isDebtEnvelope ?? this.isDebtEnvelope,
      startingDebt: startingDebt ?? this.startingDebt,
      termStartDate: termStartDate ?? this.termStartDate,
      termMonths: termMonths ?? this.termMonths,
      monthlyPayment: monthlyPayment ?? this.monthlyPayment,
      isSynced: isSynced ?? this.isSynced,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'userId': userId,
      'currentAmount': currentAmount,
      'targetAmount': targetAmount,
      'targetDate': targetDate != null ? Timestamp.fromDate(targetDate!) : null,
      'groupId': groupId,
      'emoji': emoji,
      'iconType': iconType,
      'iconValue': iconValue,
      'iconColor': iconColor,
      'subtitle': subtitle,
      'autoFillEnabled': autoFillEnabled,
      'autoFillAmount': autoFillAmount,
      'isShared': isShared,
      'linkedAccountId': linkedAccountId,
      'isDebtEnvelope': isDebtEnvelope,
      'startingDebt': startingDebt,
      'termStartDate':
          termStartDate != null ? Timestamp.fromDate(termStartDate!) : null,
      'termMonths': termMonths,
      'monthlyPayment': monthlyPayment,
      'isSynced': isSynced ?? true, // Default to synced for Firebase data
      'lastUpdated': Timestamp.fromDate(lastUpdated ?? DateTime.now()),
    };
  }

  factory Envelope.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Envelope ${doc.id} has no data');
    }

    double toDouble(dynamic v, {double fallback = 0.0}) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fallback;
      return fallback;
    }

    return Envelope(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      userId: (data['userId'] as String?) ?? '',
      currentAmount: toDouble(data['currentAmount'], fallback: 0.0),
      targetAmount: (data['targetAmount'] == null)
          ? null
          : toDouble(data['targetAmount']),
      targetDate: (data['targetDate'] as Timestamp?)?.toDate(),
      groupId: data['groupId'] as String?,
      emoji: data['emoji'] as String?,
      iconType: data['iconType'] as String?,
      iconValue: data['iconValue'] as String?,
      iconColor: data['iconColor'] as int?,
      subtitle: data['subtitle'] as String?,
      autoFillEnabled: (data['autoFillEnabled'] as bool?) ?? false,
      autoFillAmount: (data['autoFillAmount'] == null)
          ? null
          : toDouble(data['autoFillAmount']),
      isShared: (data['isShared'] as bool?) ?? true,
      linkedAccountId: data['linkedAccountId'] as String?,
      isDebtEnvelope: (data['isDebtEnvelope'] as bool?) ?? false,
      startingDebt: (data['startingDebt'] == null)
          ? null
          : toDouble(data['startingDebt']),
      termStartDate: (data['termStartDate'] as Timestamp?)?.toDate(),
      termMonths: data['termMonths'] as int?,
      monthlyPayment: (data['monthlyPayment'] == null)
          ? null
          : toDouble(data['monthlyPayment']),
      isSynced: (data['isSynced'] as bool?) ?? true, // Firestore data is already synced
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
