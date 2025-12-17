// lib/models/projection.dart

/// Result of a projection calculation
class ProjectionResult {
  final DateTime projectionDate;
  final Map<String, AccountProjection>
  accountProjections; // accountId -> projection
  final List<ProjectionEvent> timeline; // What happens between now and then
  final double totalAvailable; // Sum of all available across accounts
  final double totalAssigned; // Sum of all assigned across accounts

  ProjectionResult({
    required this.projectionDate,
    required this.accountProjections,
    required this.timeline,
    required this.totalAvailable,
    required this.totalAssigned,
  });

  double get totalBalance => totalAvailable + totalAssigned;
}

/// Projection for a single account
class AccountProjection {
  final String accountId;
  final String accountName;
  final double projectedBalance; // Total balance on target date
  final double assignedAmount; // Amount assigned to envelopes
  final double availableAmount; // Free money (balance - assigned)
  final List<EnvelopeProjection> envelopeProjections;

  AccountProjection({
    required this.accountId,
    required this.accountName,
    required this.projectedBalance,
    required this.assignedAmount,
    required this.availableAmount,
    required this.envelopeProjections,
  });
}

/// Projection for a single envelope
class EnvelopeProjection {
  final String envelopeId;
  final String envelopeName;
  final String? emoji;
  final double currentAmount;
  final double projectedAmount; // Amount after all scheduled payments/deposits
  final double targetAmount;
  final bool hasTarget;
  final bool willMeetTarget; // Will projected amount meet/exceed target?

  EnvelopeProjection({
    required this.envelopeId,
    required this.envelopeName,
    this.emoji,
    required this.currentAmount,
    required this.projectedAmount,
    required this.targetAmount,
    required this.hasTarget,
    required this.willMeetTarget,
  });

  double get changeAmount => projectedAmount - currentAmount;
  bool get isIncrease => changeAmount > 0;
}

/// Event that affects balance (pay day, bill, etc)
class ProjectionEvent {
  final DateTime date;
  final String type; // 'pay_day', 'scheduled_payment', 'auto_fill'
  final String description;
  final double amount;
  final bool isCredit; // true = money in, false = money out
  final String? envelopeId;
  final String? envelopeName;
  final String? accountId;
  final String? accountName;

  ProjectionEvent({
    required this.date,
    required this.type,
    required this.description,
    required this.amount,
    required this.isCredit,
    this.envelopeId,
    this.envelopeName,
    this.accountId,
    this.accountName,
  });

  @override
  String toString() {
    final sign = isCredit ? '+' : '-';
    // Removed hardcoded '£' for better localization support in logs
    return '$date: $description ($sign$amount)';
  }
}

/// Scenario configuration for "what if" projections
class ProjectionScenario {
  final DateTime startDate;
  final DateTime endDate;
  final double? customPayAmount; // Override default pay amount
  final String? customPayFrequency; // Override default frequency
  final Map<String, bool> envelopeEnabled; // envelopeId -> on/off
  final Map<String, double> envelopeOverrides; // envelopeId -> custom amount
  final List<TemporaryEnvelope> temporaryEnvelopes;
  final Map<String, bool>
  binderEnabled; // binderId -> on/off (toggles all envelopes)

  ProjectionScenario({
    required this.startDate,
    required this.endDate,
    this.customPayAmount,
    this.customPayFrequency,
    this.envelopeEnabled = const {},
    this.envelopeOverrides = const {},
    this.temporaryEnvelopes = const [],
    this.binderEnabled = const {},
  });

  // Create default scenario (all envelopes enabled, no overrides)
  factory ProjectionScenario.defaults({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return ProjectionScenario(startDate: startDate, endDate: endDate);
  }

  ProjectionScenario copyWith({
    DateTime? startDate,
    DateTime? endDate,
    double? customPayAmount,
    String? customPayFrequency,
    Map<String, bool>? envelopeEnabled,
    Map<String, double>? envelopeOverrides,
    List<TemporaryEnvelope>? temporaryEnvelopes,
    Map<String, bool>? binderEnabled,
  }) {
    return ProjectionScenario(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      customPayAmount: customPayAmount ?? this.customPayAmount,
      customPayFrequency: customPayFrequency ?? this.customPayFrequency,
      envelopeEnabled: envelopeEnabled ?? this.envelopeEnabled,
      envelopeOverrides: envelopeOverrides ?? this.envelopeOverrides,
      temporaryEnvelopes: temporaryEnvelopes ?? this.temporaryEnvelopes,
      binderEnabled: binderEnabled ?? this.binderEnabled,
    );
  }
}

/// Temporary envelope for scenario testing
class TemporaryEnvelope {
  final String id; // Generated UUID
  final String name;
  final double amount;
  final DateTime effectiveDate; // When this envelope "kicks in"
  final String? linkedAccountId;
  final String? emoji;
  final bool isRecurring; // If true, repeats monthly
  final int? dayOfMonth; // For recurring payments

  TemporaryEnvelope({
    required this.id,
    required this.name,
    required this.amount,
    required this.effectiveDate,
    this.linkedAccountId,
    this.emoji,
    this.isRecurring = false,
    this.dayOfMonth,
  });
}
