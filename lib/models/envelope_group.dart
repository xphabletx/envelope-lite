// lib/models/envelope_group.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive/hive.dart';
import '../data/material_icons_database.dart';

part 'envelope_group.g.dart';

@HiveType(typeId: 2)
class EnvelopeGroup {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String userId;

  // OLD: Single emoji field (keep for backwards compatibility)
  @HiveField(3)
  final String? emoji;

  // NEW: Icon system (same as Envelope)
  @HiveField(4)
  final String? iconType; // 'emoji', 'materialIcon', 'companyLogo'

  @HiveField(5)
  final String? iconValue; // emoji char, icon name, or domain

  @HiveField(6)
  final int? iconColor; // For material icons (Color.value)

  @HiveField(7)
  final int colorIndex;

  @HiveField(8)
  final bool payDayEnabled;

  @HiveField(9)
  final bool isShared;

  @HiveField(10)
  final DateTime? createdAt;

  @HiveField(11)
  final DateTime? updatedAt;

  EnvelopeGroup({
    required this.id,
    required this.name,
    required this.userId,
    this.emoji,
    this.iconType,
    this.iconValue,
    this.iconColor,
    this.colorIndex = 0,
    this.payDayEnabled = false,
    this.isShared = true,
    this.createdAt,
    this.updatedAt,
  });

  EnvelopeGroup copyWith({
    String? id,
    String? name,
    String? userId,
    String? emoji,
    String? iconType,
    String? iconValue,
    int? iconColor,
    int? colorIndex,
    bool? payDayEnabled,
    bool? isShared,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EnvelopeGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      emoji: emoji ?? this.emoji,
      iconType: iconType ?? this.iconType,
      iconValue: iconValue ?? this.iconValue,
      iconColor: iconColor ?? this.iconColor,
      colorIndex: colorIndex ?? this.colorIndex,
      payDayEnabled: payDayEnabled ?? this.payDayEnabled,
      isShared: isShared ?? this.isShared,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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
            iconData ?? Icons.folder_open,
            size: size,
            color: effectiveIconColor,
          );

        case 'companyLogo':
          final logoUrl =
              'https://www.google.com/s2/favicons?sz=128&domain=$iconValue';
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
                Icons.folder_open,
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

    // Final fallback
    return Icon(
      Icons.folder_open,
      size: size,
      color: theme.colorScheme.primary,
    );
  }
}
