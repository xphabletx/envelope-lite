import 'package:flutter/material.dart';

/// Adaptive layout that switches between portrait and landscape
class ResponsiveLayout extends StatelessWidget {
  final Widget portrait;
  final Widget? landscape;
  final Widget Function(BuildContext context, Orientation orientation)? builder;

  const ResponsiveLayout({
    super.key,
    required this.portrait,
    this.landscape,
    this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;

    // Use builder if provided
    if (builder != null) {
      return builder!(context, orientation);
    }

    // Use landscape layout if provided and in landscape mode
    if (orientation == Orientation.landscape && landscape != null) {
      return landscape!;
    }

    // Default to portrait
    return portrait;
  }
}

/// Two-column layout for landscape (master-detail pattern)
class TwoColumnLayout extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double leftFlex;
  final double rightFlex;

  const TwoColumnLayout({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: leftFlex.toInt(),
          child: left,
        ),
        Expanded(
          flex: rightFlex.toInt(),
          child: right,
        ),
      ],
    );
  }
}

/// Grid that adapts columns based on screen size
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int? forceColumns;
  final double spacing;
  final double runSpacing;
  final double childAspectRatio;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.forceColumns,
    this.spacing = 16,
    this.runSpacing = 16,
    this.childAspectRatio = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    final columns = forceColumns ?? _getResponsiveColumns(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: runSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }

  int _getResponsiveColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 900) return 3;
    if (width >= 600) return 2;
    return 1;
  }
}
