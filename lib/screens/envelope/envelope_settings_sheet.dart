// lib/screens/envelope/envelope_settings_sheet.dart
// COMPLETE FILE WITH NEW EMOJI PICKER INTEGRATED

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/envelope.dart';
import '../../models/envelope_group.dart';
import '../../services/envelope_repo.dart';
import '../../services/group_repo.dart';
import '../../widgets/group_editor.dart' as editor;
import '../../providers/font_provider.dart';
import '../add_scheduled_payment_screen.dart';
import '../../widgets/emoji_picker_sheet.dart';

class EnvelopeSettingsSheet extends StatefulWidget {
  const EnvelopeSettingsSheet({
    super.key,
    required this.envelopeId,
    required this.repo,
    required this.groupRepo,
  });

  final String envelopeId;
  final EnvelopeRepo repo;
  final GroupRepo groupRepo;

  @override
  State<EnvelopeSettingsSheet> createState() => _EnvelopeSettingsSheetState();
}

class _EnvelopeSettingsSheetState extends State<EnvelopeSettingsSheet> {
  final _nameController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _targetController = TextEditingController();
  final _autoFillAmountController = TextEditingController();

  String? _selectedEmoji;
  String? _selectedBinderId;
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

  // NEW: Use reusable emoji picker
  Future<void> _showEmojiPicker(Envelope envelope) async {
    final result = await showEmojiPickerSheet(
      context: context,
      initialEmoji: _selectedEmoji ?? envelope.emoji,
    );

    if (result != null) {
      setState(() {
        _selectedEmoji = result.isEmpty ? null : result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

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
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  physics: const ClampingScrollPhysics(),
                  children: [
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
                    InkWell(
                      onTap: () => _showEmojiPicker(envelope),
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
                              'Emoji',
                              style: fontProvider.getTextStyle(fontSize: 18),
                            ),
                            const Spacer(),
                            Text(
                              _selectedEmoji ?? envelope.emoji ?? '💰',
                              style: const TextStyle(fontSize: 32),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                            value: _selectedBinderId,
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
                                final binderColor = GroupColors.getThemedColor(
                                  binder.colorName,
                                  theme.colorScheme,
                                );
                                return DropdownMenuItem(
                                  value: binder.id,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (binder.emoji != null) ...[
                                        Text(
                                          binder.emoji!,
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Flexible(
                                        child: Text(
                                          binder.name,
                                          style: fontProvider.getTextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: binderColor,
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

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
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
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
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
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
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
                    OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => _confirmDelete(envelope),
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
        'targetAmount': targetAmount,
        'autoFillEnabled': _autoFillEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
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
          'Are you sure you want to delete "${envelope.name}"? This will also delete all associated transactions. This action cannot be undone.',
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
      setState(() => _isLoading = true);

      try {
        await widget.repo.deleteEnvelope(widget.envelopeId);

        if (mounted) {
          Navigator.pop(context);
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Envelope deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting envelope: $e')),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }
}
