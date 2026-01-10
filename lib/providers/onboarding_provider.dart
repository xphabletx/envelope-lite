// lib/providers/onboarding_provider.dart
import 'package:flutter/foundation.dart';
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
    debugPrint('[Onboarding:Provider] 🚀 Initializing for userId: $userId');

    if (_hasAttemptedInit) {
      debugPrint('[Onboarding:Provider] ⚠️ Already attempted initialization - skipping');
      return;
    }
    _hasAttemptedInit = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // TEMPORARY DEBUG: Uncomment the next 2 lines to reset onboarding state
      // await prefs.remove('onboarding_step_$userId');

      // Check if onboarding is already complete - if so, don't load saved step
      final hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding_$userId') ?? false;
      debugPrint('[Onboarding:Provider] 📊 hasCompletedOnboarding: $hasCompletedOnboarding');

      if (hasCompletedOnboarding) {
        await prefs.remove('onboarding_step_$userId');
        _currentStep = 0;
        _isInitialized = true;
        debugPrint('[Onboarding:Provider] ✅ Onboarding already completed - cleared step and set to 0');
        return;
      }

      final savedStep = prefs.getInt('onboarding_step_$userId') ?? 0;
      debugPrint('[Onboarding:Provider] 📥 Loaded saved step: $savedStep');

      // Validate step is in valid range (0-7)
      if (savedStep < 0 || savedStep > 7) {
        debugPrint('[Onboarding:Provider] ⚠️ Invalid saved step ($savedStep) - resetting to 0');
        _currentStep = 0;
      } else {
        _currentStep = savedStep;
      }

      _isInitialized = true;
      debugPrint('[Onboarding:Provider] ✅ Initialization complete - currentStep: $_currentStep');

    } catch (e) {
      debugPrint('[Onboarding:Provider] ❌ Error during initialization: $e');
      _currentStep = 0;
      _isInitialized = true;
    }
  }

  /// Set current step and persist to SharedPreferences
  Future<void> setStep(int step, String userId) async {
    if (_currentStep == step) {
      debugPrint('[Onboarding:Provider] ⚠️ Step unchanged (already at $step) - skipping');
      return;
    }

    debugPrint('[Onboarding:Provider] 🔄 Setting step - oldStep: $_currentStep, newStep: $step, userId: $userId');
    _currentStep = step;
    notifyListeners();

    try {
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('onboarding_step_$userId', step);
      debugPrint('[Onboarding:Provider] ✅ Step saved to SharedPreferences');
    } catch (e) {
      debugPrint('[Onboarding:Provider] ❌ Failed to save step to SharedPreferences: $e');
    }
  }

  /// Clear onboarding step (called when onboarding is complete)
  Future<void> clearStep(String userId) async {
    debugPrint('[Onboarding:Provider] 🗑️ Clearing onboarding step for userId: $userId');

    _currentStep = 0;
    _isInitialized = false;
    _hasAttemptedInit = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('onboarding_step_$userId');
      debugPrint('[Onboarding:Provider] ✅ Step cleared from SharedPreferences');
    } catch (e) {
      debugPrint('[Onboarding:Provider] ❌ Failed to clear step from SharedPreferences: $e');
    }
  }

  /// Reset provider state (for testing or logout)
  void reset() {
    debugPrint('[Onboarding:Provider] 🔄 Resetting provider state');

    _currentStep = 0;
    _isInitialized = true; // CRITICAL: Set to true so UI doesn't show loading spinner
    _hasAttemptedInit = false; // Allow re-initialization if needed
    notifyListeners();

    debugPrint('[Onboarding:Provider] ✅ Provider reset complete');
  }
}
