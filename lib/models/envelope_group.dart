// lib/models/envelope_group.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EnvelopeGroup {
  final String id;
  final String name;
  final String userId;
  final String? emoji;
  final String colorName;
  final bool payDayEnabled;
  final bool isShared;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EnvelopeGroup({
    required this.id,
    required this.name,
    required this.userId,
    this.emoji,
    this.colorName = 'Primary',
    this.payDayEnabled = false,
    this.isShared = true,
    this.createdAt,
    this.updatedAt,
  });

  factory EnvelopeGroup.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return EnvelopeGroup(
      id: doc.id,
      name: data?['name'] ?? '',
      userId: data?['userId'] ?? '',
      emoji: data?['emoji'],
      colorName: data?['colorName'] ?? 'Primary',
      payDayEnabled: data?['payDayEnabled'] ?? false,
      isShared: data?['isShared'] ?? true,
      createdAt: data?['createdAt'] != null
          ? (data!['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data?['updatedAt'] != null
          ? (data!['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'userId': userId,
      'emoji': emoji,
      'colorName': colorName,
      'payDayEnabled': payDayEnabled,
      'isShared': isShared,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  EnvelopeGroup copyWith({
    String? id,
    String? name,
    String? userId,
    String? emoji,
    String? colorName,
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
      colorName: colorName ?? this.colorName,
      payDayEnabled: payDayEnabled ?? this.payDayEnabled,
      isShared: isShared ?? this.isShared,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// UPDATED: Hybrid system with Inverted Logic for Dark Binders
/// - Black Binder: Identity is WHITE (Text/Spine) on DARK background
/// - Brown Binder: Identity is CREAM (Text/Spine) on WALNUT background
/// - Grey Binder: Preserved as is (Medium Grey on Dark Grey)
/// - Others: Standard Pastel (Vibrant Identity on Light Pastel background)
class GroupColors {
  // --- DEFINITIONS ---

  // Standard Identities
  static const Color _greyIdentity = Color(0xFF757575);

  // Inverted Identities (These act as Text/Border colors)
  static const Color _blackIdentity = Colors.white;
  static const Color _brownIdentity = Color(
    0xFFFFF8E1,
  ); // Manila/Cream (Amber 50)

  // Dark Backgrounds
  static const Color _blackBg = Color(0xFF121212); // Deep Black
  static const Color _brownBg = Color(0xFF4E342E); // Walnut (Brown 800)
  static const Color _greyBg = Color(0xFF424242); // Dark Grey

  // --- METHODS ---

  /// Returns the "Identity" color.
  /// For dark binders, this returns the LIGHT text color so that
  /// UI elements using this color (text, spines, buttons) pop against the dark BG.
  static Color getThemedColor(String? colorName, ColorScheme theme) {
    final safeName = colorName ?? 'Primary';

    switch (safeName) {
      case 'Primary':
        return theme.primary;
      case 'Secondary':
        return theme.secondary;

      // Standard Colors
      case 'Red':
        return const Color(0xFFE53935);
      case 'Orange':
        return const Color(0xFFFB8C00);
      case 'Yellow':
        return const Color(0xFFFDD835);
      case 'Green':
        return const Color(0xFF43A047);
      case 'Blue':
        return const Color(0xFF1E88E5);
      case 'Purple':
        return const Color(0xFF8E24AA);
      case 'Pink':
        return const Color(0xFFD81B60);

      // Special Inverted Binders
      case 'Brown':
        return _brownIdentity; // Returns Cream
      case 'Black':
        return _blackIdentity; // Returns White
      case 'Grey':
        return _greyIdentity; // Returns Grey

      // Legacy
      case 'Rose':
        return const Color(0xFFE91E63);
      case 'Coral':
        return const Color(0xFFFF5722);
      case 'Amber':
        return const Color(0xFFFFA000);
      case 'Lime':
        return const Color(0xFF689F38);
      case 'Teal':
        return const Color(0xFF00897B);
      case 'Sky':
        return const Color(0xFF1976D2);
      case 'Indigo':
        return const Color(0xFF303F9F);

      default:
        return theme.primary;
    }
  }

  /// Get contrasting text color for a given background
  static Color getContrastingTextColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? const Color(0xFF212121) : Colors.white;
  }

  /// Get background tint
  static Color getBackgroundTint(Color groupColor) {
    // INVERTED LOGIC: If Identity is White/Cream, give Dark BG
    if (groupColor.value == _blackIdentity.value) return _blackBg;
    if (groupColor.value == _brownIdentity.value) return _brownBg;
    if (groupColor.value == _greyIdentity.value) return _greyBg;

    // STANDARD LOGIC: Light Pastel
    final hsl = HSLColor.fromColor(groupColor);
    return hsl.withLightness(0.95).withSaturation(0.25).toColor();
  }

  /// Get envelope card color
  static Color getEnvelopeCardColor(Color groupColor) {
    // INVERTED LOGIC
    if (groupColor.value == _blackIdentity.value)
      return const Color(0xFF2C2C2C);
    if (groupColor.value == _brownIdentity.value)
      return const Color(0xFF5D4037); // Slightly lighter Walnut
    if (groupColor.value == _greyIdentity.value) return const Color(0xFF616161);

    // STANDARD LOGIC
    final hsl = HSLColor.fromColor(groupColor);
    return hsl.withLightness(0.92).withSaturation(0.30).toColor();
  }

  /// Get left page color
  static Color getLeftPageColor(Color groupColor) {
    // INVERTED LOGIC
    if (groupColor.value == _blackIdentity.value)
      return const Color(0xFF1E1E1E);
    if (groupColor.value == _brownIdentity.value)
      return const Color(0xFF3E2723); // Dark Walnut
    if (groupColor.value == _greyIdentity.value) return const Color(0xFF424242);

    // STANDARD LOGIC
    final hsl = HSLColor.fromColor(groupColor);
    return hsl.withLightness(0.94).withSaturation(0.28).toColor();
  }

  /// Get right page color
  static Color getRightPageColor(Color groupColor) {
    // INVERTED LOGIC
    if (groupColor.value == _blackIdentity.value)
      return const Color(0xFF121212);
    if (groupColor.value == _brownIdentity.value)
      return const Color(0xFF321F1B); // Darker Walnut
    if (groupColor.value == _greyIdentity.value) return const Color(0xFF303030);

    // STANDARD LOGIC
    final hsl = HSLColor.fromColor(groupColor);
    return hsl.withLightness(0.93).withSaturation(0.32).toColor();
  }

  /// Get border color
  static Color getBorderColor(Color groupColor) {
    // INVERTED LOGIC: Border is same as Identity (Light)
    if (groupColor.value == _blackIdentity.value) return _blackIdentity;
    if (groupColor.value == _brownIdentity.value) return _brownIdentity;
    if (groupColor.value == _greyIdentity.value) return Colors.white70;

    // STANDARD LOGIC: Darker border
    final hsl = HSLColor.fromColor(groupColor);
    return hsl.withLightness(0.50).withSaturation(0.70).toColor();
  }

  /// Get accent text color
  static Color getAccentTextColor(Color groupColor) {
    // INVERTED LOGIC: Text is Identity (Light)
    if (groupColor.value == _blackIdentity.value) return _blackIdentity;
    if (groupColor.value == _brownIdentity.value) return _brownIdentity;
    if (groupColor.value == _greyIdentity.value) return Colors.white;

    // STANDARD LOGIC: Dark Text
    final hsl = HSLColor.fromColor(groupColor);
    return hsl.withLightness(0.35).toColor();
  }

  static const colorNames = [
    'Red',
    'Orange',
    'Yellow',
    'Green',
    'Blue',
    'Purple',
    'Pink',
    'Brown',
    'Black',
    'Grey',
  ];

  static String getColorDisplayName(String colorName) {
    return colorName;
  }
}
