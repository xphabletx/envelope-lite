import 'package:flutter/material.dart';

/// Global service to manage focus behavior across the app
/// Prevents automatic keyboard opening and manages field navigation
class FocusManagerService {
  static final FocusManagerService _instance = FocusManagerService._internal();
  factory FocusManagerService() => _instance;
  FocusManagerService._internal();

  /// Dismisses keyboard without auto-refocusing
  static void dismissKeyboard(BuildContext context) {
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      currentFocus.focusedChild!.unfocus();
    }
  }

  /// Requests focus without automatic keyboard if not user-initiated
  static void requestFocusSilently(BuildContext context, FocusNode node) {
    // Only request focus, keyboard will show when user taps
    node.requestFocus();
  }

  /// Moves focus to next field with auto-scroll
  static void moveToNextField(
    BuildContext context, {
    FocusNode? currentNode,
    FocusNode? nextNode,
  }) {
    if (nextNode != null) {
      nextNode.requestFocus();
    } else {
      FocusScope.of(context).nextFocus();
    }
  }

  /// Moves focus to previous field with auto-scroll
  static void moveToPreviousField(BuildContext context) {
    FocusScope.of(context).previousFocus();
  }

  /// Unfocuses current field and dismisses keyboard
  static void unfocus(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  /// Creates a focus node that won't auto-open keyboard
  static FocusNode createManagedFocusNode({
    bool skipTraversal = false,
    bool canRequestFocus = true,
  }) {
    return FocusNode(
      skipTraversal: skipTraversal,
      canRequestFocus: canRequestFocus,
    );
  }

  /// Ensures a widget is visible in its scrollable ancestor
  static void ensureVisible(
    BuildContext context, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
    double alignment = 0.5,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        context,
        duration: duration,
        curve: curve,
        alignment: alignment,
      );
    });
  }
}

/// A mixin to help manage focus nodes in stateful widgets
mixin FocusManagement<T extends StatefulWidget> on State<T> {
  final List<FocusNode> _focusNodes = [];

  /// Creates and registers a managed focus node
  FocusNode createFocusNode({
    bool skipTraversal = false,
    bool canRequestFocus = true,
  }) {
    final node = FocusManagerService.createManagedFocusNode(
      skipTraversal: skipTraversal,
      canRequestFocus: canRequestFocus,
    );
    _focusNodes.add(node);
    return node;
  }

  /// Disposes all registered focus nodes
  void disposeFocusNodes() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    _focusNodes.clear();
  }

  @override
  void dispose() {
    disposeFocusNodes();
    super.dispose();
  }
}

/// Helper to build a form with managed focus navigation
class ManagedFocusForm extends StatefulWidget {
  final Widget child;
  final GlobalKey<FormState>? formKey;
  final AutovalidateMode? autovalidateMode;
  final VoidCallback? onChanged;

  const ManagedFocusForm({
    super.key,
    required this.child,
    this.formKey,
    this.autovalidateMode,
    this.onChanged,
  });

  @override
  State<ManagedFocusForm> createState() => _ManagedFocusFormState();
}

class _ManagedFocusFormState extends State<ManagedFocusForm> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Dismiss keyboard when tapping outside fields
      onTap: () => FocusManagerService.dismissKeyboard(context),
      child: Form(
        key: widget.formKey,
        autovalidateMode: widget.autovalidateMode,
        onChanged: widget.onChanged,
        child: widget.child,
      ),
    );
  }
}
