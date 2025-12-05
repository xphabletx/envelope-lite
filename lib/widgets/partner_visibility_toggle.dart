// lib/widgets/partner_visibility_toggle.dart
// FONT PROVIDER INTEGRATED: All GoogleFonts.caveat() replaced with FontProvider

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // NEW IMPORT
import 'package:google_fonts/google_fonts.dart';
import '../services/workspace_helper.dart';
import '../providers/font_provider.dart'; // NEW IMPORT

class PartnerVisibilityToggle extends StatefulWidget {
  const PartnerVisibilityToggle({
    super.key,
    required this.isEnvelopes, // true for envelopes, false for binders
    required this.onChanged,
  });

  final bool isEnvelopes;
  final ValueChanged<bool> onChanged;

  @override
  State<PartnerVisibilityToggle> createState() =>
      _PartnerVisibilityToggleState();
}

class _PartnerVisibilityToggleState extends State<PartnerVisibilityToggle> {
  bool _showPartner = true;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final show = widget.isEnvelopes
        ? await WorkspaceHelper.getShowPartnerEnvelopes()
        : await WorkspaceHelper.getShowPartnerBinders();

    if (mounted) {
      setState(() => _showPartner = show);
    }
  }

  Future<void> _toggle(bool value) async {
    setState(() => _showPartner = value);

    if (widget.isEnvelopes) {
      await WorkspaceHelper.setShowPartnerEnvelopes(value);
    } else {
      await WorkspaceHelper.setShowPartnerBinders(value);
    }

    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withAlpha(51)),
      ),
      child: Row(
        children: [
          Icon(
            widget.isEnvelopes ? Icons.visibility : Icons.folder,
            color: theme.colorScheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Show Partner ${widget.isEnvelopes ? 'Envelopes' : 'Binders'}',
              // UPDATED: FontProvider
              style: fontProvider.getTextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Switch(
            value: _showPartner,
            onChanged: _toggle,
            activeColor: theme.colorScheme.secondary,
          ),
        ],
      ),
    );
  }
}
