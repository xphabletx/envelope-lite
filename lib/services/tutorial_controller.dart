import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simplified tutorial flow - 5 steps only
enum TutorialStep {
  notStarted, // 0 - Tutorial hasn't begun
  welcome, // 1 - Welcome message
  autoCreating, // 2 - Creating envelope automatically
  envelopeCreated, // 3 - Show the created envelope
  swipeGesture, // 4 - Demo swipe actions
  complete, // 5 - Tutorial finished
}

/// Manages tutorial state and progression
class TutorialController extends ChangeNotifier {
  TutorialStep _currentStep = TutorialStep.notStarted;
  bool _isActive = false;

  TutorialStep get currentStep => _currentStep;
  bool get isActive => _isActive;

  static const String _stepKey = 'tutorial_current_step';
  static const String _activeKey = 'tutorial_is_active';

  Future<void> loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stepIndex = prefs.getInt(_stepKey) ?? 0;
      final savedActive = prefs.getBool(_activeKey) ?? false;

      if (stepIndex < TutorialStep.values.length) {
        _currentStep = TutorialStep.values[stepIndex];
        _isActive = savedActive;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading tutorial state: $e');
    }
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_stepKey, _currentStep.index);
      await prefs.setBool(_activeKey, _isActive);
    } catch (e) {
      debugPrint('Error saving tutorial state: $e');
    }
  }

  Future<void> start() async {
    _currentStep = TutorialStep.welcome;
    _isActive = true;
    await _saveState();
    notifyListeners();
  }

  Future<void> nextStep() async {
    if (_currentStep == TutorialStep.complete) return;

    final currentIndex = _currentStep.index;
    if (currentIndex + 1 < TutorialStep.values.length) {
      _currentStep = TutorialStep.values[currentIndex + 1];

      if (_currentStep == TutorialStep.complete) {
        _isActive = false;
      }

      await _saveState();
      notifyListeners();
    }
  }

  Future<void> goToStep(TutorialStep step) async {
    _currentStep = step;

    if (step == TutorialStep.complete) {
      _isActive = false;
    }

    await _saveState();
    notifyListeners();
  }

  Future<void> skipTour() async {
    _currentStep = TutorialStep.complete;
    _isActive = false;
    await _saveState();
    notifyListeners();
  }

  Future<void> complete() async {
    _currentStep = TutorialStep.complete;
    _isActive = false;
    await _saveState();
    notifyListeners();
  }

  Future<void> reset() async {
    _currentStep = TutorialStep.notStarted;
    _isActive = false;
    await _saveState();
    notifyListeners();
  }

  bool isOnStep(TutorialStep step) => _currentStep == step;
  bool isPastStep(TutorialStep step) => _currentStep.index > step.index;
}
