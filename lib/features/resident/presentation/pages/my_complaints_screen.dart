import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/providers/complaint_provider.dart';

/// Lists complaints from GET /residents/my-complaints (replaces former mock screen).
class MyComplaintsScreen extends ConsumerWidget {
  const MyComplaintsScreen({super.key});

  static Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'RESOLVED':
        return DesignColors.success;
      case 'IN_PROGRESS':
        return const Color(0xFFF59E0B);
      case 'OPEN':
      default:
        return DesignColors.primary;
    }
  }

  static String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'IN_PROGRESS':
        return 'In progress';
      case 'RESOLVED':
        return 'Resolved';
      case 'OPEN':
        return 'Open';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myComplaintsProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: DesignColors.textPrimary),
        ),
        title: const Text(
          'My Complaints',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: DesignColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New complaint',
            onPressed: () => context.push('/resident/complaint'),
            icon: const Icon(Icons.add_circle_outline, color: DesignColors.primary),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 56, color: DesignColors.error),
                const SizedBox(height: AppSpacing.md),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: DesignColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => ref.invalidate(myComplaintsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 72,
                      color: DesignColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No complaints yet',
                      style: DesignTypography.headingM.copyWith(
                        color: DesignColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Submit a complaint from Home or tap below.',
                      textAlign: TextAlign.center,
                      style: DesignTypography.bodySmall.copyWith(
                        color: DesignColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: () => context.push('/resident/complaint'),
                      icon: const Icon(Icons.add),
                      label: const Text('File a complaint'),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myComplaintsProvider);
              await ref.read(myComplaintsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: items.length,
              separatorBuilder: (context, _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final c = items[index];
                final color = _statusColor(c.status);
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: DesignRadius.borderLG,
                    side: BorderSide(
                      color: DesignColors.border.withValues(alpha: 0.6),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: DesignRadius.borderMD,
                      ),
                      child: Icon(Icons.report_problem_outlined, color: color),
                    ),
                    title: Text(
                      c.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.category,
                            style: TextStyle(
                              fontSize: 13,
                              color: DesignColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd MMM yyyy, hh:mm a').format(c.createdAt.toLocal()),
                            style: TextStyle(
                              fontSize: 12,
                              color: DesignColors.textSecondary.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: DesignRadius.borderXS,
                      ),
                      child: Text(
                        _statusLabel(c.status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    isThreeLine: true,
                  ),
                ).animate().fadeIn(duration: 250.ms, delay: (index * 40).ms);
              },
            ),
          );
        },
      ),
    );
  }
}
