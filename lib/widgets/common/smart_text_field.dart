import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A smart text field that handles:
/// - Context-aware keyboard actions (next vs done)
/// - Auto-scroll when focused
/// - Focus management for field navigation
/// - No automatic keyboard opening
class SmartTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefix;
  final Widget? suffix;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final bool isLastField;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final String? Function(String?)? validator;
  final AutovalidateMode? autovalidateMode;
  final bool autofocus;
  final EdgeInsetsGeometry? contentPadding;
  final InputDecoration? decoration;
  final TextStyle? style;
  final bool obscureText;
  final TextCapitalization textCapitalization;
  final TextAlign? textAlign;
  final int? maxLength;
  final VoidCallback? onEditingComplete;
  final void Function(PointerDownEvent)? onTapOutside;
  final bool autocorrect;
  final bool enableSuggestions;

  const SmartTextField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.prefix,
    this.suffix,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.nextFocusNode,
    this.isLastField = false,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.validator,
    this.autovalidateMode,
    this.autofocus = false,
    this.contentPadding,
    this.decoration,
    this.style,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
    this.textAlign,
    this.maxLength,
    this.onEditingComplete,
    this.onTapOutside,
    this.autocorrect = true,
    this.enableSuggestions = true,
  });

  @override
  State<SmartTextField> createState() => _SmartTextFieldState();
}

class _SmartTextFieldState extends State<SmartTextField> {
  late FocusNode _internalFocusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = widget.focusNode ?? FocusNode();
    _internalFocusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(SmartTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle focus node changes
    if (widget.focusNode != oldWidget.focusNode) {
      // Remove listener from old focus node
      _internalFocusNode.removeListener(_onFocusChange);

      // Dispose old internal focus node if we created it
      if (oldWidget.focusNode == null) {
        _internalFocusNode.dispose();
      }

      // Set up new focus node
      _internalFocusNode = widget.focusNode ?? FocusNode();
      _internalFocusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _internalFocusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _internalFocusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    // Safety check: don't proceed if widget is no longer mounted
    if (!mounted) return;

    if (_internalFocusNode.hasFocus != _hasFocus) {
      setState(() {
        _hasFocus = _internalFocusNode.hasFocus;
      });

      // Auto-scroll to this field when it gains focus
      if (_hasFocus) {
        _ensureVisible();
      }
    }
  }

  void _ensureVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final context = this.context;
      final renderObject = context.findRenderObject();

      if (renderObject == null) return;

      // Try to find the nearest Scrollable
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5, // Center the field in the viewport
      );
    });
  }

  void _handleSubmitted(String value) {
    if (widget.onSubmitted != null) {
      widget.onSubmitted!(value);
    }

    // Move to next field or unfocus
    if (widget.nextFocusNode != null) {
      widget.nextFocusNode!.requestFocus();
    } else if (!widget.isLastField) {
      // Try to find next field automatically
      FocusScope.of(context).nextFocus();
    } else {
      // Last field - dismiss keyboard
      _internalFocusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine the TextInputAction based on context
    final textInputAction = widget.isLastField
        ? TextInputAction.done
        : (widget.nextFocusNode != null || !widget.isLastField)
            ? TextInputAction.next
            : TextInputAction.done;

    final effectiveDecoration = widget.decoration ??
        InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          prefix: widget.prefix,
          suffix: widget.suffix,
          contentPadding: widget.contentPadding,
          border: const OutlineInputBorder(),
        );

    return TextField(
      controller: widget.controller,
      focusNode: _internalFocusNode,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      onChanged: widget.onChanged,
      onSubmitted: _handleSubmitted,
      textInputAction: textInputAction,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      decoration: effectiveDecoration,
      style: widget.style,
      obscureText: widget.obscureText,
      textCapitalization: widget.textCapitalization,
      textAlign: widget.textAlign ?? TextAlign.start,
      maxLength: widget.maxLength,
      onEditingComplete: widget.onEditingComplete,
      onTapOutside: widget.onTapOutside,
      autocorrect: widget.autocorrect,
      enableSuggestions: widget.enableSuggestions,
      // CRITICAL: Never auto-show keyboard
      showCursor: true,
      enableInteractiveSelection: true,
    );
  }
}

/// A form field version of SmartTextField with validation support
class SmartTextFormField extends FormField<String> {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final bool isLastField;

  SmartTextFormField({
    super.key,
    required this.controller,
    super.validator,
    super.autovalidateMode,
    String? labelText,
    String? hintText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Widget? prefix,
    Widget? suffix,
    bool readOnly = false,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    this.focusNode,
    this.nextFocusNode,
    this.isLastField = false,
    int? maxLines = 1,
    int? minLines,
    bool enabled = true,
    bool autofocus = false,
    EdgeInsetsGeometry? contentPadding,
    InputDecoration? decoration,
    TextStyle? style,
    bool obscureText = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextAlign? textAlign,
    int? maxLength,
    VoidCallback? onEditingComplete,
    void Function(PointerDownEvent)? onTapOutside,
    bool autocorrect = true,
    bool enableSuggestions = true,
  }) : super(
          initialValue: controller.text,
          builder: (FormFieldState<String> field) {
            final effectiveDecoration = decoration ??
                InputDecoration(
                  labelText: labelText,
                  hintText: hintText,
                  prefix: prefix,
                  suffix: suffix,
                  contentPadding: contentPadding,
                  border: const OutlineInputBorder(),
                  errorText: field.errorText,
                );

            return SmartTextField(
              controller: controller,
              focusNode: focusNode,
              nextFocusNode: nextFocusNode,
              isLastField: isLastField,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              readOnly: readOnly,
              onTap: onTap,
              onChanged: (value) {
                field.didChange(value);
                onChanged?.call(value);
              },
              onSubmitted: onSubmitted,
              maxLines: maxLines,
              minLines: minLines,
              enabled: enabled,
              autofocus: autofocus,
              decoration: effectiveDecoration,
              style: style,
              obscureText: obscureText,
              textCapitalization: textCapitalization,
              textAlign: textAlign,
              maxLength: maxLength,
              onEditingComplete: onEditingComplete,
              onTapOutside: onTapOutside,
              autocorrect: autocorrect,
              enableSuggestions: enableSuggestions,
            );
          },
        );
}
