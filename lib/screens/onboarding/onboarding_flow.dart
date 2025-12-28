// lib/screens/onboarding/onboarding_flow.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/user_service.dart';
import '../../providers/theme_provider.dart';
import '../../providers/font_provider.dart';
import '../../theme/app_themes.dart';
import '../../providers/locale_provider.dart';
import '../../services/envelope_repo.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'onboarding_target_icon_step.dart';
import 'onboarding_account_setup.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.userService});

  final UserService userService;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _currentStep = 0;
  String? _photoPath; // Changed from _photoURL to _photoPath (local path)
  String _displayName = '';
  String _selectedTheme = AppThemes.latteId;
  String _selectedFont =
      FontProvider.systemDefaultId; // Start with system default
  String? _targetIconType = 'emoji';
  String? _targetIconValue = '🎯';
  final String _selectedLanguage = 'en'; // Default to English (no picker in onboarding)
  String _selectedCurrency = 'GBP'; // User will select this

  @override
  void initState() {
    super.initState();
    // Ensure a basic profile exists so Storage Rules pass
    _ensureProfileExists();
  }

  Future<void> _ensureProfileExists() async {
    final profile = await widget.userService.getUserProfile();
    if (profile == null) {
      await widget.userService.createUserProfile(
        displayName: 'New User',
        selectedTheme: AppThemes.latteId,
      );
      await widget.userService.updateUserProfile(
        hasCompletedOnboarding: false,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    debugPrint('[Onboarding] Completing onboarding...');

    // Save photo path locally
    if (_photoPath != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_photo_path', _photoPath!);
      debugPrint('[Onboarding] ✅ Photo path saved to SharedPreferences: $_photoPath');
    }

    // Create user profile in Firebase (displayName only, NO photoURL for solo users)
    await widget.userService.createUserProfile(
      displayName: _displayName.isEmpty ? 'User' : _displayName,
      photoURL: null, // Solo users don't upload photos to Firebase Storage
      selectedTheme: _selectedTheme,
    );
    debugPrint('[Onboarding] ✅ Profile saved to Firebase (displayName only)');

    // Save target icon to SharedPreferences (local-only, UI preference)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('target_icon_type', _targetIconType ?? 'emoji');
    await prefs.setString('target_icon_value', _targetIconValue ?? '🎯');
    debugPrint('[Onboarding] ✅ Target icon saved locally: $_targetIconType $_targetIconValue');

    if (!mounted) return;

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);

    // Update providers
    await themeProvider.setTheme(_selectedTheme);
    await fontProvider.setFont(_selectedFont);
    await localeProvider.setLanguage(_selectedLanguage);
    await localeProvider.setCurrency(_selectedCurrency);

    // Note: Account setup will handle navigation to /home
  }

  void _nextStep() {
    if (_currentStep < 6) {
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
        onPhotoSelected: (path) => _photoPath = path,
        onNext: _nextStep,
        userService: widget.userService,
      ),
      _DisplayNameStep(
        onNameChanged: (name) => _displayName = name,
        onNext: _nextStep,
        onBack: _previousStep,
        photoPath: _photoPath,
      ),
      _ThemePickerStep(
        selectedTheme: _selectedTheme,
        onThemeSelected: (themeId) => setState(() => _selectedTheme = themeId),
        onNext: _nextStep,
        onBack: _previousStep,
      ),
      _FontPickerStep(
        selectedFont: _selectedFont,
        onFontSelected: (fontId) => setState(() => _selectedFont = fontId),
        onNext: _nextStep,
        onBack: _previousStep,
      ),
      _CurrencyPickerStep(
        selectedCurrency: _selectedCurrency,
        onCurrencySelected: (curr) => setState(() => _selectedCurrency = curr),
        onComplete: _nextStep,
        onBack: _previousStep,
      ),
      OnboardingTargetIconStep(
        initialIconType: _targetIconType,
        initialIconValue: _targetIconValue,
        onIconSelected: (type, value) {
          _targetIconType = type;
          _targetIconValue = value;
        },
        onNext: _nextStep,
        onBack: _previousStep,
      ),
      OnboardingAccountSetup(
        envelopeRepo: EnvelopeRepo.firebase(
          FirebaseFirestore.instance,
          workspaceId: null,
          userId: widget.userService.userId,
        ),
        onBack: _previousStep,
        onComplete: _completeOnboarding,
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        // If on first step, confirm exit
        if (_currentStep == 0) {
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Exit Onboarding?'),
              content: const Text('Your progress will be lost. Are you sure you want to exit?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Exit'),
                ),
              ],
            ),
          );
          if (shouldExit == true && context.mounted) {
            Navigator.of(context).pop();
          }
        } else {
          // If not on first step, go back to previous step
          _previousStep();
        }
      },
      child: Scaffold(body: SafeArea(child: steps[_currentStep])),
    );
  }
}

// Step 1: Photo Upload
class _PhotoUploadStep extends StatefulWidget {
  const _PhotoUploadStep(
      {required this.onPhotoSelected,
      required this.onNext,
      required this.userService});

  final Function(String?) onPhotoSelected;
  final VoidCallback onNext;
  final UserService userService;

  @override
  State<_PhotoUploadStep> createState() => _PhotoUploadStepState();
}

