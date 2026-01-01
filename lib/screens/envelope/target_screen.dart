// lib/screens/envelope/target_screen.dart

import 'package:flutter/material.dart';
import '../../models/envelope.dart';
import '../../services/envelope_repo.dart';
import '../../services/group_repo.dart';
import '../../services/account_repo.dart';
import 'multi_target_screen.dart';

/// Legacy wrapper for backwards compatibility
/// Delegates to MultiTargetScreen in single-envelope mode
class TargetScreen extends StatelessWidget {
  const TargetScreen({
    super.key,
    required this.envelope,
    required this.envelopeRepo,
    required this.groupRepo,
    required this.accountRepo,
  });

  final Envelope envelope;
  final EnvelopeRepo envelopeRepo;
  final GroupRepo groupRepo;
  final AccountRepo accountRepo;

  @override
  Widget build(BuildContext context) {
    return MultiTargetScreen(
      envelopeRepo: envelopeRepo,
      groupRepo: groupRepo,
      accountRepo: accountRepo,
      initialEnvelopeIds: [envelope.id],
      mode: TargetScreenMode.singleEnvelope,
      title: '${envelope.name} Target',
    );
  }
}
