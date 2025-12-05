// lib/widgets/partner_badge.dart
// FONT PROVIDER INTEGRATED: All GoogleFonts.caveat() replaced with FontProvider

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // NEW IMPORT
import 'package:google_fonts/google_fonts.dart';
import '../providers/font_provider.dart'; // NEW IMPORT

/// Badge to display on partner's envelopes/binders
class PartnerBadge extends StatelessWidget {
  const PartnerBadge({
    super.key,
    required this.partnerName,
    this.size = PartnerBadgeSize.normal,
  });

  final String partnerName;
  final PartnerBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontProvider = Provider.of<FontProvider>(context, listen: false);

    final fontSize = size == PartnerBadgeSize.small ? 10.0 : 12.0;
    final padding = size == PartnerBadgeSize.small
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 4);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withAlpha(51),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.secondary.withAlpha(128),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person,
            size: size == PartnerBadgeSize.small ? 10 : 12,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 4),
          Text(
            partnerName,
            // UPDATED: FontProvider
            style: fontProvider.getTextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

enum PartnerBadgeSize { small, normal }

/// Check if envelope belongs to partner
bool isPartnerEnvelope(String envelopeUserId, String currentUserId) {
  return envelopeUserId != currentUserId;
}
