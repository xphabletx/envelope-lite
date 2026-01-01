// lib/providers/onboarding_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingProvider extends ChangeNotifier {
  int _currentStep = 0;
  bool _isInitialized = false;
  bool _hasAttemptedInit = false;

  int get currentStep => _currentStep;
  bool get isInitialized => _isInitialized;

  /// Initialize from SharedPreferences (local-only)
  Future<void> initialize(String userId) async {
    if (_hasAttemptedInit) return;
    _hasAttemptedInit = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // TEMPORARY DEBUG: Uncomment the next 2 lines to reset onboarding state
      // await prefs.remove('onboarding_step_$userId');
      // debugPrint('[OnboardingProvider] 🔧 DEBUG: Cleared onboarding step');

      // Check if onboarding is already complete - if so, don't load saved step
      final hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding_$userId') ?? false;
      if (hasCompletedOnboarding) {
        debugPrint('[OnboardingProvider] ⏭️ Onboarding already complete - clearing saved step');
        await prefs.remove('onboarding_step_$userId');
        _currentStep = 0;
        _isInitialized = true;
        return;
      }

      final savedStep = prefs.getInt('onboarding_step_$userId') ?? 0;

      // Validate step is in valid range (0-7)
      if (savedStep < 0 || savedStep > 7) {
        debugPrint('[OnboardingProvider] ⚠️ Invalid step $savedStep - resetting to 0');
        _currentStep = 0;
      } else {
        _currentStep = savedStep;
      }

      _isInitialized = true;

      debugPrint('[OnboardingProvider] ✅ Loaded step from SharedPreferences: $_currentStep');
    } catch (e) {
      debugPrint('[OnboardingProvider] ❌ Error loading step: $e');
      _currentStep = 0;
      _isInitialized = true;
    }
  }

  /// Set current step and persist to SharedPreferences
  Future<void> setStep(int step, String userId) async {
    if (_currentStep == step) return;

    _currentStep = step;
    notifyListeners();

    try {
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('onboarding_step_$userId', step);

      debugPrint('[OnboardingProvider] ✅ Step saved locally: $step');
    } catch (e) {
      debugPrint('[OnboardingProvider] ❌ Error saving step: $e');
    }
  }

  /// Clear onboarding step (called when onboarding is complete)
  Future<void> clearStep(String userId) async {
    _currentStep = 0;
    _isInitialized = false;
    _hasAttemptedInit = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('onboarding_step_$userId');

      debugPrint('[OnboardingProvider] ✅ Onboarding step cleared');
    } catch (e) {
      debugPrint('[OnboardingProvider] ❌ Error clearing step: $e');
    }
  }

  /// Reset provider state (for testing or logout)
  void reset() {
    _currentStep = 0;
    _isInitialized = true; // CRITICAL: Set to true so UI doesn't show loading spinner
    _hasAttemptedInit = false; // Allow re-initialization if needed
    notifyListeners();
    debugPrint('[OnboardingProvider] ✅ Reset to step 0, isInitialized=true');
  }
}
