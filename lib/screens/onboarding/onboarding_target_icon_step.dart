// lib/screens/onboarding/onboarding_target_icon_step.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/font_provider.dart';
import '../../widgets/envelope/omni_icon_picker_modal.dart';
import '../../services/icon_search_service_unlimited.dart';

class OnboardingTargetIconStep extends StatefulWidget {
  const OnboardingTargetIconStep({
    super.key,
    required this.onIconSelected,
    required this.onNext,
    required this.onBack,
    this.initialIconType,
    this.initialIconValue,
  });

  final Function(String?, String?) onIconSelected;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final String? initialIconType;
  final String? initialIconValue;

  @override
  State<OnboardingTargetIconStep> createState() =>
      _OnboardingTargetIconStepState();
}

class _OnboardingTargetIconStepState extends State<OnboardingTargetIconStep> {
  String? _selectedIconType;
  String? _selectedIconValue;

  @override
  void initState() {
    super.initState();
    _selectedIconType = widget.initialIconType ?? 'emoji';
    _selectedIconValue = widget.initialIconValue ?? '🎯';
  }

  Future<void> _openIconPicker() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OmniIconPickerModal(
        initialValue: _selectedIconValue,
        initialType: _selectedIconType == 'emoji'
            ? IconType.emoji
            : _selectedIconType == 'companyLogo'
                ? IconType.companyLogo
                : IconType.materialIcon,
        initialQuery: '',
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedIconType = result['type'];
        _selectedIconValue = result['value'];
      });
    }
  }

  void _continue() {
    widget.onIconSelected(_selectedIconType, _selectedIconValue);
    widget.onNext();
  }

  Widget _buildIconPreview(BuildContext context) {
    final theme = Theme.of(context);

    if (_selectedIconValue == null) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.add_photo_alternate,
          size: 48,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      );
    }

    Widget iconWidget;
    switch (_selectedIconType) {
      case 'emoji':
        iconWidget = Text(
          _selectedIconValue!,
          style: const TextStyle(fontSize: 80),
        );
        break;
      case 'companyLogo':
        iconWidget = Text(
          _selectedIconValue!,
          style: const TextStyle(fontSize: 80),
        );
        break;
      case 'material':
      default:
        final codePoint = int.tryParse(_selectedIconValue!);
        iconWidget = Icon(
          codePoint != null
              ? IconData(codePoint, fontFamily: 'MaterialIcons')
              : Icons.help_outline,
          size: 80,
          color: theme.colorScheme.primary,
        );
    }

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.colorScheme.primary,
          width: 3,
        ),
      ),
      child: Center(child: iconWidget),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Choose Your 100% Icon',
            style: fontProvider.getTextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'This icon will appear when your envelopes reach their target amount',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          _buildIconPreview(context),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _openIconPicker,
            icon: const Icon(Icons.edit),
            label: const Text('Choose Different Icon'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onBack,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
