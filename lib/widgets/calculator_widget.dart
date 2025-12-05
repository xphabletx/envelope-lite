// lib/widgets/calculator_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class CalculatorWidget extends StatefulWidget {
  final Function(String)? onResultSelected;
  const CalculatorWidget({super.key, this.onResultSelected});

  @override
  State<CalculatorWidget> createState() => CalculatorWidgetState();
}

class CalculatorWidgetState extends State<CalculatorWidget> {
  String _display = '0';
  String _expression = '';
  bool _isMinimized = false;
  Offset _position = const Offset(20, 100);
  bool _justCalculated = false;

  @override
  void initState() {
    super.initState();
    // Suppress overflow errors during calculator animations (debug only)
    if (kDebugMode) {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        final exception = details.exception;
        final isOverflowError =
            exception is FlutterError &&
            exception.diagnostics.any(
              (node) =>
                  node.value.toString().contains('overflowed') ||
                  node.value.toString().contains('RenderFlex'),
            );

        final isCalculatorError =
            details.context?.toString().contains('calculator_widget') ?? false;

        if (isOverflowError && isCalculatorError) {
          return;
        }

        originalOnError?.call(details);
      };
    }
  }

  // Make these methods public so we can preserve state
  String get display => _display;
  String get expression => _expression;
  bool get isMinimized => _isMinimized;
  Offset get position => _position;

  void restoreState(
    String display,
    String expression,
    bool minimized,
    Offset pos,
  ) {
    setState(() {
      _display = display;
      _expression = expression;
      _isMinimized = minimized;
      _position = pos;
      _justCalculated = false;
    });
  }

  void _onButtonPressed(String value) {
    setState(() {
      // Handle Error state - any button press clears it
      if (_display == 'Error') {
        _display = '0';
        _expression = '';
        _justCalculated = false;
        // If it's not a number or decimal, process the button normally after clearing
        if (value == 'C' || value == '⌫') return;
      }

      // If we just calculated:
      // - Number/decimal: start fresh
      // - Operator: continue with result
      // - Equals/Clear/Backspace: process normally
      if (_justCalculated) {
        if (!['C', '⌫', '+', '-', '×', '÷', '='].contains(value)) {
          // Number or decimal pressed - start fresh
          _display = value == '.' ? '0.' : value;
          _expression = '';
          _justCalculated = false;
          return;
        } else if (['+', '-', '×', '÷'].contains(value)) {
          // Operator pressed - continue with result
          _expression = '$_display $value ';
          _display = '0';
          _justCalculated = false;
          return;
        }
      }

      if (value == 'C') {
        _display = '0';
        _expression = '';
        _justCalculated = false;
      } else if (value == '=') {
        try {
          final fullExpression = _expression + _display;
          final result = _evaluate(fullExpression);
          // Show the full expression on screen briefly
          _expression = '$fullExpression =';
          _display = _formatNumber(result);
          _justCalculated = true;

          // If there's a callback, call it with the result
          widget.onResultSelected?.call(_display);
        } catch (e) {
          _display = 'Error';
          _expression = '';
          _justCalculated = false;
        }
      } else if (['+', '-', '×', '÷'].contains(value)) {
        if (_display != '0' && _display != 'Error') {
          final operator = value == '×'
              ? ' × '
              : (value == '÷' ? ' ÷ ' : ' $value ');
          _expression += _display + operator;
          _display = '0';
          _justCalculated = false;
        }
      } else if (value == '⌫') {
        if (_justCalculated) {
          // If we just calculated, backspace clears everything
          _display = '0';
          _expression = '';
          _justCalculated = false;
        } else if (_display.length > 1) {
          _display = _display.substring(0, _display.length - 1);
        } else {
          _display = '0';
        }
      } else if (value == '.') {
        // Add decimal point if not already present
        if (!_display.contains('.')) {
          if (_display == '0') {
            _display = '0.';
          } else {
            _display += '.';
          }
        }
        _justCalculated = false;
      } else {
        // Number button
        if (_display == '0') {
          _display = value;
        } else {
          _display += value;
        }
        _justCalculated = false;
      }
    });
  }

  String _formatNumber(double value) {
    // If it's a whole number, show without decimals
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    // Otherwise show with up to 2 decimal places, removing trailing zeros
    String result = value.toStringAsFixed(2);
    // Remove trailing zeros after decimal
    result = result.replaceAll(RegExp(r'\.?0+$'), '');
    return result;
  }

  double _evaluate(String expression) {
    // Simple expression evaluator
    // Replace visual operators with calculation operators
    expression = expression.replaceAll(' × ', '*').replaceAll(' ÷ ', '/');
    expression = expression.replaceAll(' + ', '+').replaceAll(' - ', '-');
    expression = expression.replaceAll(' = ', ''); // Remove equals if present

    // Handle operators in order: *, /, +, -
    List<String> tokens = [];
    String currentNumber = '';

    for (int i = 0; i < expression.length; i++) {
      String char = expression[i];
      if (['+', '-', '*', '/'].contains(char)) {
        if (currentNumber.isNotEmpty) {
          tokens.add(currentNumber);
          currentNumber = '';
        }
        tokens.add(char);
      } else {
        currentNumber += char;
      }
    }
    if (currentNumber.isNotEmpty) {
      tokens.add(currentNumber);
    }

    // First pass: * and /
    for (int i = 1; i < tokens.length; i += 2) {
      if (tokens[i] == '*' || tokens[i] == '/') {
        double left = double.parse(tokens[i - 1]);
        double right = double.parse(tokens[i + 1]);
        double result = tokens[i] == '*' ? left * right : left / right;
        tokens[i - 1] = result.toString();
        tokens.removeAt(i);
        tokens.removeAt(i);
        i -= 2;
      }
    }

    // Second pass: + and -
    double result = double.parse(tokens[0]);
    for (int i = 1; i < tokens.length; i += 2) {
      double next = double.parse(tokens[i + 1]);
      if (tokens[i] == '+') {
        result += next;
      } else if (tokens[i] == '-') {
        result -= next;
      }
    }

    // Round to 2 decimal places
    return (result * 100).roundToDouble() / 100;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              (_position.dx + details.delta.dx).clamp(
                0.0,
                MediaQuery.of(context).size.width - (_isMinimized ? 80 : 280),
              ),
              (_position.dy + details.delta.dy).clamp(
                0.0,
                MediaQuery.of(context).size.height - (_isMinimized ? 80 : 420),
              ),
            );
          });
        },
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isMinimized ? 60 : 280,
            height: _isMinimized ? 60 : 420,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withAlpha(77),
                width: 1,
              ),
            ),
            // Show content based on state, with fade transition
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _isMinimized
                  ? _buildMinimized(theme)
                  : _buildExpanded(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimized(ThemeData theme) {
    return InkWell(
      onTap: () => setState(() => _isMinimized = false),
      borderRadius: BorderRadius.circular(16),
      child: Center(
        child: Icon(
          Icons.calculate,
          size: 30,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildExpanded(ThemeData theme) {
    return Column(
      children: [
        // Header with minimize and close - clips during animation
        ClipRect(
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Only show full header when width is sufficient
                if (constraints.maxWidth < 200) {
                  // During animation or if too small, just show centered text
                  return Center(
                    child: Text(
                      'Calc',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  );
                }

                // Full header when enough space
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.remove,
                        size: 18,
                        color: theme.colorScheme.onSurface,
                      ),
                      onPressed: () => setState(() => _isMinimized = true),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Calculator',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.clip,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: theme.colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // Display - FIXED HEIGHT
        Container(
          width: double.infinity,
          height: 104,
          padding: const EdgeInsets.all(16),
          color: theme.colorScheme.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Expression display - scrollable if long
              if (_expression.isNotEmpty)
                SizedBox(
                  height: 30,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Text(
                      _expression,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              // Result display
              SizedBox(
                height: 40,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Text(
                    _display,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Buttons - FIXED SIZE
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                _buildButtonRow(['7', '8', '9', '÷'], theme),
                _buildButtonRow(['4', '5', '6', '×'], theme),
                _buildButtonRow(['1', '2', '3', '-'], theme),
                _buildButtonRow(['⌫/C', '0', '.', '+'], theme),
                _buildButtonRow(['='], theme, span: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButtonRow(
    List<String> buttons,
    ThemeData theme, {
    int span = 1,
  }) {
    return Expanded(
      child: Row(
        children: buttons.map((btn) {
          final isOperator = ['+', '-', '×', '÷', '=', '.'].contains(btn);
          final isClearBackspace = btn == '⌫/C';

          return Expanded(
            flex: btn == '=' ? 4 : 1,
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: isClearBackspace
                  ? GestureDetector(
                      onTap: () => _onButtonPressed('⌫'),
                      onLongPress: () => _onButtonPressed('C'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.backspace_outlined,
                              size: 16,
                              color: theme.colorScheme.onSurface,
                            ),
                            Text(
                              '/C',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: () => _onButtonPressed(btn),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOperator
                            ? (btn == '='
                                  ? theme.colorScheme.secondary
                                  : theme.colorScheme.surface)
                            : theme.scaffoldBackgroundColor,
                        foregroundColor: btn == '='
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.zero,
                        elevation: 0,
                      ),
                      child: Text(
                        btn,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: btn == '='
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
