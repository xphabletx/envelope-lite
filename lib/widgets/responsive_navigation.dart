// lib/widgets/responsive_navigation.dart
import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';

/// A responsive navigation widget that switches between BottomNavigationBar
/// (portrait) and NavigationRail (landscape) based on screen orientation.
class ResponsiveNavigation extends StatelessWidget {
  const ResponsiveNavigation({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.elevation = 8,
    this.selectedLabelStyle,
    this.unselectedLabelStyle,
    this.child,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<ResponsiveNavigationDestination> destinations;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final double elevation;
  final TextStyle? selectedLabelStyle;
  final TextStyle? unselectedLabelStyle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final theme = Theme.of(context);

    // Use NavigationRail in landscape mode for phones and tablets
    if (responsive.isLandscape) {
      return Row(
        children: [
          NavigationRail(
            backgroundColor: backgroundColor ?? theme.scaffoldBackgroundColor,
            selectedIndex: currentIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: NavigationRailLabelType.selected,
            selectedIconTheme: IconThemeData(
              color: selectedItemColor ?? theme.colorScheme.primary,
              size: 24,
            ),
            unselectedIconTheme: IconThemeData(
              color: unselectedItemColor ?? Colors.grey.shade600,
              size: 24,
            ),
            selectedLabelTextStyle: selectedLabelStyle?.copyWith(fontSize: 12),
            unselectedLabelTextStyle: unselectedLabelStyle?.copyWith(fontSize: 11),
            destinations: destinations.map((dest) {
              return NavigationRailDestination(
                icon: dest.icon,
                selectedIcon: dest.selectedIcon,
                label: Text(dest.label),
              );
            }).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          if (child != null) Expanded(child: child!),
        ],
      );
    }

    // Use BottomNavigationBar in portrait mode
    return Column(
      children: [
        if (child != null) Expanded(child: child!),
        BottomNavigationBar(
          backgroundColor: backgroundColor ?? theme.scaffoldBackgroundColor,
          selectedItemColor: selectedItemColor ?? theme.colorScheme.primary,
          unselectedItemColor: unselectedItemColor ?? Colors.grey.shade600,
          elevation: elevation,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: selectedLabelStyle,
          unselectedLabelStyle: unselectedLabelStyle,
          items: destinations.map((dest) {
            return BottomNavigationBarItem(
              icon: dest.icon,
              activeIcon: dest.selectedIcon,
              label: dest.label,
            );
          }).toList(),
          currentIndex: currentIndex,
          onTap: onDestinationSelected,
        ),
      ],
    );
  }
}

/// Navigation destination for responsive navigation
class ResponsiveNavigationDestination {
  const ResponsiveNavigationDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.key,
  });

  final Widget icon;
  final Widget selectedIcon;
  final String label;
  final Key? key;
}

/// A responsive app bar that can auto-hide in landscape mode
class ResponsiveAppBar extends StatefulWidget implements PreferredSizeWidget {
  const ResponsiveAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.backgroundColor,
    this.elevation = 0,
    this.scrolledUnderElevation = 0,
    this.autoHideInLandscape = true,
    this.height,
  });

  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final Color? backgroundColor;
  final double elevation;
  final double scrolledUnderElevation;
  final bool autoHideInLandscape;
  final double? height;

  @override
  State<ResponsiveAppBar> createState() => _ResponsiveAppBarState();

  @override
  Size get preferredSize {
    // Default to normal toolbar height
    // The actual height will be controlled by the build method
    return Size.fromHeight(height ?? kToolbarHeight);
  }
}

class _ResponsiveAppBarState extends State<ResponsiveAppBar> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final theme = Theme.of(context);

    // In portrait mode, show normal app bar
    if (!responsive.isLandscape || !widget.autoHideInLandscape) {
      return AppBar(
        title: widget.title,
        actions: widget.actions,
        leading: widget.leading,
        backgroundColor: widget.backgroundColor ?? theme.scaffoldBackgroundColor,
        elevation: widget.elevation,
        scrolledUnderElevation: widget.scrolledUnderElevation,
      );
    }

    // In landscape mode, show collapsible/expandable app bar
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _isExpanded ? kToolbarHeight : 32,
      child: AppBar(
        title: _isExpanded ? widget.title : null,
        leading: widget.leading,
        backgroundColor: widget.backgroundColor ?? theme.scaffoldBackgroundColor,
        elevation: widget.elevation,
        scrolledUnderElevation: widget.scrolledUnderElevation,
        titleSpacing: _isExpanded ? null : 0,
        leadingWidth: _isExpanded ? null : 40,
        toolbarHeight: _isExpanded ? kToolbarHeight : 32,
        actions: [
          if (!_isExpanded)
            IconButton(
              icon: const Icon(Icons.expand_more, size: 20),
              onPressed: () => setState(() => _isExpanded = true),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
            )
          else ...[
            if (widget.actions != null) ...widget.actions!,
            IconButton(
              icon: const Icon(Icons.expand_less, size: 20),
              onPressed: () => setState(() => _isExpanded = false),
              padding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );
  }
}

/// Wrapper widget that provides responsive scaffold with navigation
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.currentIndex,
    required this.onNavigationChanged,
    required this.destinations,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.selectedLabelStyle,
    this.unselectedLabelStyle,
  });

  final int currentIndex;
  final ValueChanged<int> onNavigationChanged;
  final List<ResponsiveNavigationDestination> destinations;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final TextStyle? selectedLabelStyle;
  final TextStyle? unselectedLabelStyle;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final theme = Theme.of(context);

    // Portrait mode: Traditional scaffold with bottom nav
    if (!responsive.isLandscape) {
      return Scaffold(
        appBar: appBar,
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: backgroundColor ?? theme.scaffoldBackgroundColor,
          selectedItemColor: selectedItemColor ?? theme.colorScheme.primary,
          unselectedItemColor: unselectedItemColor ?? Colors.grey.shade600,
          elevation: 8,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: selectedLabelStyle,
          unselectedLabelStyle: unselectedLabelStyle,
          items: destinations.map((dest) {
            return BottomNavigationBarItem(
              icon: dest.icon,
              activeIcon: dest.selectedIcon,
              label: dest.label,
            );
          }).toList(),
          currentIndex: currentIndex,
          onTap: onNavigationChanged,
        ),
      );
    }

    // Landscape mode: NavigationRail + compact app bar
    return Scaffold(
      backgroundColor: backgroundColor ?? theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: backgroundColor ?? theme.scaffoldBackgroundColor,
            selectedIndex: currentIndex,
            onDestinationSelected: onNavigationChanged,
            labelType: NavigationRailLabelType.selected,
            selectedIconTheme: IconThemeData(
              color: selectedItemColor ?? theme.colorScheme.primary,
              size: 24,
            ),
            unselectedIconTheme: IconThemeData(
              color: unselectedItemColor ?? Colors.grey.shade600,
              size: 24,
            ),
            selectedLabelTextStyle: selectedLabelStyle?.copyWith(fontSize: 12),
            unselectedLabelTextStyle: unselectedLabelStyle?.copyWith(fontSize: 11),
            destinations: destinations.map((dest) {
              return NavigationRailDestination(
                icon: dest.icon,
                selectedIcon: dest.selectedIcon,
                label: Text(dest.label),
              );
            }).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Column(
              children: [
                if (appBar != null) appBar!,
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
