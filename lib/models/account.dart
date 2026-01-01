// lib/models/account.dart
import 'package:flutter/material.dart';
import 'package:stuffrite/data/material_icons_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive/hive.dart';

part 'account.g.dart';

@HiveType(typeId: 101)
enum AccountType {
  @HiveField(0)
  bankAccount,
  @HiveField(1)
  creditCard,
}

@HiveType(typeId: 1)
class Account {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double currentBalance;

  @HiveField(3)
  final String userId;

  @HiveField(4)
  final String? emoji; // Legacy

  @HiveField(5)
  final String? colorName;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final DateTime lastUpdated;

  @HiveField(8)
  final bool isDefault;

  @HiveField(9)
  final bool isShared;

  @HiveField(10)
  final String? workspaceId;

  // NEW: Icon system
  @HiveField(11)
  final String? iconType; // 'emoji', 'materialIcon', 'companyLogo'

  @HiveField(12)
  final String? iconValue; // emoji char, icon name, or domain

  @HiveField(13)
  final int? iconColor; // For material icons (Color.value)

  // NEW: Credit card support
  @HiveField(14)
  final AccountType accountType;

  @HiveField(15)
  final double? creditLimit;

  // NEW: Pay day auto-fill support
  @HiveField(16)
  final bool? _payDayAutoFillEnabled;

  @HiveField(17)
  final double? payDayAutoFillAmount;

  // NEW: Sync tracking field (nullable for backward compatibility)
  @HiveField(18)
  final bool? isSynced;

  // Getter with default for backward compatibility
  bool get payDayAutoFillEnabled => _payDayAutoFillEnabled ?? false;

  Account({
    required this.id,
    required this.name,
    required this.currentBalance,
    required this.userId,
    this.emoji,
    this.colorName,
    required this.createdAt,
    required this.lastUpdated,
    this.isDefault = false,
    this.isShared = false,
    this.workspaceId,
    this.iconType,
    this.iconValue,
    this.iconColor,
    this.accountType = AccountType.bankAccount,
    this.creditLimit,
    bool payDayAutoFillEnabled = false,
    this.payDayAutoFillAmount,
    this.isSynced,
  }) : _payDayAutoFillEnabled = payDayAutoFillEnabled;

  /// Get icon widget for display
  Widget getIconWidget(ThemeData theme, {double size = 40}) {
    final effectiveIconColor = iconColor != null
        ? Color(iconColor!)
        : theme.colorScheme.primary;

    // New icon system
    if (iconType != null && iconValue != null) {
      switch (iconType) {
        case 'emoji':
          return Text(
            iconValue!,
            style: TextStyle(fontSize: size * 0.8),
          );

        case 'materialIcon':
          final iconData =
              materialIconsDatabase[iconValue]?['icon'] as IconData?;
          return Icon(
            iconData ?? Icons.help_outline,
            size: size,
            color: effectiveIconColor,
          );

        case 'companyLogo':
          final logoUrl =
              'https://www.google.com/s2/favicons?sz=128&domain=${iconValue!}';
          return ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.1),
            child: CachedNetworkImage(
              imageUrl: logoUrl,
              width: size,
              height: size,
              fit: BoxFit.contain,
              placeholder: (context, url) => SizedBox(
                width: size,
                height: size,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary.withAlpha(128),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Icon(
                Icons.business,
                size: size,
                color: theme.colorScheme.secondary,
              ),
            ),
          );
      }
    }

    // Fallback to old emoji system
    if (emoji != null && emoji!.isNotEmpty) {
      return Text(
        emoji!,
        style: TextStyle(fontSize: size * 0.8),
      );
    }

    // Default fallback
    return Icon(
      Icons.account_balance_wallet,
      size: size,
      color: theme.colorScheme.primary,
    );
  }

  // =========================================================================
  // CREDIT CARD HELPERS
  // =========================================================================

  /// Whether this is a credit card account
  bool get isCreditCard => accountType == AccountType.creditCard;

  /// Whether the account has debt (negative balance)
  bool get isDebt => currentBalance < 0;

  /// Available credit (for credit cards only)
  /// Calculated as: creditLimit + currentBalance (balance is negative)
  double get availableCredit {
    if (!isCreditCard || creditLimit == null) return 0.0;
    return creditLimit! + currentBalance; // balance is negative, so this subtracts the debt
  }

  /// Credit utilization percentage (0.0 to 1.0)
  /// Important metric for credit score
  double get creditUtilization {
    if (!isCreditCard || creditLimit == null || creditLimit == 0) return 0.0;
    return (currentBalance.abs() / creditLimit!).clamp(0.0, 1.0);
  }

  Account copyWith({
    String? name,
    double? currentBalance,
    String? emoji,
    String? colorName,
    DateTime? lastUpdated,
    bool? isDefault,
    bool? isShared,
    String? iconType,
    String? iconValue,
    int? iconColor,
    AccountType? accountType,
    double? creditLimit,
    bool? payDayAutoFillEnabled,
    double? payDayAutoFillAmount,
    bool? isSynced,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      currentBalance: currentBalance ?? this.currentBalance,
      userId: userId,
      emoji: emoji ?? this.emoji,
      colorName: colorName ?? this.colorName,
      createdAt: createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isDefault: isDefault ?? this.isDefault,
      isShared: isShared ?? this.isShared,
      workspaceId: workspaceId,
      iconType: iconType ?? this.iconType,
      iconValue: iconValue ?? this.iconValue,
      iconColor: iconColor ?? this.iconColor,
      accountType: accountType ?? this.accountType,
      creditLimit: creditLimit ?? this.creditLimit,
      payDayAutoFillEnabled: payDayAutoFillEnabled ?? this.payDayAutoFillEnabled,
      payDayAutoFillAmount: payDayAutoFillAmount ?? this.payDayAutoFillAmount,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  String toString() {
    return 'Account(id: $id, name: $name, balance: $currentBalance, isDefault: $isDefault, icon: $iconValue)';
  }
}