import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../services/account_repo.dart';
import '../../providers/font_provider.dart';

class AccountEditorModal extends StatefulWidget {
  const AccountEditorModal({
    super.key,
    required this.accountRepo,
    this.account, // null = create mode, not null = edit mode
  });

  final AccountRepo accountRepo;
  final Account? account;

  @override
  State<AccountEditorModal> createState() => _AccountEditorModalState();
}

class _AccountEditorModalState extends State<AccountEditorModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController(text: '0.00');
  final _nameFocus = FocusNode();
  final _balanceFocus = FocusNode();

  String? _selectedEmoji;
  String _selectedColor = 'Primary';
  bool _isDefault = false;
  bool _saving = false;

  bool get _isEditMode => widget.account != null;

  @override
  void initState() {
    super.initState();
    // If editing, populate fields
    if (_isEditMode) {
      _nameController.text = widget.account!.name;
      _balanceController.text = widget.account!.currentBalance.toStringAsFixed(
        2,
      );
      _selectedEmoji = widget.account!.emoji;
      _selectedColor = widget.account!.colorName ?? 'Primary';
      _isDefault = widget.account!.isDefault;
    }

    // Auto-focus name field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _nameFocus.requestFocus();
      }
    });

    // Select all text in balance when focused
    _balanceFocus.addListener(() {
      if (_balanceFocus.hasFocus) {
        _balanceController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _balanceController.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _nameFocus.dispose();
    _balanceFocus.dispose();
    super.dispose();
  }

  Future<void> _pickEmoji() async {
    final controller = TextEditingController(text: _selectedEmoji ?? '');
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Choose Emoji',
          style: fontProvider.getTextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Type or paste an emoji',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 2,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 60),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                onSubmitted: (value) {
                  Navigator.pop(context);
                  setState(() {
                    _selectedEmoji = value.characters.isEmpty
                        ? null
                        : value.characters.first;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _selectedEmoji = null);
            },
            child: Text(
              'Remove',
              style: fontProvider.getTextStyle(fontSize: 16),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: fontProvider.getTextStyle(fontSize: 16),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _selectedEmoji = controller.text.characters.isEmpty
                    ? null
                    : controller.text.characters.first;
              });
            },
            child: Text(
              'Save',
              style: fontProvider.getTextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final balanceText = _balanceController.text.trim();
    final balance = double.tryParse(balanceText);

    if (balance == null || balance < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid balance')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      if (_isEditMode) {
        // Update existing account
        await widget.accountRepo.updateAccount(
          accountId: widget.account!.id,
          name: name,
          currentBalance: balance,
          emoji: _selectedEmoji,
          colorName: _selectedColor,
          isDefault: _isDefault,
        );
      } else {
        // Create new account
        await widget.accountRepo.createAccount(
          name: name,
          startingBalance: balance,
          emoji: _selectedEmoji,
          colorName: _selectedColor,
          isDefault: _isDefault,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode ? 'Account updated!' : 'Account created!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
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

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 28,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _isEditMode ? 'Edit Account' : 'New Account',
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

            // Form content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: media.viewInsets.bottom + 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name field
                      TextFormField(
                        controller: _nameController,
                        focusNode: _nameFocus,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        style: fontProvider.getTextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Account Name',
                          labelStyle: fontProvider.getTextStyle(fontSize: 18),
                          hintText: 'e.g. Main Account',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.account_balance_wallet),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                        onEditingComplete: () => _balanceFocus.requestFocus(),
                      ),
                      const SizedBox(height: 16),

                      // Emoji picker
                      InkWell(
                        onTap: _pickEmoji,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.5,
                              ),
                            ),
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
                                _selectedEmoji ?? '💳',
                                style: const TextStyle(fontSize: 32),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Balance field
                      TextFormField(
                        controller: _balanceController,
                        focusNode: _balanceFocus,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        style: fontProvider.getTextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          labelText: _isEditMode
                              ? 'Current Balance'
                              : 'Starting Balance',
                          labelStyle: fontProvider.getTextStyle(fontSize: 18),
                          hintText: '0.00',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixText: '£ ',
                          prefixStyle: fontProvider.getTextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          _balanceController.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: _balanceController.text.length,
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Color picker
                      DropdownButtonFormField<String>(
                        initialValue: _selectedColor,
                        decoration: InputDecoration(
                          labelText: 'Color Theme',
                          labelStyle: fontProvider.getTextStyle(fontSize: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.palette),
                        ),
                        items:
                            [
                              'Primary',
                              'Secondary',
                              'Tertiary',
                              'Red',
                              'Orange',
                              'Yellow',
                              'Green',
                              'Blue',
                              'Purple',
                              'Pink',
                            ].map((color) {
                              return DropdownMenuItem(
                                value: color,
                                child: Text(
                                  color,
                                  style: fontProvider.getTextStyle(
                                    fontSize: 18,
                                  ),
                                ),
                              );
                            }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedColor = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Default toggle
                      SwitchListTile(
                        value: _isDefault,
                        onChanged: (value) {
                          setState(() => _isDefault = value);
                        },
                        title: Text(
                          'Set as default account',
                          style: fontProvider.getTextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Pay Day deposits will go to this account',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Save button
                      FilledButton(
                        onPressed: _saving ? null : _handleSave,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isEditMode ? 'Save Changes' : 'Create Account',
                                style: fontProvider.getTextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
