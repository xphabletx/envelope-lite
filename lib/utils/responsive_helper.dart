import 'package:flutter/material.dart';

class ResponsiveHelper {
  final BuildContext context;

  ResponsiveHelper(this.context);

  // Screen dimensions
  double get width => MediaQuery.of(context).size.width;
  double get height => MediaQuery.of(context).size.height;

  // Orientation
  bool get isLandscape => MediaQuery.of(context).orientation == Orientation.landscape;
  bool get isPortrait => MediaQuery.of(context).orientation == Orientation.portrait;

  // Device type detection
  bool get isPhone => width < 600;
  bool get isTablet => width >= 600 && width < 1200;
  bool get isDesktop => width >= 1200;

  // Responsive breakpoints
  bool get isSmall => width < 600;  // Phone portrait
  bool get isMedium => width >= 600 && width < 900; // Tablet portrait / Phone landscape
  bool get isLarge => width >= 900; // Tablet landscape / Desktop

  // Responsive values
  double responsive({
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    if (isDesktop && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }

  // Grid columns based on screen size
  int get gridColumns {
    if (isLarge) return 3;
    if (isMedium) return 2;
    return 1;
  }

  // Safe padding for landscape (avoid notch)
  EdgeInsets get safePadding {
    final viewPadding = MediaQuery.of(context).viewPadding;
    if (isLandscape) {
      return EdgeInsets.only(
        left: viewPadding.left + 16,
        right: viewPadding.right + 16,
        top: viewPadding.top + 8,
        bottom: viewPadding.bottom + 8,
      );
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  }
}

// Extension for easy access
extension ResponsiveContext on BuildContext {
  ResponsiveHelper get responsive => ResponsiveHelper(this);
}
