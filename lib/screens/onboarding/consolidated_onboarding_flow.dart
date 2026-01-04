// lib/screens/onboarding/consolidated_onboarding_flow.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/theme_provider.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/user_service.dart';
import '../../services/account_repo.dart';
import '../../services/envelope_repo.dart';
import '../../services/pay_day_settings_service.dart';
import '../../services/onboarding_progress_service.dart';
import '../../models/pay_day_settings.dart';
import '../../models/account.dart';
import '../../models/onboarding_progress.dart';
import '../home_screen.dart';
import '../../data/binder_templates.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/onboarding_currency_converter.dart';
import '../../widgets/binder/binder_template_quick_setup.dart';
import '../../widgets/envelope/omni_icon_picker_modal.dart';
import '../../widgets/common/smart_text_field.dart';

class ConsolidatedOnboardingFlow extends StatefulWidget {
  final String userId;

  const ConsolidatedOnboardingFlow({
    super.key,
    required this.userId,
  });

  @override
  State<ConsolidatedOnboardingFlow> createState() => _ConsolidatedOnboardingFlowState();
}

class _ConsolidatedOnboardingFlowState extends State<ConsolidatedOnboardingFlow> {
  final PageController _pageController = PageController();
  late final OnboardingProgressService _progressService;

  // User data collection
  String? _userName;
  String? _photoUrl;
  String _selectedCurrency = 'GBP';
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
    _progressService = OnboardingProgressService(FirebaseFirestore.instance, widget.userId);
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
        _isAccountMode = progress.isAccountMode ?? false;
        _accountName = progress.accountName;
        _bankName = progress.bankName;
        _accountBalance = progress.accountBalance;
        _accountIconType = progress.accountIconType;
        _accountIconValue = progress.accountIconValue;
        _payAmount = progress.payAmount;
        _payFrequency = progress.payFrequency;
        _nextPayDate = progress.nextPayDate;
      });
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
      _ThemeSelectionStep(onContinue: _nextStep),

      // Step 4: Font
      _FontSelectionStep(onContinue: _nextStep),

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
          onContinue: (payAmount, frequency, nextPayDate) {
            setState(() {
              _payAmount = payAmount;
              _payFrequency = frequency;
              _nextPayDate = nextPayDate;
            });
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
        onBack: _previousStep,
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

      // Step 12: Target Icon
      _TargetIconStep(
        onContinue: _nextStep,
      ),

      // Step 13: Completion
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
      setState(() => _currentPageIndex--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    try {
      // Save user profile and mark onboarding as complete
      final userService = UserService(FirebaseFirestore.instance, widget.userId);
      await userService.createUserProfile(
        displayName: _userName ?? 'User',
        photoURL: _photoUrl,
        hasCompletedOnboarding: true, // Mark onboarding as complete
      );

      // If in account mode, create the account and pay day settings
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

        // Save pay day settings
        if (_payAmount != null && _payFrequency != null && _nextPayDate != null) {
          final settings = PayDaySettings(
            userId: widget.userId,
            payFrequency: _payFrequency!,
            nextPayDate: _nextPayDate!,
            expectedPayAmount: _payAmount!,
            defaultAccountId: accountId,
          );

          final payDayService = PayDaySettingsService(FirebaseFirestore.instance, widget.userId);
          await payDayService.updatePayDaySettings(settings);
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

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeScreen(repo: repo),
          ),
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
    // Show loading indicator while pages are being built
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
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

  const _NameSetupStep({
    this.initialName,
    required this.onContinue,
  });

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
                autofocus: true,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.words,
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
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        // Save to app documents directory
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'profile_${widget.userId}.jpg';
        final savedImage = await File(image.path).copy(
          '${appDir.path}/$fileName',
        );

        setState(() {
          _photoPath = savedImage.path;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error picking photo: $e');
      setState(() => _isLoading = false);
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
  final VoidCallback onContinue;

  const _ThemeSelectionStep({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'Choose your vibe',
                style: fontProvider.getTextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              Expanded(
                child: ListView(
                  children: [
                    _ThemeCard(
                      themeId: 'latte_love',
                      name: 'Latte Love',
                      description: 'Warm creams & browns',
                      emoji: '☕',
                      isSelected: themeProvider.currentThemeId == 'latte_love',
                      onTap: () => themeProvider.setTheme('latte_love'),
                    ),
                    const SizedBox(height: 12),
                    _ThemeCard(
                      themeId: 'mint_fresh',
                      name: 'Mint Fresh',
                      description: 'Soft mint & sage',
                      emoji: '🌿',
                      isSelected: themeProvider.currentThemeId == 'mint_fresh',
                      onTap: () => themeProvider.setTheme('mint_fresh'),
                    ),
                    const SizedBox(height: 12),
                    _ThemeCard(
                      themeId: 'blush_gold',
                      name: 'Blush & Gold',
                      description: 'Rose gold elegance',
                      emoji: '🌸',
                      isSelected: themeProvider.currentThemeId == 'blush_gold',
                      onTap: () => themeProvider.setTheme('blush_gold'),
                    ),
                    const SizedBox(height: 12),
                    _ThemeCard(
                      themeId: 'lavender_dreams',
                      name: 'Lavender Dreams',
                      description: 'Soft purples & lilacs',
                      emoji: '💜',
                      isSelected: themeProvider.currentThemeId == 'lavender_dreams',
                      onTap: () => themeProvider.setTheme('lavender_dreams'),
                    ),
                    const SizedBox(height: 12),
                    _ThemeCard(
                      themeId: 'monochrome',
                      name: 'Monochrome',
                      description: 'Classic black & white',
                      emoji: '⚫',
                      isSelected: themeProvider.currentThemeId == 'monochrome',
                      onTap: () => themeProvider.setTheme('monochrome'),
                    ),
                    const SizedBox(height: 12),
                    _ThemeCard(
                      themeId: 'singularity',
                      name: 'Singularity',
                      description: 'Deep space blues',
                      emoji: '🌌',
                      isSelected: themeProvider.currentThemeId == 'singularity',
                      onTap: () => themeProvider.setTheme('singularity'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              FilledButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onContinue();
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
                  Text(
                    description,
                    style: const TextStyle(fontSize: 14),
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
      ),
    );
  }
}

// _FontSelectionStep
class _FontSelectionStep extends StatelessWidget {
  final VoidCallback onContinue;

  const _FontSelectionStep({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);

    final fonts = [
      {'id': 'caveat', 'name': 'Caveat', 'desc': 'Handwritten & Friendly'},
      {'id': 'indie_flower', 'name': 'Indie Flower', 'desc': 'Casual & Playful'},
      {'id': 'roboto', 'name': 'Roboto', 'desc': 'Clean & Modern'},
      {'id': 'open_sans', 'name': 'Open Sans', 'desc': 'Friendly & Readable'},
      {'id': 'system_default', 'name': 'System Default', 'desc': 'Your device font'},
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'Choose your font style',
                style: fontProvider.getTextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              Expanded(
                child: ListView.separated(
                  itemCount: fonts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final font = fonts[index];
                    final fontId = font['id']!;
                    final isSelected = fontProvider.currentFontId == fontId;

                    return InkWell(
                      onTap: () => fontProvider.setFont(fontId),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  font['name']!,
                                  style: fontProvider.getTextStyle(
                                    fontSize: 20,
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
                              style: const TextStyle(fontSize: 14),
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
                  onContinue();
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
              Text(
                'What currency do you use?',
                style: fontProvider.getTextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              Expanded(
                child: ListView.separated(
                  itemCount: LocaleProvider.supportedCurrencies.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                                : theme.colorScheme.outline.withValues(alpha: 0.3),
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'How do you want to budget?',
                style: fontProvider.getTextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              Expanded(
                child: ListView(
                  children: [
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

                    const SizedBox(height: 16),

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
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Privacy notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
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
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

            ...features.map((feature) => Padding(
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
                )),
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
  final Function(String accountName, String bankName, double balance, String iconType, String iconValue) onContinue;

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
    _nameController = TextEditingController(text: widget.initialAccountName ?? 'Main Account');
    _balanceController = TextEditingController(
      text: widget.initialBalance != null ? widget.initialBalance.toString() : '',
    );
    _bankNameController = TextEditingController(text: widget.initialBankName ?? '');
    _iconType = widget.initialIconType ?? 'emoji';
    _iconValue = widget.initialIconValue ?? '🏦';
    _bankNameFocus = FocusNode();
    _nameFocus = FocusNode();
    _balanceFocus = FocusNode();
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
      builder: (_) => OmniIconPickerModal(
        initialQuery: _bankNameController.text.trim(),
      ),
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
              Text(
                'Add your main account',
                style: fontProvider.getTextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
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
                      onTap: () => _bankNameController.selection = TextSelection(
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
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
  final Function(double payAmount, String frequency, DateTime nextPayDate) onContinue;

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
      text: widget.initialPayAmount != null ? widget.initialPayAmount.toString() : '',
    );
    _frequency = widget.initialFrequency ?? 'monthly';
    _nextPayDate = widget.initialNextPayDate ?? DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _continueToNext() {
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
              Text(
                'When do you get paid?',
                style: fontProvider.getTextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                        DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                        DropdownMenuItem(value: 'biweekly', child: Text('Bi-weekly')),
                        DropdownMenuItem(value: 'fourweekly', child: Text('Four-weekly')),
                        DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
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
                          lastDate: DateTime.now().add(const Duration(days: 90)),
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

class _EnvelopeMindsetStepState extends State<_EnvelopeMindsetStep>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late final List<Map<String, dynamic>> _examples;

  int _currentExampleIndex = 0;

  /// Get singular currency name for the tagline
  String _getCurrencySingularName(String currencyCode) {
    switch (currencyCode) {
      case 'GBP':
        return 'pound';
      case 'EUR':
        return 'euro';
      case 'USD':
      case 'CAD':
      case 'AUD':
      case 'NZD':
      case 'SGD':
      case 'HKD':
        return 'dollar';
      case 'MXN':
        return 'peso';
      case 'BRL':
        return 'real';
      case 'ARS':
        return 'peso';
      case 'JPY':
      case 'CNY':
        return 'yen';
      case 'INR':
        return 'rupee';
      case 'KRW':
        return 'won';
      case 'AED':
        return 'dirham';
      case 'SAR':
        return 'riyal';
      case 'ZAR':
        return 'rand';
      case 'CHF':
        return 'franc';
      case 'SEK':
      case 'NOK':
      case 'DKK':
        return 'krona';
      case 'PLN':
        return 'złoty';
      case 'TRY':
        return 'lira';
      default:
        return 'unit'; // Generic fallback
    }
  }

  /// Format currency for onboarding (symbol + whole number, no decimals)
  String _formatSimpleCurrency(double amount, String symbol) {
    return '$symbol${amount.round()}';
  }

  @override
  void initState() {
    super.initState();

    // Get converted amounts
    final convertedAmounts = OnboardingCurrencyConverter.getExamples(
      widget.selectedCurrency,
    );

    // Build examples with converted amounts
    _examples = [
      {'text': 'Netflix gets', 'amount': convertedAmounts['netflix']!, 'emoji': '📺'},
      {'text': 'Groceries get', 'amount': convertedAmounts['groceries']!, 'emoji': '🛒'},
      {'text': 'Savings get', 'amount': convertedAmounts['savings']!, 'emoji': '💰'},
      {'text': 'That coffee run gets', 'amount': convertedAmounts['coffee']!, 'emoji': '☕'},
    ];

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animateExamples();
  }

  Future<void> _animateExamples() async {
    for (int i = 0; i < _examples.length; i++) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        setState(() => _currentExampleIndex = i);
        _animationController.reset();
        _animationController.forward();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    final currencyName = _getCurrencySingularName(widget.selectedCurrency);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom - 48,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              // Animated envelope icon
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.elasticOut,
                builder: (context, double scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.mail,
                        size: 60,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // Main headline
              Text(
                'Welcome to Envelope Thinking',
                style: fontProvider.getTextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Tagline - dynamic currency
              Text(
                '"Give every $currencyName a purpose"',
                style: fontProvider.getTextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Animated examples
              SizedBox(
                height: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(_examples.length, (index) {
                    if (index > _currentExampleIndex) {
                      return const SizedBox.shrink();
                    }

                    final example = _examples[index];
                    final formattedAmount = _formatSimpleCurrency(
                      example['amount'] as double,
                      localeProvider.currencySymbol,
                    );
                    return FadeTransition(
                      opacity: index == _currentExampleIndex
                          ? _fadeAnimation
                          : const AlwaysStoppedAnimation(1.0),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          '→ ${example['text']} $formattedAmount ${example['emoji']}',
                          style: TextStyle(
                            fontSize: 20,
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 32),

              // Value propositions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'When you stuff your envelopes, you know EXACTLY what you can afford for everything.',
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Set recurring payments. Automate pay day. See your future balances. Never guess again.',
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.primary,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // CTA button
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
                      'I\'m Ready!',
                      style: fontProvider.getTextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('🎯', style: TextStyle(fontSize: 24)),
                  ],
                ),
              ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// _BinderTemplateSelectionStep
class _BinderTemplateSelectionStep extends StatelessWidget {
  final Function(BinderTemplate?) onContinue;
  final VoidCallback onSkip;
  final VoidCallback? onBack;

  const _BinderTemplateSelectionStep({
    required this.onContinue,
    required this.onSkip,
    this.onBack,
  });

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
            children: [
              Text(
                'Let\'s create your first binder!',
                style: fontProvider.getTextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
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

              const SizedBox(height: 32),

              Expanded(
                child: ListView(
                  children: [
                    ...binderTemplates.map((template) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TemplateCard(
                            template: template,
                            onTap: () => onContinue(template),
                          ),
                        )),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  if (onBack != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onBack!();
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Go back',
                          style: fontProvider.getTextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (onBack != null) const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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

class _TemplateCard extends StatelessWidget {
  final BinderTemplate template;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
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
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  template.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${template.name} Binder',
                    style: fontProvider.getTextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    template.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${template.envelopes.length} envelopes',
                      style: TextStyle(
                        fontSize: 12,
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
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// _TargetIconStep
class _TargetIconStep extends StatefulWidget {
  final VoidCallback onContinue;

  const _TargetIconStep({required this.onContinue});

  @override
  State<_TargetIconStep> createState() => _TargetIconStepState();
}

class _TargetIconStepState extends State<_TargetIconStep> {
  String? _selectedEmoji;

  Future<void> _openEmojiPicker() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const OmniIconPickerModal(
        initialQuery: '',
      ),
    );

    if (!mounted) return;

    if (result != null && result['type'] == 'emoji') {
      final emoji = result['value'] as String;
      setState(() {
        _selectedEmoji = emoji;
      });
      // Save to provider
      final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
      localeProvider.setCelebrationEmoji(emoji);
    }
  }

  void _selectEmoji(String emoji) {
    setState(() {
      _selectedEmoji = emoji;
    });
    // Save to provider
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    localeProvider.setCelebrationEmoji(emoji);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    final displayEmoji = _selectedEmoji ?? localeProvider.celebrationEmoji;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom - 48,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Choose Your 100% Celebration!',
                    style: fontProvider.getTextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'When your envelopes hit their target, they\'ll show this icon instead of the pie.',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        displayEmoji,
                        style: const TextStyle(fontSize: 60),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  Text(
                    'Quick picks:',
                    style: fontProvider.getTextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildEmojiOption('🎯', displayEmoji),
                      const SizedBox(width: 16),
                      _buildEmojiOption('💯', displayEmoji),
                      const SizedBox(width: 16),
                      _buildEmojiOption('🥳', displayEmoji),
                    ],
                  ),

                  const SizedBox(height: 32),

                  OutlinedButton.icon(
                    onPressed: _openEmojiPicker,
                    icon: const Icon(Icons.search),
                    label: Text(
                      'Search for emoji',
                      style: fontProvider.getTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

              const SizedBox(height: 16),

              Text(
                'Or just type an emoji from your keyboard! 😎',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

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
      ),
    );
  }

  Widget _buildEmojiOption(String emoji, String currentEmoji) {
    final theme = Theme.of(context);
    final isSelected = emoji == currentEmoji;

    return GestureDetector(
      onTap: () => _selectEmoji(emoji),
      child: Container(
        width: 80,
        height: 80,
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
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 40),
          ),
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🎉', style: TextStyle(fontSize: 60)),
                ),
              ),

              const SizedBox(height: 32),

              Text(
                'You\'re All Set, $userName!',
                style: fontProvider.getTextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              if (envelopeCount > 0) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'You\'ve created $envelopeCount envelope${envelopeCount == 1 ? '' : 's'}',
                        style: fontProvider.getTextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (isAccountMode)
                        Text(
                          'Your next pay day will auto-fill your envelopes. Check Time Machine to see your future!',
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        )
                      else
                        Text(
                          'Tap Pay Day to allocate money across your envelopes',
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pro tip: If you have cash in your account now, go to each envelope and add the current amount you\'ve already set aside for it.',
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

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
                  'Start Budgeting →',
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
    );
  }
}

