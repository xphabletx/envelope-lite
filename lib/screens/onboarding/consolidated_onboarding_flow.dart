// lib/screens/onboarding/consolidated_onboarding_flow.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/theme_provider.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/user_service.dart';
import '../../services/account_repo.dart';
import '../../services/envelope_repo.dart';
import '../../services/scheduled_payment_repo.dart';
import '../../services/pay_day_settings_service.dart';
import '../../services/onboarding_progress_service.dart';
import '../../models/pay_day_settings.dart';
import '../../models/account.dart';
import '../../models/onboarding_progress.dart';
import '../home_screen.dart';
import '../../data/binder_templates.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import '../../widgets/binder/binder_template_quick_setup.dart';
import '../../widgets/envelope/omni_icon_picker_modal.dart';
import '../../widgets/common/smart_text_field.dart';
import '../../widgets/group_editor.dart';
import '../../services/group_repo.dart';

class ConsolidatedOnboardingFlow extends StatefulWidget {
  final String userId;

  const ConsolidatedOnboardingFlow({super.key, required this.userId});

  @override
  State<ConsolidatedOnboardingFlow> createState() =>
      _ConsolidatedOnboardingFlowState();
}

class _ConsolidatedOnboardingFlowState extends State<ConsolidatedOnboardingFlow>
    with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();
  late final OnboardingProgressService _progressService;

  @override
  bool get wantKeepAlive => true;

  // User data collection
  String? _userName;
  String? _photoUrl;
  String _selectedCurrency = 'GBP';
  String? _selectedTheme; // Track theme selection for save/restore
  String? _selectedFont; // Track font selection for save/restore
  bool _isAccountMode = false;
  BinderTemplate? _selectedTemplate;
  int _createdEnvelopeCount = 0;

  // Account data (not saved until completion)
  String? _accountName;
  String? _bankName;
  double? _accountBalance;
  String? _accountIconType;
  String? _accountIconValue;

  // Pay day data (not saved until completion)
  double? _payAmount;
  String? _payFrequency;
  DateTime? _nextPayDate;

  int _currentPageIndex = 0;
  List<Widget> _pages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _progressService = OnboardingProgressService(
      FirebaseFirestore.instance,
      widget.userId,
    );
    _loadSavedProgress();
  }

  /// Load any saved onboarding progress
  Future<void> _loadSavedProgress() async {
    final progress = await _progressService.loadProgress();

    if (progress != null && mounted) {
      setState(() {
        _currentPageIndex = progress.currentStep;
        _userName = progress.userName;
        _photoUrl = progress.photoUrl;
        _selectedCurrency = progress.selectedCurrency ?? 'GBP';
        _selectedTheme = progress.selectedTheme;
        _selectedFont = progress.selectedFont;
        _isAccountMode = progress.isAccountMode ?? false;
        _accountName = progress.accountName;
        _bankName = progress.bankName;
        _accountBalance = progress.accountBalance;
        _accountIconType = progress.accountIconType;
        _accountIconValue = progress.accountIconValue;
        _payAmount = progress.payAmount;
        _payFrequency = progress.payFrequency;
        _nextPayDate = progress.nextPayDate;

        // Restore selected template if it exists
        if (progress.selectedTemplateId != null) {
          _selectedTemplate = binderTemplates.firstWhere(
            (t) => t.id == progress.selectedTemplateId,
            orElse: () => binderTemplates.first,
          );
        }
      });

      // Restore theme and font to providers if they were saved
      if (progress.selectedTheme != null) {
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        themeProvider.setTheme(progress.selectedTheme!);
      }
      if (progress.selectedFont != null) {
        final fontProvider = Provider.of<FontProvider>(context, listen: false);
        fontProvider.setFont(progress.selectedFont!);
      }
    }

    _buildPages();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    // Jump to saved page if exists
    if (progress != null && _currentPageIndex > 0) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _pageController.jumpToPage(_currentPageIndex);
        }
      });
    }
  }

  /// Save current progress to Firestore
  Future<void> _saveProgress() async {
    final progress = OnboardingProgress(
      userId: widget.userId,
      currentStep: _currentPageIndex,
      lastUpdated: DateTime.now(),
      userName: _userName,
      photoUrl: _photoUrl,
      selectedCurrency: _selectedCurrency,
      selectedTheme: _selectedTheme,
      selectedFont: _selectedFont,
      isAccountMode: _isAccountMode,
      accountName: _accountName,
      bankName: _bankName,
      accountBalance: _accountBalance,
      accountIconType: _accountIconType,
      accountIconValue: _accountIconValue,
      payAmount: _payAmount,
      payFrequency: _payFrequency,
      nextPayDate: _nextPayDate,
      selectedTemplateId: _selectedTemplate?.id,
    );

    await _progressService.saveProgress(progress);
  }

  /// CRITICAL FIX: Save pay day settings immediately (called after pay day setup step)
  /// This ensures they're available for widgets like Insight in subsequent onboarding steps
  /// (e.g., when using template quick setup or group editor)
  Future<void> _savePayDaySettingsNow() async {
    if (!_isAccountMode) return;

    if (_payAmount != null && _payFrequency != null && _nextPayDate != null) {
      try {
        final settings = PayDaySettings(
          userId: widget.userId,
          payFrequency: _payFrequency!,
          nextPayDate: _nextPayDate!,
          expectedPayAmount: _payAmount!,
          defaultAccountId: null, // Will be set when account is created
        );

        final payDayService = PayDaySettingsService(
          FirebaseFirestore.instance,
          widget.userId,
        );
        await payDayService.updatePayDaySettings(settings);
        debugPrint('[Onboarding] ✅ Pay day settings saved during onboarding');
      } catch (e) {
        debugPrint('[Onboarding] ⚠️ Error saving pay day settings during onboarding: $e');
      }
    }
  }

  void _buildPages() {
    _pages = [
      // Step 1: Name
      _NameSetupStep(
        initialName: _userName,
        onContinue: (name) {
          setState(() => _userName = name);
          _nextStep();
        },
      ),

      // Step 2: Photo
      _PhotoSetupStep(
        userId: widget.userId,
        initialPhoto: _photoUrl,
        onContinue: (photoUrl) {
          setState(() => _photoUrl = photoUrl);
          _nextStep();
        },
        onSkip: _nextStep,
      ),

      // Step 3: Theme
      _ThemeSelectionStep(
        initialTheme: _selectedTheme,
        onContinue: (themeId) {
          setState(() => _selectedTheme = themeId);
          _nextStep();
        },
      ),

      // Step 4: Font
      _FontSelectionStep(
        initialFont: _selectedFont,
        onContinue: (fontId) {
          setState(() => _selectedFont = fontId);
          _nextStep();
        },
      ),

      // Step 5: Currency
      _CurrencySelectionStep(
        onContinue: (currencyCode) {
          setState(() => _selectedCurrency = currencyCode);
          _nextStep();
        },
      ),

      // Step 6: Mode Selection
      _ModeSelectionStep(
        onContinue: (isAccountMode) {
          setState(() {
            _isAccountMode = isAccountMode;
            // Rebuild pages to include/exclude account setup steps
            _buildPages();
          });
          _nextStep();
        },
      ),

      // Step 7a & 7b: Account & Pay Day Setup (conditionally shown)
      if (_isAccountMode) ...[
        _AccountSetupStep(
          initialAccountName: _accountName,
          initialBankName: _bankName,
          initialBalance: _accountBalance,
          initialIconType: _accountIconType,
          initialIconValue: _accountIconValue,
          onContinue: (accountName, bankName, balance, iconType, iconValue) {
            setState(() {
              _accountName = accountName;
              _bankName = bankName;
              _accountBalance = balance;
              _accountIconType = iconType;
              _accountIconValue = iconValue;
            });
            _nextStep();
          },
        ),
        _PayDaySetupStep(
          initialPayAmount: _payAmount,
          initialFrequency: _payFrequency,
          initialNextPayDate: _nextPayDate,
          onContinue: (payAmount, frequency, nextPayDate) async {
            setState(() {
              _payAmount = payAmount;
              _payFrequency = frequency;
              _nextPayDate = nextPayDate;
            });

            // CRITICAL FIX: Save pay day settings immediately so they're available
            // for Insight in subsequent onboarding steps (template quick setup, etc.)
            await _savePayDaySettingsNow();

            _nextStep();
          },
        ),
      ],

      // Step 8: Envelope Mindset
      _EnvelopeMindsetStep(
        selectedCurrency: _selectedCurrency,
        onContinue: _nextStep,
      ),

      // Step 9: Binder Template
      _BinderTemplateSelectionStep(
        userId: widget.userId,
        onContinue: (template) {
          setState(() {
            _selectedTemplate = template;
            _buildPages(); // Rebuild pages to include Quick Setup
          });
          _nextStep();
        },
        onSkip: () {
          setState(() => _selectedTemplate = null);
          // Skip template AND quick setup, go to target icon
          _nextStep();
        },
      ),

      // Step 10 & 11: Quick Setup (if template selected)
      if (_selectedTemplate != null)
        BinderTemplateQuickSetup(
          template: _selectedTemplate!,
          userId: widget.userId,
          defaultAccountId: null, // Account not created until completion
          onComplete: (envelopeCount) {
            setState(() => _createdEnvelopeCount = envelopeCount);
            _nextStep();
          },
        ),

      // Step 12: Completion
      _CompletionStep(
        isAccountMode: _isAccountMode,
        userName: _userName ?? 'there',
        envelopeCount: _createdEnvelopeCount,
        onComplete: _completeOnboarding,
      ),
    ];
  }

  void _nextStep() {
    if (_currentPageIndex < _pages.length - 1) {
      setState(() => _currentPageIndex++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      // Save progress after moving to next step
      _saveProgress();
    }
  }

  void _previousStep() {
    if (_currentPageIndex > 0) {
      // Dismiss keyboard before navigating back to prevent overflow
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _currentPageIndex--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Mark onboarding as complete in SharedPreferences (local-first, works offline)
      await prefs.setBool('hasCompletedOnboarding_${widget.userId}', true);

      // 2. Save displayName to FirebaseAuth user object (local-first, works offline)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && _userName != null) {
        await currentUser.updateDisplayName(_userName!.trim());
      }

      // 3. Save photoURL to SharedPreferences (local-first, works offline)
      if (_photoUrl != null) {
        await prefs.setString('profile_photo_path_${widget.userId}', _photoUrl!);
      }

      // 4. Save showTutorial flag to SharedPreferences (local-first)
      await prefs.setBool('showTutorial_${widget.userId}', true);

      // 5. Best-effort sync to Firestore (optional, fails silently offline)
      try {
        final userService = UserService(
          FirebaseFirestore.instance,
          widget.userId,
        );
        await userService.createUserProfile(
          displayName: _userName ?? 'User',
          photoURL: _photoUrl,
          hasCompletedOnboarding: true,
        );
      } catch (e) {
        debugPrint('[Onboarding] ⚠️ Firestore user profile sync failed (offline?): $e');
      }

      // If in account mode, create the account and update pay day settings with account ID
      if (_isAccountMode) {
        final envelopeRepo = EnvelopeRepo.firebase(
          FirebaseFirestore.instance,
          userId: widget.userId,
        );
        final accountRepo = AccountRepo(envelopeRepo);

        // Create account
        final accountId = await accountRepo.createAccount(
          name: _accountName ?? 'Main Account',
          startingBalance: _accountBalance ?? 0.0,
          emoji: _accountIconValue ?? '🏦',
          isDefault: true,
          iconType: _accountIconType ?? 'emoji',
          iconValue: _accountIconValue ?? '🏦',
          accountType: AccountType.bankAccount,
        );

        // Update pay day settings with the newly created account ID
        // (Pay day settings were already saved earlier in _savePayDaySettingsNow,
        // but without the account ID since the account didn't exist yet)
        if (_payAmount != null &&
            _payFrequency != null &&
            _nextPayDate != null) {
          final payDayService = PayDaySettingsService(
            FirebaseFirestore.instance,
            widget.userId,
          );

          // Get existing settings and update with account ID
          final existingSettings = await payDayService.getPayDaySettings();
          if (existingSettings != null) {
            final updatedSettings = existingSettings.copyWith(
              defaultAccountId: accountId,
            );
            await payDayService.updatePayDaySettings(updatedSettings);
          } else {
            // Fallback: Create new settings if they don't exist for some reason
            final settings = PayDaySettings(
              userId: widget.userId,
              payFrequency: _payFrequency!,
              nextPayDate: _nextPayDate!,
              expectedPayAmount: _payAmount!,
              defaultAccountId: accountId,
            );
            await payDayService.updatePayDaySettings(settings);
          }
        }
      }

      // Clear onboarding progress after successful completion
      await _progressService.clearProgress();

      // Navigate to home screen
      if (mounted) {
        final repo = EnvelopeRepo.firebase(
          FirebaseFirestore.instance,
          userId: widget.userId,
        );
        final scheduledPaymentRepo = ScheduledPaymentRepo(widget.userId);

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeScreen(
            repo: repo,
            scheduledPaymentRepo: scheduledPaymentRepo,
          )),
        );
      }
    } catch (e) {
      debugPrint('[Onboarding] Error completing onboarding: $e');
      // Don't clear progress if there was an error - allow retry
      rethrow;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    // Show loading indicator while pages are being built
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentPageIndex > 0) {
          _previousStep();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // Disable swipe
              children: _pages,
            ),
            // Back button overlay (show on all steps except first)
            if (_currentPageIndex > 0)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _previousStep,
                    tooltip: 'Go back',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// INDIVIDUAL STEP WIDGETS
