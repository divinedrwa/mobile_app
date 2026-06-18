import 'package:flutter/material.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/utils/pdf_share.dart';

/// Shown when an invoice has already been generated/cached for a cycle.
/// Lets the resident view or share the saved file, or rebuild a fresh copy.
Future<void> showInvoiceActionsSheet(
  BuildContext context,
  String path, {
  required Future<void> Function() onRegenerate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text(
            'Invoice ready',
            style: DesignTypography.bodyMedium.copyWith(
              color: DesignColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          ListTile(
            leading: const Icon(Icons.visibility_outlined,
                color: DesignColors.primary),
            title: const Text('View invoice'),
            onTap: () {
              Navigator.pop(ctx);
              openSavedPdf(path);
            },
          ),
          ListTile(
            leading: const Icon(Icons.ios_share, color: DesignColors.primary),
            title: const Text('Share invoice'),
            onTap: () {
              Navigator.pop(ctx);
              shareSavedPdf(path);
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh, color: DesignColors.textSecondary),
            title: const Text('Regenerate'),
            subtitle: const Text('Rebuild with the latest details'),
            onTap: () {
              Navigator.pop(ctx);
              onRegenerate();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
