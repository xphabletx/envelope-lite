// lib/models/onboarding_progress.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Stores incremental onboarding progress
/// Saved to users/{userId}/onboarding/progress
/// Transferred to main app collections only on completion
class OnboardingProgress {
  final String userId;

  // Step completion tracking
  final int currentStep;
  final DateTime lastUpdated;

  // User profile data
  final String? userName;
  final String? photoUrl;

  // Preferences
  final String? selectedCurrency;
  final String? selectedTheme;
  final String? selectedFont;

  // Mode selection
  final bool? isAccountMode;

  // Account data (not saved to main app until completion)
  final String? accountName;
  final String? bankName;
  final double? accountBalance;
  final String? accountIconType;
  final String? accountIconValue;

  // Pay day data (not saved to main app until completion)
  final double? payAmount;
  final String? payFrequency;
  final DateTime? nextPayDate;

  // Template selection
  final String? selectedTemplateId;

  // Celebration emoji
  final String? celebrationEmoji;

  OnboardingProgress({
    required this.userId,
    this.currentStep = 0,
    required this.lastUpdated,
    this.userName,
    this.photoUrl,
    this.selectedCurrency,
    this.selectedTheme,
    this.selectedFont,
    this.isAccountMode,
    this.accountName,
    this.bankName,
    this.accountBalance,
    this.accountIconType,
    this.accountIconValue,
    this.payAmount,
    this.payFrequency,
    this.nextPayDate,
    this.selectedTemplateId,
    this.celebrationEmoji,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'currentStep': currentStep,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'userName': userName,
      'photoUrl': photoUrl,
      'selectedCurrency': selectedCurrency,
      'selectedTheme': selectedTheme,
      'selectedFont': selectedFont,
      'isAccountMode': isAccountMode,
      'accountName': accountName,
      'bankName': bankName,
      'accountBalance': accountBalance,
      'accountIconType': accountIconType,
      'accountIconValue': accountIconValue,
      'payAmount': payAmount,
      'payFrequency': payFrequency,
      'nextPayDate': nextPayDate != null ? Timestamp.fromDate(nextPayDate!) : null,
      'selectedTemplateId': selectedTemplateId,
      'celebrationEmoji': celebrationEmoji,
    };
  }

  factory OnboardingProgress.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OnboardingProgress(
      userId: data['userId'] as String,
      currentStep: data['currentStep'] as int? ?? 0,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userName: data['userName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      selectedCurrency: data['selectedCurrency'] as String?,
      selectedTheme: data['selectedTheme'] as String?,
      selectedFont: data['selectedFont'] as String?,
      isAccountMode: data['isAccountMode'] as bool?,
      accountName: data['accountName'] as String?,
      bankName: data['bankName'] as String?,
      accountBalance: (data['accountBalance'] as num?)?.toDouble(),
      accountIconType: data['accountIconType'] as String?,
      accountIconValue: data['accountIconValue'] as String?,
      payAmount: (data['payAmount'] as num?)?.toDouble(),
      payFrequency: data['payFrequency'] as String?,
      nextPayDate: (data['nextPayDate'] as Timestamp?)?.toDate(),
      selectedTemplateId: data['selectedTemplateId'] as String?,
      celebrationEmoji: data['celebrationEmoji'] as String?,
    );
  }

  OnboardingProgress copyWith({
    int? currentStep,
    DateTime? lastUpdated,
    String? userName,
    String? photoUrl,
    String? selectedCurrency,
    String? selectedTheme,
    String? selectedFont,
    bool? isAccountMode,
    String? accountName,
    String? bankName,
    double? accountBalance,
    String? accountIconType,
    String? accountIconValue,
    double? payAmount,
    String? payFrequency,
    DateTime? nextPayDate,
    String? selectedTemplateId,
    String? celebrationEmoji,
  }) {
    return OnboardingProgress(
      userId: userId,
      currentStep: currentStep ?? this.currentStep,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      userName: userName ?? this.userName,
      photoUrl: photoUrl ?? this.photoUrl,
      selectedCurrency: selectedCurrency ?? this.selectedCurrency,
      selectedTheme: selectedTheme ?? this.selectedTheme,
      selectedFont: selectedFont ?? this.selectedFont,
      isAccountMode: isAccountMode ?? this.isAccountMode,
      accountName: accountName ?? this.accountName,
      bankName: bankName ?? this.bankName,
      accountBalance: accountBalance ?? this.accountBalance,
      accountIconType: accountIconType ?? this.accountIconType,
      accountIconValue: accountIconValue ?? this.accountIconValue,
      payAmount: payAmount ?? this.payAmount,
      payFrequency: payFrequency ?? this.payFrequency,
      nextPayDate: nextPayDate ?? this.nextPayDate,
      selectedTemplateId: selectedTemplateId ?? this.selectedTemplateId,
      celebrationEmoji: celebrationEmoji ?? this.celebrationEmoji,
    );
  }
}
