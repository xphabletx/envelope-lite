// lib/screens/envelope/envelope_settings_sheet.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/envelope.dart';
import '../../models/envelope_group.dart';
import '../../models/account.dart'; // NEW
import '../../services/envelope_repo.dart';
import '../../services/group_repo.dart';
import '../../services/account_repo.dart'; // NEW
import '../../widgets/group_editor.dart' as editor;
import '../../providers/font_provider.dart';
import '../add_scheduled_payment_screen.dart';
import '../../widgets/envelope/omni_icon_picker_modal.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_themes.dart';

class EnvelopeSettingsSheet extends StatefulWidget {
  const EnvelopeSettingsSheet({
    super.key,
    required this.envelopeId,
    required this.repo,
    required this.groupRepo,
    required this.accountRepo, // NEW
  });

  final String envelopeId;
  final EnvelopeRepo repo;
  final GroupRepo groupRepo;
  final AccountRepo accountRepo; // NEW

  @override
  State<EnvelopeSettingsSheet> createState() => _EnvelopeSettingsSheetState();
}

class _EnvelopeSettingsSheetState extends State<EnvelopeSettingsSheet> {
  final _nameController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _targetController = TextEditingController();
  final _autoFillAmountController = TextEditingController();

  String? _selectedEmoji;
  String? _iconType;
  String? _iconValue;
  String? _selectedBinderId;
  String? _selectedAccountId; // NEW
  bool _autoFillEnabled = false;
  bool _isLoading = false;
  bool _initialized = false;
  List<EnvelopeGroup> _binders = [];
  bool _bindersLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBinders();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subtitleController.dispose();
    _targetController.dispose();
    _autoFillAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadBinders() async {
    if (_bindersLoaded) return;

    try {
      final snapshot = await widget.groupRepo.groupsCol().get();
      final allBinders = snapshot.docs
          .map((doc) => EnvelopeGroup.fromFirestore(doc))
          .toList();

      final uniqueBinders = <String, EnvelopeGroup>{};
      for (final binder in allBinders) {
        uniqueBinders[binder.id] = binder;
      }

      if (mounted) {
        setState(() {
          _binders = uniqueBinders.values.toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          _bindersLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _binders = [];
          _bindersLoaded = true;
        });
      }
    }
  }

  Future<void> _createNewBinder() async {
    await editor.showGroupEditor(
      context: context,
      groupRepo: widget.groupRepo,
      envelopeRepo: widget.repo,
    );
    setState(() => _bindersLoaded = false);
    await _loadBinders();
  }

