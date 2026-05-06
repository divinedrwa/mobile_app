import 'package:flutter/material.dart';

import '../../ui/guard_tokens.dart';

class GuardDashboardError extends StatelessWidget {
  const GuardDashboardError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minH =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          primary: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minH),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(GuardTokens.g3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 56, color: GuardTokens.warning.withValues(alpha: 0.85)),
                    const SizedBox(height: GuardTokens.g2),
                    Text(
                      'Unable to reach server',
                      textAlign: TextAlign.center,
                      style: GuardTokens.headingStyle(context),
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: GuardTokens.bodyStyle(context),
                    ),
                    const SizedBox(height: GuardTokens.sectionGap),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                      style: GuardTokens.primaryFilled(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
