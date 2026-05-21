import 'package:flutter/material.dart';

import '../../ui/guard_tokens.dart';

/// Inline warning-style error banner — used in shift, directory, today summary.
/// Shows icon + message row with a Retry button aligned right.
class GuardInlineErrorBanner extends StatelessWidget {
  const GuardInlineErrorBanner({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GuardTokens.g2),
      decoration: BoxDecoration(
        color: GuardTokens.warningMuted,
        borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
        border: Border.all(color: GuardTokens.warning.withValues(alpha: 0.45)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: GuardTokens.warning),
              const SizedBox(width: GuardTokens.g2),
              Expanded(child: Text(message)),
            ],
          ),
          const SizedBox(height: GuardTokens.g2),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              style: GuardTokens.textLink(context),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered full-screen error — used in logs page tabs.
/// Shows cloud_off icon + message + filled Retry button.
class GuardCenteredError extends StatelessWidget {
  const GuardCenteredError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GuardTokens.padScreen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: GuardTokens.warning.withValues(alpha: 0.9),
            ),
            const SizedBox(height: GuardTokens.g2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GuardTokens.bodyStyle(context),
            ),
            const SizedBox(height: GuardTokens.g2),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: GuardTokens.primaryFilled(context),
            ),
          ],
        ),
      ),
    );
  }
}