class _PhotoUploadStepState extends State<_PhotoUploadStep> {
  File? _image;
  bool _saving = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      debugPrint('[Onboarding] Photo selected: ${pickedFile.path}');
    }
  }

  Future<String> _savePhotoLocally(String sourcePath) async {
    try {
      debugPrint('[Onboarding] Saving photo locally...');

      final userId = widget.userService.userId;
      final appDir = await getApplicationDocumentsDirectory();
      final localPath = '${appDir.path}/profile_photo_$userId.jpg';

      // Copy the selected photo to app directory
      final sourceFile = File(sourcePath);
      await sourceFile.copy(localPath);

      debugPrint('[Onboarding] ✅ Photo saved locally: $localPath');
      debugPrint('[Onboarding] ⏭️ Skipping Firebase Storage upload (solo mode)');
      return localPath;
    } catch (e) {
      debugPrint('[Onboarding] ❌ Error saving photo: $e');
      rethrow;
    }
  }

  Future<void> _saveAndContinue() async {
    if (_image == null) {
      debugPrint('[Onboarding] No photo selected, continuing...');
      widget.onPhotoSelected(null);
      widget.onNext();
      return;
    }

    setState(() => _saving = true);

    try {
      final localPhotoPath = await _savePhotoLocally(_image!.path);
      widget.onPhotoSelected(localPhotoPath);
      widget.onNext();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton.icon(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Log Out'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _image == null
                ? const Icon(Icons.account_circle, size: 120, color: Colors.grey)
                : CircleAvatar(
                    radius: 60,
                    backgroundImage: FileImage(_image!),
                  ),
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
              onPressed: _pickImage,
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
            _saving
                ? const CircularProgressIndicator()
                : TextButton(
                    onPressed: _saveAndContinue,
                    child: Text(_image == null ? 'Skip for now' : 'Continue'),
                  ),
          ],
        ),
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
    this.photoPath,
  });

  final Function(String) onNameChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final String? photoPath;

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a display name')),
        );
      }
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
          widget.photoPath == null
              ? const Icon(Icons.badge_outlined, size: 120, color: Colors.grey)
              : CircleAvatar(
                  radius: 60,
                  backgroundImage: FileImage(File(widget.photoPath!)),
                ),
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
            onTap: () {
              // Select all text when tapped
              _controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _controller.text.length,
              );
            },
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
    required this.onNext,
    required this.onBack,
  });

  final String selectedTheme;
  final Function(String) onThemeSelected;
  final VoidCallback onNext;
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
            'Your theme and font will be applied once you complete setup',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withAlpha(179),
            ),
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
                                color: theme.primaryColor.withAlpha(77),
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
                              color: theme.primaryColor.withAlpha(179),
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
                  onPressed: onNext,
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// Step 4: Font Picker
class _FontPickerStep extends StatelessWidget {
  const _FontPickerStep({
    required this.selectedFont,
    required this.onFontSelected,
    required this.onNext,
    required this.onBack,
  });

  final String selectedFont;
  final Function(String) onFontSelected;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final fonts = FontProvider.getAllFonts();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Text(
            'Choose Your Font',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'This will be used throughout the app',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              itemCount: fonts.length,
              itemBuilder: (context, index) {
                final font = fonts[index];
                final isSelected = selectedFont == font.id;

                // Get sample text style for this font
                TextStyle sampleStyle;
                switch (font.id) {
                  case FontProvider.caveatId:
                    sampleStyle = GoogleFonts.caveat(fontSize: 24);
                    break;
                  case FontProvider.indieFlowerId:
                    sampleStyle = GoogleFonts.indieFlower(fontSize: 24);
                    break;
                  case FontProvider.robotoId:
                    sampleStyle = GoogleFonts.roboto(fontSize: 24);
                    break;
                  case FontProvider.openSansId:
                    sampleStyle = GoogleFonts.openSans(fontSize: 24);
                    break;
                  case FontProvider.systemDefaultId:
                  default:
                    sampleStyle = const TextStyle(fontSize: 24);
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 32,
                          )
                        : const Icon(Icons.radio_button_unchecked, size: 32),
                    title: Text('The Quick Brown Fox', style: sampleStyle),
                    subtitle: Text(
                      '${font.name} - ${font.description}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    onTap: () => onFontSelected(font.id),
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
                  onPressed: onNext,
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// Step 6: Currency Picker (FIXED OVERFLOW PROACTIVELY)
class _CurrencyPickerStep extends StatelessWidget {
  const _CurrencyPickerStep({
    required this.selectedCurrency,
    required this.onCurrencySelected,
    required this.onComplete,
    required this.onBack,
  });

  final String selectedCurrency;
  final Function(String) onCurrencySelected;
  final VoidCallback onComplete;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Expanded wrapping SingleChildScrollView allows content to scroll and fill available space
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  const Icon(Icons.attach_money, size: 120, color: Colors.grey),
                  const SizedBox(height: 32),
                  Text(
                    'Select Your Currency',
                    style: fontProvider.getTextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This determines how amounts are displayed throughout the app',
                    style: fontProvider.getTextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withAlpha(179),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Currency dropdown
                  ...LocaleProvider.supportedCurrencies.map((currency) {
                    final code = currency['code']!;
                    final isSelected = selectedCurrency == code;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: isSelected ? 4 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline.withAlpha(51),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withAlpha(26),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              currency['symbol']!,
                              style: TextStyle(
                                fontSize: 24,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          currency['name']!,
                          style: fontProvider.getTextStyle(
                            fontSize: 18,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          code,
                          style: fontProvider.getTextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withAlpha(153),
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.primary,
                                size: 32,
                              )
                            : null,
                        onTap: () => onCurrencySelected(code),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Fixed Bottom Buttons
          const SizedBox(height: 16), // Padding between list and buttons
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
                  child: Text('Back', style: fontProvider.getTextStyle()),
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
                  child: Text(
                    'Continue',
                    style: fontProvider.getTextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