  Future<void> _pickIcon(Envelope envelope) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const OmniIconPickerModal(),
    );

    if (result != null) {
      setState(() {
        _iconType = result['type'].toString().split('.').last;
        _iconValue = result['value'] as String;
        if (_iconType == 'emoji') {
          _selectedEmoji = _iconValue;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return StreamBuilder<Envelope>(
      stream: widget.repo.envelopeStream(widget.envelopeId),
      builder: (context, envelopeSnapshot) {
        if (!envelopeSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final envelope = envelopeSnapshot.data!;

        if (!_bindersLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!_initialized && _bindersLoaded) {
          _nameController.text = envelope.name;
          _subtitleController.text = envelope.subtitle ?? '';
          _targetController.text =
              envelope.targetAmount?.toStringAsFixed(2) ?? '';
          _autoFillAmountController.text =
              envelope.autoFillAmount?.toStringAsFixed(2) ?? '';
          _selectedEmoji = envelope.emoji;
          _iconType = envelope.iconType;
          _iconValue = envelope.iconValue;
          _selectedAccountId = envelope.linkedAccountId; // NEW

          if (envelope.groupId != null &&
              _binders.any((b) => b.id == envelope.groupId)) {
            _selectedBinderId = envelope.groupId;
          } else {
            _selectedBinderId = null;
          }

          _autoFillEnabled = envelope.autoFillEnabled;
          _initialized = true;
        }

        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Icon(
                      Icons.settings,
                      size: 28,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Envelope Settings',
                        style: fontProvider.getTextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 8,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  physics: const ClampingScrollPhysics(),
                  children: [
                    // NAME INPUT
                    TextField(
                      controller: _nameController,
                      style: fontProvider.getTextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Envelope Name',
                        labelStyle: fontProvider.getTextStyle(fontSize: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.mail),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ICON PICKER
                    InkWell(
                      onTap: () => _pickIcon(envelope),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.colorScheme.outline),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.emoji_emotions),
                            const SizedBox(width: 16),
                            Text(
                              'Icon',
                              style: fontProvider.getTextStyle(fontSize: 18),
                            ),
                            const Spacer(),
                            envelope
                                .copyWith(
                                  iconType: _iconType,
                                  iconValue: _iconValue,
                                  emoji: _selectedEmoji,
                                )
                                .getIconWidget(theme, size: 32),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // SUBTITLE
                    TextField(
                      controller: _subtitleController,
                      style: fontProvider
                          .getTextStyle(fontSize: 18)
                          .copyWith(fontStyle: FontStyle.italic),
                      decoration: InputDecoration(
                        labelText: 'Subtitle (optional)',
                        labelStyle: fontProvider.getTextStyle(fontSize: 16),
                        hintText: 'e.g., "Weekly shopping"',
                        hintStyle: fontProvider
                            .getTextStyle(fontSize: 16, color: Colors.grey)
                            .copyWith(fontStyle: FontStyle.italic),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.notes),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // TARGET AMOUNT
                    TextField(
                      controller: _targetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: fontProvider.getTextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Target Amount (£)',
                        labelStyle: fontProvider.getTextStyle(fontSize: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.flag),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Divider(color: theme.colorScheme.outline),
                    const SizedBox(height: 16),

                    // BINDER SELECTOR
                    Text(
                      'Binder',
                      style: fontProvider.getTextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: _selectedBinderId,
                            decoration: InputDecoration(
                              labelText: 'Add to Binder',
                              labelStyle: fontProvider.getTextStyle(
                                fontSize: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.folder),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(
                                  'No Binder',
                                  style: fontProvider.getTextStyle(
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              ..._binders.map((binder) {
                                final binderColorOption =
                                    ThemeBinderColors.getColorsForTheme(
                                        themeProvider.currentThemeId)[binder.colorIndex];
                                // Use envelopeTextColor for better contrast, especially for light binders
                                final textColor = binderColorOption.envelopeTextColor;
                                return DropdownMenuItem(
                                  value: binder.id,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      binder.getIconWidget(theme, size: 20),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          binder.name,
                                          style: fontProvider.getTextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            onChanged: (value) =>
                                setState(() => _selectedBinderId = value),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.add_circle,
                            color: theme.colorScheme.secondary,
                          ),
                          tooltip: 'Create new binder',
                          onPressed: _createNewBinder,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Divider(color: theme.colorScheme.outline),
                    const SizedBox(height: 16),

                    // ACCOUNT LINKING SECTION (NEW)
                    Text(
                      'Account Link',
                      style: fontProvider.getTextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Where does money for this envelope come from?',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withAlpha(153),
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<Account>>(
                      stream: widget.accountRepo.accountsStream(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }
                        final accounts = snapshot.data!;

                        return DropdownButtonFormField<String?>(
                          initialValue: _selectedAccountId,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(
                              Icons.account_balance_wallet,
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(
                                'Not linked',
                                style: fontProvider.getTextStyle(fontSize: 16),
                              ),
                            ),
                            ...accounts.map(
                              (account) => DropdownMenuItem(
                                value: account.id,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      account.emoji ?? '💳',
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        account.name,
                                        style: fontProvider.getTextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedAccountId = val);
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                    Divider(color: theme.colorScheme.outline),
                    const SizedBox(height: 16),

                    // SCHEDULE PAYMENT LINK
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withAlpha(26),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        'Schedule Payment',
                        style: fontProvider.getTextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Set up recurring deposits/withdrawals',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withAlpha(153),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddScheduledPaymentScreen(
                              repo: widget.repo,
                              preselectedEnvelopeId: envelope.id,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                    Divider(color: theme.colorScheme.outline),
                    const SizedBox(height: 16),

                    // AUTO-FILL SECTION
                    Text(
                      'Pay Day Auto-Fill',
                      style: fontProvider.getTextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: _autoFillEnabled,
                      onChanged: (value) =>
                          setState(() => _autoFillEnabled = value),
                      title: Text(
                        'Enable Auto-Fill',
                        style: fontProvider.getTextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Automatically add money on pay day',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withAlpha(153),
                        ),
                      ),
                    ),
                    if (_autoFillEnabled) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _autoFillAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: fontProvider.getTextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Auto-Fill Amount (£)',
                          labelStyle: fontProvider.getTextStyle(fontSize: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.autorenew),
                          helperText: 'Amount to add each pay day',
                          helperStyle: fontProvider.getTextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),

                    // SAVE BUTTON
                    FilledButton(
                      onPressed: _isLoading
                          ? null
                          : () => _saveChanges(envelope),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Save Changes',
                              style: fontProvider.getTextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // DELETE BUTTON
                    OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              debugPrint('[EnvelopeSettingsSheet] 🔴 Delete button tapped');
                              _confirmDelete(envelope);
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.red.shade600),
                      ),
                      child: Text(
                        'Delete Envelope',
                        style: fontProvider.getTextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveChanges(Envelope envelope) async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Envelope name cannot be empty')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final targetAmount = _targetController.text.isEmpty
          ? null
          : double.tryParse(_targetController.text);

      final autoFillAmount =
          _autoFillEnabled && _autoFillAmountController.text.isNotEmpty
          ? double.tryParse(_autoFillAmountController.text)
          : null;

      final Map<String, dynamic> updates = {
        'name': _nameController.text.trim(),
        'emoji': _selectedEmoji,
        'iconType': _iconType,
        'iconValue': _iconValue,
        'targetAmount': targetAmount,
        'autoFillEnabled': _autoFillEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
        // Save Linked Account
        'linkedAccountId': _selectedAccountId,
      };

      if (_subtitleController.text.trim().isEmpty) {
        updates['subtitle'] = FieldValue.delete();
      } else {
        updates['subtitle'] = _subtitleController.text.trim();
      }

      if (_selectedBinderId == null) {
        updates['groupId'] = FieldValue.delete();
      } else {
        updates['groupId'] = _selectedBinderId;
      }

      if (_autoFillEnabled && autoFillAmount != null) {
        updates['autoFillAmount'] = autoFillAmount;
      } else {
        updates['autoFillAmount'] = FieldValue.delete();
      }

      await widget.repo.db
          .collection('users')
          .doc(widget.repo.currentUserId)
          .collection('solo')
          .doc('data')
          .collection('envelopes')
          .doc(widget.envelopeId)
          .update(updates);

      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating envelope: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmDelete(Envelope envelope) async {
    debugPrint('[EnvelopeSettingsSheet] 📋 Showing delete confirmation dialog');
    final fontProvider = Provider.of<FontProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Envelope?',
          style: fontProvider.getTextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${envelope.name}"?\n\n'
          'This will also delete:\n'
          '• All associated transactions\n'
          '• All scheduled payments for this envelope\n\n'
          'This action cannot be undone.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: fontProvider.getTextStyle(fontSize: 18),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: Text(
              'Delete',
              style: fontProvider.getTextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      debugPrint('[EnvelopeSettingsSheet] ✅ User confirmed delete');
      debugPrint('[EnvelopeSettingsSheet] Envelope ID: ${widget.envelopeId}');
      debugPrint('[EnvelopeSettingsSheet] Envelope name: ${envelope.name}');

      setState(() => _isLoading = true);

      try {
        debugPrint('[EnvelopeSettingsSheet] 📞 Calling repo.deleteEnvelope...');
        await widget.repo.deleteEnvelope(widget.envelopeId);
        debugPrint('[EnvelopeSettingsSheet] ✅ Delete completed successfully');

        if (mounted) {
          debugPrint('[EnvelopeSettingsSheet] Popping navigation and showing success message');
          Navigator.pop(context);
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Envelope deleted')));
        }
      } catch (e) {
        debugPrint('[EnvelopeSettingsSheet] ❌ Delete failed with error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting envelope: $e')),
          );
          setState(() => _isLoading = false);
        }
      }
    } else if (confirmed == false) {
      debugPrint('[EnvelopeSettingsSheet] ❌ User cancelled delete');
    } else if (!mounted) {
      debugPrint('[EnvelopeSettingsSheet] ⚠️ Widget not mounted, skipping delete');
    }
  }
}
