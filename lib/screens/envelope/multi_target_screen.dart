// lib/screens/envelope/multi_target_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/envelope.dart';
import '../../services/envelope_repo.dart';
import '../../services/group_repo.dart';
import '../../services/account_repo.dart';
import '../../services/scheduled_payment_repo.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/time_machine_provider.dart';
import '../../providers/horizon_controller.dart';
import 'horizon_widgets/horizon_summary_card.dart';
import 'horizon_widgets/horizon_control_panel.dart';
import 'horizon_widgets/horizon_envelope_tile.dart';

enum TargetScreenMode {
  singleEnvelope,
  multiEnvelope,
  binderFiltered,
}

class MultiTargetScreen extends StatefulWidget {
  const MultiTargetScreen({
    super.key,
    required this.envelopeRepo,
    required this.groupRepo,
    required this.accountRepo,
    required this.scheduledPaymentRepo,
    this.initialEnvelopeIds,
    this.initialGroupId,
    this.mode = TargetScreenMode.multiEnvelope,
    this.title,
  });

  final EnvelopeRepo envelopeRepo;
  final GroupRepo groupRepo;
  final AccountRepo accountRepo;
  final ScheduledPaymentRepo scheduledPaymentRepo;
  final List<String>? initialEnvelopeIds; // Pre-selected envelope IDs
  final String? initialGroupId; // Filter by binder/group
  final TargetScreenMode mode;
  final String? title; // Custom title

  @override
  State<MultiTargetScreen> createState() => _MultiTargetScreenState();
}

class _MultiTargetScreenState extends State<MultiTargetScreen> {
  late HorizonController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HorizonController(
      envelopeRepo: widget.envelopeRepo,
      accountRepo: widget.accountRepo,
      scheduledRepo: widget.scheduledPaymentRepo,
    );

    if (widget.initialEnvelopeIds != null) {
      _controller.selectedEnvelopeIds.addAll(widget.initialEnvelopeIds!);
    }

    _controller.refreshAvailableFunds();
  }

  @override
  Widget build(BuildContext context) {
    final fontProvider = Provider.of<FontProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);
    final timeMachine = Provider.of<TimeMachineProvider>(context);

    return ChangeNotifierProvider.value(
      value: _controller,
      child: StreamBuilder<List<Envelope>>(
        stream: widget.envelopeRepo.envelopesStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );

          final allEnvelopes = snapshot.data!;

          // Filter by user (exclude partner envelopes)
          var filteredEnvelopes = allEnvelopes
              .where((e) => e.userId == widget.envelopeRepo.currentUserId)
              .toList();

          // Filter by group if specified
          if (widget.initialGroupId != null) {
            filteredEnvelopes = filteredEnvelopes
                .where((e) => e.groupId == widget.initialGroupId)
                .toList();
          }

          // Only show envelopes with targets
          filteredEnvelopes = filteredEnvelopes
              .where((e) => e.targetAmount != null && e.targetAmount! > 0)
              .toList();

          // Auto-select all envelopes by default if nothing is selected
          if (_controller.selectedEnvelopeIds.isEmpty && filteredEnvelopes.isNotEmpty) {
            if (widget.mode == TargetScreenMode.singleEnvelope) {
              // Single mode: select only the first envelope
              _controller.selectedEnvelopeIds.add(filteredEnvelopes.first.id);
            } else {
              // Multi mode: select all envelopes by default
              _controller.selectedEnvelopeIds.addAll(
                filteredEnvelopes.map((e) => e.id),
              );
            }
          }

          // Calculate baselines for selected envelopes
          final selectedEnvelopes = filteredEnvelopes
              .where((e) => _controller.selectedEnvelopeIds.contains(e.id))
              .toList();

          if (selectedEnvelopes.isNotEmpty) {
            _controller.calculateBaselines(selectedEnvelopes);
          }

          return Scaffold(
            appBar: AppBar(
              title: Text(
                widget.title ??
                (widget.mode == TargetScreenMode.singleEnvelope
                    ? 'Target Horizon'
                    : 'Horizon Navigator'),
                style: fontProvider.getTextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: Consumer<HorizonController>(
              builder: (context, controller, _) {
                final selectedList = filteredEnvelopes
                    .where((e) => controller.selectedEnvelopeIds.contains(e.id))
                    .toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Component 1: Summary (Step 2)
                    HorizonSummaryCard(
                      envelopesToShow: selectedList,
                      controller: controller,
                      fontProvider: fontProvider,
                      locale: locale,
                      timeMachine: timeMachine,
                    ),
                    const SizedBox(height: 20),

                    // Component 2: Controls (Step 3)
                    HorizonControlPanel(
                      controller: controller,
                      fontProvider: fontProvider,
                      locale: locale,
                    ),
                    const SizedBox(height: 24),

                    // Component 3: The List (Step 4)
                    Text(
                      'Individual Horizons',
                      style: fontProvider.getTextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...filteredEnvelopes.map(
                      (envelope) => HorizonEnvelopeTile(
                        envelope: envelope,
                        controller: controller,
                        fontProvider: fontProvider,
                        locale: locale,
                        isSelected: controller.selectedEnvelopeIds.contains(
                          envelope.id,
                        ),
                        onToggleSelection: () => setState(() {
                          if (controller.selectedEnvelopeIds.contains(
                            envelope.id,
                          )) {
                            controller.selectedEnvelopeIds.remove(envelope.id);
                          } else {
                            controller.selectedEnvelopeIds.add(envelope.id);
                          }
                        }),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