// ============================================================================

class _NameSetupStep extends StatefulWidget {
  final String? initialName;
  final Function(String) onContinue;

  const _NameSetupStep({this.initialName, required this.onContinue});

  @override
  State<_NameSetupStep> createState() => _NameSetupStepState();
}

class _NameSetupStepState extends State<_NameSetupStep> {
  late final TextEditingController _controller;
  late final FocusNode _controllerFocus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _controllerFocus = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _controllerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'What should we call you?',
                style: fontProvider.getTextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              TextField(
                controller: _controller,
                autofocus: false,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.words,
                autocorrect: false,
                onTap: () => _controller.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _controller.text.length,
                ),
                style: const TextStyle(fontSize: 24),
                decoration: InputDecoration(
                  hintText: 'Your name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'We\'ll use this to personalize your experience',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              FilledButton(
                onPressed: () {
                  if (_controller.text.trim().isNotEmpty) {
                    // Dismiss keyboard before continuing
                    FocusManager.instance.primaryFocus?.unfocus();
                    HapticFeedback.mediumImpact();
                    widget.onContinue(_controller.text.trim());
                  }
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Continue',
                  style: fontProvider.getTextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// _PhotoSetupStep
class _PhotoSetupStep extends StatefulWidget {
  final String userId;
  final String? initialPhoto;
  final Function(String?) onContinue;
  final VoidCallback onSkip;

  const _PhotoSetupStep({
    required this.userId,
    this.initialPhoto,
    required this.onContinue,
    required this.onSkip,
  });

  @override
  State<_PhotoSetupStep> createState() => _PhotoSetupStepState();
}

class _PhotoSetupStepState extends State<_PhotoSetupStep> {
  String? _photoPath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _photoPath = widget.initialPhoto;
  }

  Future<void> _pickPhoto() async {
    setState(() => _isLoading = true);

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get theme colors before async gap
      final primaryColor = Theme.of(context).colorScheme.primary;
      final onPrimaryColor = Theme.of(context).colorScheme.onPrimary;

      // Crop the image to a circle
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Photo',
            toolbarColor: primaryColor,
            toolbarWidgetColor: onPrimaryColor,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            cropStyle: CropStyle.circle,
            aspectRatioPresets: [CropAspectRatioPreset.square],
            // Fix status bar - use light/dark mode instead of color
            statusBarLight: onPrimaryColor.computeLuminance() > 0.5,
            activeControlsWidgetColor: primaryColor,
            // Move controls to bottom to avoid status bar overlap
            hideBottomControls: false,
            // Proper padding and layout
            cropFrameColor: primaryColor,
            cropGridColor: primaryColor.withValues(alpha: 0.3),
            dimmedLayerColor: Colors.black.withValues(alpha: 0.6),
            // Show crop frame to make it clearer
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: 'Crop Profile Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            cropStyle: CropStyle.circle,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      );

      if (croppedFile != null) {
        // Save to app documents directory
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'profile_${widget.userId}.jpg';
        final savedImage = await File(
          croppedFile.path,
        ).copy('${appDir.path}/$fileName');

        if (mounted) {
          setState(() {
            _photoPath = savedImage.path;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Add a profile photo?',
                style: fontProvider.getTextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Avatar
              GestureDetector(
                onTap: _isLoading ? null : _pickPhoto,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primaryContainer,
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 3,
                    ),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _photoPath != null
                      ? ClipOval(
                          child: Image.file(
                            File(_photoPath!),
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: 80,
                          color: theme.colorScheme.primary,
                        ),
                ),
              ),

              const SizedBox(height: 32),

              OutlinedButton(
                onPressed: _isLoading ? null : _pickPhoto,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Choose Photo',
                  style: fontProvider.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'You can always add one later',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        widget.onSkip();
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Skip',
                        style: fontProvider.getTextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        widget.onContinue(_photoPath);
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Continue',
                        style: fontProvider.getTextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// _ThemeSelectionStep
class _ThemeSelectionStep extends StatelessWidget {
  final String? initialTheme;
  final Function(String) onContinue;

  const _ThemeSelectionStep({
    this.initialTheme,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: 40,
                  ), // Add padding to avoid back button overlap
                  child: Text(
                    'Choose your vibe',
                    style: fontProvider.getTextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 32),

                _ThemeCard(
                themeId: 'latte_love',
                name: 'Latte Love',
                description: 'Warm creams & browns',
                emoji: '☕',
                isSelected: themeProvider.currentThemeId == 'latte_love',
                onTap: () => themeProvider.setTheme('latte_love'),
              ),
              const SizedBox(height: 8),
              _ThemeCard(
                themeId: 'mint_fresh',
                name: 'Mint Fresh',
                description: 'Soft mint & sage',
                emoji: '🌿',
                isSelected: themeProvider.currentThemeId == 'mint_fresh',
                onTap: () => themeProvider.setTheme('mint_fresh'),
              ),
              const SizedBox(height: 8),
              _ThemeCard(
                themeId: 'blush_gold',
                name: 'Blush & Gold',
                description: 'Rose gold elegance',
                emoji: '🌸',
                isSelected: themeProvider.currentThemeId == 'blush_gold',
                onTap: () => themeProvider.setTheme('blush_gold'),
              ),
              const SizedBox(height: 8),
              _ThemeCard(
                themeId: 'lavender_dreams',
                name: 'Lavender Dreams',
                description: 'Soft purples & lilacs',
                emoji: '💜',
                isSelected: themeProvider.currentThemeId == 'lavender_dreams',
                onTap: () => themeProvider.setTheme('lavender_dreams'),
              ),
              const SizedBox(height: 8),
              _ThemeCard(
                themeId: 'monochrome',
                name: 'Monochrome',
                description: 'Classic black & white',
                emoji: '⚫',
                isSelected: themeProvider.currentThemeId == 'monochrome',
                onTap: () => themeProvider.setTheme('monochrome'),
              ),
              const SizedBox(height: 8),
              _ThemeCard(
                themeId: 'singularity',
                name: 'Singularity',
                description: 'Deep space blues',
                emoji: '🌌',
                isSelected: themeProvider.currentThemeId == 'singularity',
                onTap: () => themeProvider.setTheme('singularity'),
              ),

                const SizedBox(height: 32),

                FilledButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    onContinue(themeProvider.currentThemeId);
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: fontProvider.getTextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final String themeId;
  final String name;
  final String description;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.themeId,
    required this.name,
    required this.description,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: fontProvider.getTextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(description, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}

// _FontSelectionStep
class _FontSelectionStep extends StatelessWidget {
  final String? initialFont;
  final Function(String) onContinue;

  const _FontSelectionStep({
    this.initialFont,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    final fonts = [
      {'id': 'caveat', 'name': 'Caveat', 'desc': 'Handwritten & Friendly'},
      {
        'id': 'indie_flower',
        'name': 'Indie Flower',
        'desc': 'Casual & Playful',
      },
      {'id': 'roboto', 'name': 'Roboto', 'desc': 'Clean & Modern'},
      {'id': 'open_sans', 'name': 'Open Sans', 'desc': 'Friendly & Readable'},
      {
        'id': 'system_default',
        'name': 'System Default',
        'desc': 'Your device font',
      },
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: 40,
                  ), // Add padding to avoid back button overlap
                  child: Text(
                    'Choose your font style',
                    style: fontProvider.getTextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 32),

                ...fonts.map((font) {
                final fontId = font['id']!;
                final isSelected = fontProvider.currentFontId == fontId;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => fontProvider.setFont(fontId),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                font['name']!,
                                style: fontProvider.getTextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: theme.colorScheme.primary,
                                  size: 24,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            font['desc']!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

                const SizedBox(height: 32),

                FilledButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    onContinue(fontProvider.currentFontId);
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: fontProvider.getTextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// _CurrencySelectionStep
class _CurrencySelectionStep extends StatelessWidget {
  final Function(String) onContinue;

  const _CurrencySelectionStep({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: 40,
                ), // Add padding to avoid back button overlap
                child: Text(
                  'What currency do you use?',
                  style: fontProvider.getTextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 32),

              Expanded(
                child: ListView.separated(
                  itemCount: LocaleProvider.supportedCurrencies.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final currency = LocaleProvider.supportedCurrencies[index];
                    final code = currency['code']!;
                    final name = currency['name']!;
                    final symbol = currency['symbol']!;
                    final isSelected = localeProvider.currencyCode == code;

                    return InkWell(
                      onTap: () => localeProvider.setCurrency(code),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline.withValues(
                                    alpha: 0.3,
                                  ),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  symbol,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    code,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.primary,
                                size: 24,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              FilledButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onContinue(localeProvider.currencyCode);
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Continue',
                  style: fontProvider.getTextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// _ModeSelectionStep
class _ModeSelectionStep extends StatefulWidget {
  final Function(bool) onContinue;

  const _ModeSelectionStep({required this.onContinue});

  @override
  State<_ModeSelectionStep> createState() => _ModeSelectionStepState();
}

class _ModeSelectionStepState extends State<_ModeSelectionStep> {
  bool? _isAccountMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: 40,
                  ), // Add padding to avoid back button overlap
                  child: Text(
                    'How do you want to budget?',
                    style: fontProvider.getTextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 32),

                // Budget Mode
                _ModeCard(
                title: 'Simple Envelope Tracking',
                description: 'Quick & flexible budgeting',
                features: [
                  'Allocate money when you want',
                  'Track your envelopes',
                  'Quick & flexible',
                ],
                emoji: '📊',
                isSelected: _isAccountMode == false,
                isRecommended: false,
                onTap: () => setState(() => _isAccountMode = false),
              ),

              const SizedBox(height: 12),

              // Account Mode
              _ModeCard(
                title: 'Complete Financial Picture',
                description: 'Full automation & forecasting',
                features: [
                  'Add your account balance',
                  'Automate your pay day',
                  'See EXACT future balances',
                  'Never overdraft again',
                ],
                emoji: '🎯',
                isSelected: _isAccountMode == true,
                isRecommended: true,
                onTap: () => setState(() => _isAccountMode = true),
                ),

                const SizedBox(height: 32),

                // Privacy notice
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'We NEVER connect to your bank. All manual.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                FilledButton(
                  onPressed: _isAccountMode != null
                      ? () {
                          HapticFeedback.mediumImpact();
                          widget.onContinue(_isAccountMode!);
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: fontProvider.getTextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String description;
  final List<String> features;
  final String emoji;
  final bool isSelected;
  final bool isRecommended;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.description,
    required this.features,
    required this.emoji,
    required this.isSelected,
    required this.isRecommended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: fontProvider.getTextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
              ],
            ),

            if (isRecommended) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      'RECOMMENDED',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// _AccountSetupStep
class _AccountSetupStep extends StatefulWidget {
  final String? initialAccountName;
  final String? initialBankName;
  final double? initialBalance;
  final String? initialIconType;
  final String? initialIconValue;
  final Function(
    String accountName,
    String bankName,
    double balance,
    String iconType,
    String iconValue,
  )
  onContinue;

  const _AccountSetupStep({
    this.initialAccountName,
    this.initialBankName,
    this.initialBalance,
    this.initialIconType,
    this.initialIconValue,
    required this.onContinue,
  });

  @override
  State<_AccountSetupStep> createState() => _AccountSetupStepState();
}

class _AccountSetupStepState extends State<_AccountSetupStep> {
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late final TextEditingController _bankNameController;
  late final FocusNode _bankNameFocus;
  late final FocusNode _nameFocus;
  late final FocusNode _balanceFocus;
  late String _iconType;
  late String _iconValue;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialAccountName ?? 'Main Account',
    );
    _balanceController = TextEditingController(
      text: widget.initialBalance != null
          ? widget.initialBalance.toString()
          : '',
    );
    _bankNameController = TextEditingController(
      text: widget.initialBankName ?? '',
    );
    _iconType = widget.initialIconType ?? 'emoji';
    _iconValue = widget.initialIconValue ?? '🏦';
    _bankNameFocus = FocusNode();
    _nameFocus = FocusNode();
    _balanceFocus = FocusNode();

    // Select all text when account name is focused
    _nameFocus.addListener(() {
      if (_nameFocus.hasFocus) {
        _nameController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _nameController.text.length,
        );
      }
    });

    // Select all text when balance is focused
    _balanceFocus.addListener(() {
      if (_balanceFocus.hasFocus) {
        _balanceController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _balanceController.text.length,
        );
      }
    });

    // Select all text when bank name is focused
    _bankNameFocus.addListener(() {
      if (_bankNameFocus.hasFocus) {
        _bankNameController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _bankNameController.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _bankNameController.dispose();
    _bankNameFocus.dispose();
    _nameFocus.dispose();
    _balanceFocus.dispose();
    super.dispose();
  }

  Future<void> _openIconPicker() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          OmniIconPickerModal(initialQuery: _bankNameController.text.trim()),
    );

    if (result != null) {
      setState(() {
        _iconType = result['type'] as String;
        _iconValue = result['value'] as String;
      });
    }
  }

  Widget _buildIconPreview() {
    final theme = Theme.of(context);
    final account = Account(
      id: '',
      name: '',
      userId: '',
      currentBalance: 0,
      createdAt: DateTime.now(),
      lastUpdated: DateTime.now(),
      iconType: _iconType,
      iconValue: _iconValue,
      iconColor: null,
      emoji: null,
    );

    return account.getIconWidget(theme, size: 32);
  }

  void _continueToNext() {
    // Dismiss keyboard before continuing
    FocusManager.instance.primaryFocus?.unfocus();
    final balance = double.tryParse(_balanceController.text) ?? 0.0;
    widget.onContinue(
      _nameController.text.trim(),
      _bankNameController.text.trim(),
      balance,
      _iconType,
      _iconValue,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: 40,
                ), // Add padding to avoid back button overlap
                child: Text(
                  'Add your main account',
                  style: fontProvider.getTextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Where your pay/salary is deposited',
                style: fontProvider.getTextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              Expanded(
                child: ListView(
                  children: [
                    Text(
                      'Bank Name',
                      style: fontProvider.getTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SmartTextField(
                      controller: _bankNameController,
                      focusNode: _bankNameFocus,
                      nextFocusNode: _nameFocus,
                      textCapitalization: TextCapitalization.words,
                      autocorrect: false,
                      onTap: () =>
                          _bankNameController.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: _bankNameController.text.length,
                          ),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: 'e.g., Chase, Barclays, HSBC',
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Icon',
                      style: fontProvider.getTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _openIconPicker,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.colorScheme.outline),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _buildIconPreview(),
                            const SizedBox(width: 12),
                            Text(
                              'Tap to select icon',
                              style: fontProvider.getTextStyle(
                                fontSize: 16,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Account Name',
                      style: fontProvider.getTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SmartTextField(
                      controller: _nameController,
                      focusNode: _nameFocus,
                      nextFocusNode: _balanceFocus,
                      textCapitalization: TextCapitalization.words,
                      autocorrect: false,
                      onTap: () => _nameController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _nameController.text.length,
                      ),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Current Balance',
                      style: fontProvider.getTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SmartTextField(
                      controller: _balanceController,
                      focusNode: _balanceFocus,
                      isLastField: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onTap: () => _balanceController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _balanceController.text.length,
                      ),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixText: '${localeProvider.currencySymbol} ',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              FilledButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _continueToNext();
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Continue',
                  style: fontProvider.getTextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// _PayDaySetupStep
class _PayDaySetupStep extends StatefulWidget {
  final double? initialPayAmount;
  final String? initialFrequency;
  final DateTime? initialNextPayDate;
  final Function(double payAmount, String frequency, DateTime nextPayDate)
  onContinue;

  const _PayDaySetupStep({
    this.initialPayAmount,
    this.initialFrequency,
    this.initialNextPayDate,
    required this.onContinue,
  });

  @override
  State<_PayDaySetupStep> createState() => _PayDaySetupStepState();
}

class _PayDaySetupStepState extends State<_PayDaySetupStep> {
  late final TextEditingController _amountController;
  late final FocusNode _amountFocus;
  late String _frequency;
  late DateTime _nextPayDate;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialPayAmount != null
          ? widget.initialPayAmount.toString()
          : '',
    );
    _amountFocus = FocusNode();
    _frequency = widget.initialFrequency ?? 'monthly';
    _nextPayDate =
        widget.initialNextPayDate ??
        DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _continueToNext() {
    // Dismiss keyboard before continuing
    FocusManager.instance.primaryFocus?.unfocus();
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    widget.onContinue(amount, _frequency, _nextPayDate);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: 40,
                ), // Add padding to avoid back button overlap
                child: Text(
                  'When do you get paid?',
                  style: fontProvider.getTextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 48),

              Expanded(
                child: ListView(
                  children: [
                    Text(
                      'Pay Amount',
                      style: fontProvider.getTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SmartTextField(
                      controller: _amountController,
                      focusNode: _amountFocus,
                      isLastField: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onTap: () => _amountController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _amountController.text.length,
                      ),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixText: '${localeProvider.currencySymbol} ',
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Frequency',
                      style: fontProvider.getTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _frequency,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Weekly'),
                        ),
                        DropdownMenuItem(
                          value: 'biweekly',
                          child: Text('Bi-weekly'),
                        ),
                        DropdownMenuItem(
                          value: 'fourweekly',
                          child: Text('Four-weekly'),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Monthly'),
                        ),
                      ],
                      onChanged: (value) => setState(() => _frequency = value!),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Next Pay Date',
                      style: fontProvider.getTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _nextPayDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 90),
                          ),
                        );
                        if (date != null) {
                          setState(() => _nextPayDate = date);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '${_nextPayDate.day}/${_nextPayDate.month}/${_nextPayDate.year}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              FilledButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _continueToNext();
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Continue',
                  style: fontProvider.getTextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// THE SOUL OF THE APP: ENVELOPE MINDSET STEP
// ============================================================================
class _EnvelopeMindsetStep extends StatefulWidget {
  final String selectedCurrency;
  final VoidCallback onContinue;

  const _EnvelopeMindsetStep({
    required this.selectedCurrency,
    required this.onContinue,
  });

  @override
  State<_EnvelopeMindsetStep> createState() => _EnvelopeMindsetStepState();
}

class _EnvelopeMindsetStepState extends State<_EnvelopeMindsetStep> {

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      children: [
                        // Add top padding to avoid back button overlap
                        const SizedBox(height: 40),

                        Text(
                          'Your Financial Machine',
                          style: fontProvider.getTextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 12),

                        Text(
                          'A complete automation system for your money',
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 32),

                        // Core Systems Header
                        Text(
                          'Core Systems',
                          style: fontProvider.getTextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 16),

                        // Four Core System Cards
                        _buildPillarCard(
                          theme: theme,
                          fontProvider: fontProvider,
                          icon: '👁️‍🗨️',
                          title: 'Insight',
                          subtitle: 'Intelligence System',
                          description: 'Calculates exactly how much to save per paycheck to reach your goals. Target in sight.',
                        ),

                        const SizedBox(height: 12),

                        _buildPillarCard(
                          theme: theme,
                          fontProvider: fontProvider,
                          icon: '⚡',
                          title: 'Cash Flow',
                          subtitle: 'The Engine',
                          description: 'Powers your savings velocity. Auto-deposits into envelopes every pay day.',
                        ),

                        const SizedBox(height: 12),

                        _buildPillarCard(
                          theme: theme,
                          fontProvider: fontProvider,
                          icon: '🛡️',
                          title: 'Autopilot',
                          subtitle: 'The Shield',
                          description: 'Protects your strategy by automating bills that cross "The Wall" to the outside world.',
                        ),

                        const SizedBox(height: 12),

                        _buildPillarCard(
                          theme: theme,
                          fontProvider: fontProvider,
                          icon: '🎯',
                          title: 'Horizon Navigator',
                          subtitle: 'Navigation System',
                          description: 'Track your targets and adjust course. See exactly when you\'ll reach each destination.',
                        ),

                        const SizedBox(height: 24),

                        // Dashboard Section
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                                theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('🔮', style: TextStyle(fontSize: 32)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Time Machine',
                                          style: fontProvider.getTextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        Text(
                                          'Your Command Center',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Once your systems are running, the Time Machine projects your financial future—showing every paycheck, every bill, every goal on a single timeline.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        const SizedBox(height: 20),

                        FilledButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            widget.onContinue();
                          },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Initialize System',
                                style: fontProvider.getTextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text('🚀', style: TextStyle(fontSize: 24)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPillarCard({
    required ThemeData theme,
    required FontProvider fontProvider,
    required String icon,
    required String title,
    required String subtitle,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: fontProvider.getTextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// _BinderTemplateSelectionStep
class _BinderTemplateSelectionStep extends StatelessWidget {
  final String userId;
  final Function(BinderTemplate?) onContinue;
  final VoidCallback onSkip;

  const _BinderTemplateSelectionStep({
    required this.userId,
    required this.onContinue,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 40,
                          ), // Add padding to avoid back button overlap
                          child: Text(
                            'Let\'s create your first binder!',
                            style: fontProvider.getTextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          'Choose a binder template to get started quickly, or start from scratch',
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 24),

                        ...binderTemplates.map(
                          (template) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _TemplateCard(
                              template: template,
                              onTap: () => onContinue(template),
                            ),
                          ),
                        ),

                        // Start from Scratch option
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _StartFromScratchCard(
                            userId: userId,
                            onBinderCreated: () {
                              // After creating a binder, skip to completion
                              onSkip();
                            },
                          ),
                        ),

                        const SizedBox(height: 32),

                        OutlinedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            onSkip();
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Skip - I\'ll create later',
                            style: fontProvider.getTextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final BinderTemplate template;
  final VoidCallback onTap;

  const _TemplateCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  template.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${template.name} Binder',
                    style: fontProvider.getTextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    template.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${template.envelopes.length} envelopes',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: theme.colorScheme.primary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _StartFromScratchCard extends StatefulWidget {
  final String userId;
  final VoidCallback onBinderCreated;

  const _StartFromScratchCard({
    required this.userId,
    required this.onBinderCreated,
  });

  @override
  State<_StartFromScratchCard> createState() => _StartFromScratchCardState();
}

class _StartFromScratchCardState extends State<_StartFromScratchCard> {
  Future<void> _openGroupEditor() async {
    final envelopeRepo = EnvelopeRepo.firebase(
      FirebaseFirestore.instance,
      userId: widget.userId,
    );
    final groupRepo = GroupRepo(envelopeRepo);

    final groupId = await showGroupEditor(
      context: context,
      groupRepo: groupRepo,
      envelopeRepo: envelopeRepo,
    );

    // If a binder was created, call the callback
    if (groupId != null && mounted) {
      widget.onBinderCreated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    return InkWell(
      onTap: _openGroupEditor,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.edit_note,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start from Scratch',
                    style: fontProvider.getTextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Build your own custom binder',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: theme.colorScheme.primary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// _CompletionStep
class _CompletionStep extends StatelessWidget {
  final bool isAccountMode;
  final String userName;
  final int envelopeCount;
  final VoidCallback onComplete;

  const _CompletionStep({
    required this.isAccountMode,
    required this.userName,
    required this.envelopeCount,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text('🚀', style: TextStyle(fontSize: 60)),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Text(
                          'Systems Ready, $userName!',
                          style: fontProvider.getTextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 32),

                        // System Ready Status Chips
                        _buildStatusChip(
                          theme: theme,
                          fontProvider: fontProvider,
                          icon: '✅',
                          label: 'Cash Flow Configured',
                        ),

                        const SizedBox(height: 12),

                        _buildStatusChip(
                          theme: theme,
                          fontProvider: fontProvider,
                          icon: '✅',
                          label: 'Autopilot Ready',
                        ),

                        const SizedBox(height: 12),

                        _buildStatusChip(
                          theme: theme,
                          fontProvider: fontProvider,
                          icon: '✅',
                          label: 'Time Machine Initialized',
                        ),

                        const SizedBox(height: 32),

                        // Pro-Tip
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('💡', style: TextStyle(fontSize: 24)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Pro-Tip: Your current strategy is now being projected. Head to any Horizon Visual to see the Time Machine in action and look into your financial future.',
                                  style: const TextStyle(fontSize: 14, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        const SizedBox(height: 20),

                        FilledButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            onComplete();
                          },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Enter the Cockpit →',
                            style: fontProvider.getTextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusChip({
    required ThemeData theme,
    required FontProvider fontProvider,
    required String icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: fontProvider.getTextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
