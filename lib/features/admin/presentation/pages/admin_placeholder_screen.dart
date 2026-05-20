import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../theme/context_extensions.dart';

/// Placeholder screen shown for admin features not yet implemented.
class AdminPlaceholderScreen extends StatelessWidget {
  const AdminPlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: context.surface.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.spacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: DesignColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.construction_rounded,
                  size: 44,
                  color: DesignColors.primary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Coming Soon',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.text.primary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'This feature is coming in the next update.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.text.secondary,
                      height: 1.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
