// lib/models/envelope.dart
// UPDATED: Using Google Favicons + Cached Network Image

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/material_icons_database.dart';

class Envelope {
  final String id;
  String name;
  final String userId;
  double currentAmount;
  double? targetAmount;
  DateTime? targetDate;
  String? groupId;

  // OLD: Single emoji field (keep for backwards compatibility)
  final String? emoji;

  // NEW: Icon system
  final String? iconType; // 'emoji', 'materialIcon', 'companyLogo'
  final String? iconValue; // emoji char, icon name, or domain
  final int? iconColor; // For material icons (Color.value)

  final String? subtitle;
  final bool autoFillEnabled;
  final double? autoFillAmount;
  final bool isShared;
  final String? linkedAccountId;

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
    );
  }
}
