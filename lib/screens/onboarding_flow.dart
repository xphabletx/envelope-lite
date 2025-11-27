// lib/screens/onboarding_flow.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../providers/theme_provider.dart';
import '../theme/app_themes.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.userService});

  final UserService userService;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _currentStep = 0;
  String? _photoURL;
  String _displayName = '';
  String _selectedTheme = AppThemes.latteId;

  Future<void> _completeOnboarding() async {
    // Create user profile in Firebase
    await widget.userService.createUserProfile(
      displayName: _displayName.isEmpty ? 'User' : _displayName,
      photoURL: _photoURL,
      selectedTheme: _selectedTheme,
    );

    // Update theme provider
    if (mounted) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      await themeProvider.setTheme(_selectedTheme);
    }

    // Mark onboarding complete
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _completeOnboarding();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      _PhotoUploadStep(
        onPhotoSelected: (url) => _photoURL = url,
        onNext: _nextStep,
      ),
      _DisplayNameStep(
        onNameChanged: (name) => _displayName = name,
        onNext: _nextStep,
        onBack: _previousStep,
      ),
      _ThemePickerStep(
        selectedTheme: _selectedTheme,
        onThemeSelected: (themeId) => setState(() => _selectedTheme = themeId),
        onComplete: _completeOnboarding,
        onBack: _previousStep,
      ),
    ];

    return Scaffold(body: SafeArea(child: steps[_currentStep]));
  }
}

// Step 1: Photo Upload
class _PhotoUploadStep extends StatelessWidget {
  const _PhotoUploadStep({required this.onPhotoSelected, required this.onNext});

  final Function(String?) onPhotoSelected;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_circle, size: 120, color: Colors.grey),
          const SizedBox(height: 32),
          Text(
            'Add a Profile Photo',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Help your workspace members recognize you',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement image picker
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Photo upload coming soon')),
              );
            },
            icon: const Icon(Icons.photo_camera),
            label: const Text('Choose Photo'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              onPhotoSelected(null);
              onNext();
            },
            child: const Text('Skip for now'),
          ),
        ],
      ),
    );
  }
}

// Step 2: Display Name
class _DisplayNameStep extends StatefulWidget {
  const _DisplayNameStep({
    required this.onNameChanged,
    required this.onNext,
    required this.onBack,
  });

  final Function(String) onNameChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<_DisplayNameStep> createState() => _DisplayNameStepState();
}

class _DisplayNameStepState extends State<_DisplayNameStep> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continue() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a display name')),
      );
      return;
    }
    widget.onNameChanged(name);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.badge_outlined, size: 120, color: Colors.grey),
          const SizedBox(height: 32),
          Text(
            'What should we call you?',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'This name will appear in your workspace',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Display Name',
              hintText: 'e.g., Sarah\'s Budget',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.person_outline),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            onSubmitted: (_) => _continue(),
          ),
          const SizedBox(height: 32),
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

// Step 3: Theme Picker
class _ThemePickerStep extends StatelessWidget {
  const _ThemePickerStep({
    required this.selectedTheme,
    required this.onThemeSelected,
    required this.onComplete,
    required this.onBack,
  });

  final String selectedTheme;
  final Function(String) onThemeSelected;
  final VoidCallback onComplete;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final themes = AppThemes.getAllThemes();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Text(
            'Pick Your Vibe',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'You can change this anytime in Settings',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: themes.length,
              itemBuilder: (context, index) {
                final theme = themes[index];
                final isSelected = selectedTheme == theme.id;

                return GestureDetector(
                  onTap: () => onThemeSelected(theme.id),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? theme.primaryColor
                            : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: theme.primaryColor.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 32,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            theme.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            theme.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.primaryColor.withValues(alpha: 0.7),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onBack,
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
                  onPressed: onComplete,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Get Started 🎉'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
