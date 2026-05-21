import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/models/daily_help_model.dart';
import '../../data/providers/daily_help_provider.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../widgets/list_skeleton.dart';
import 'add_daily_help_screen.dart';

/// Vendors screen (daily help / household services).
class DailyHelpScreen extends ConsumerWidget {
  const DailyHelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final helpersState = ref.watch(dailyHelpProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Vendors')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(dailyHelpProvider.notifier).fetchDailyHelp(),
        child: helpersState.when(
        loading: () => const ListSkeleton(itemHeight: 72),
        error: (error, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 56,
                color: DesignColors.error,
              ),
              const SizedBox(height: 12),
              Text(userFacingMessage(error), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.read(dailyHelpProvider.notifier).fetchDailyHelp(),
                child: const Text('Retry'),
              ),
            ],
          ),
          ),
        )]),
        data: (helpers) => helpers.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [EmptyStateWidget(
                icon: Icons.support_agent_outlined,
                title: 'No daily help added yet',
                subtitle: 'Add your regular service providers like maids, cooks, or drivers.',
                actionLabel: 'Add helper',
                onAction: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddDailyHelpScreen()),
                  );
                },
              )])
            : ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: helpers.length,
          itemBuilder: (context, index) {
            final helper = helpers[index];
            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    // Photo
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: _getHelperColor(
                        helper.type,
                      ).withValues(alpha: 0.2),
                      child: Icon(
                        _getHelperIcon(helper.type),
                        color: _getHelperColor(helper.type),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            helper.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getHelperColor(
                                helper.type,
                              ).withValues(alpha: 0.1),
                              borderRadius: DesignRadius.borderXS,
                            ),
                            child: Text(
                              helper.type,
                              style: TextStyle(
                                fontSize: 12,
                                color: _getHelperColor(helper.type),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone,
                                size: 14,
                                color: DesignColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                helper.phone,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: DesignColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          if (helper.timings != null)
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: DesignColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  helper.timings!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: DesignColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    // Actions
                    Column(
                      children: [
                        IconButton(
                          tooltip: 'Call',
                          icon: const Icon(Icons.call, color: Colors.green),
                          onPressed: () => _makeCall(helper.phone),
                        ),
                        PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'delete') {
                              _showDeleteDialog(context, ref, helper);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AddDailyHelpScreen(helper: helper),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 300.ms, delay: DesignAnimations.staggerFor(index));
          },
        ),
      )),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddDailyHelpScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Vendor'),
      ),
    );
  }

  IconData _getHelperIcon(String type) {
    switch (type.toLowerCase()) {
      case 'maid':
        return Icons.cleaning_services;
      case 'cook':
        return Icons.restaurant;
      case 'driver':
        return Icons.local_taxi;
      default:
        return Icons.person;
    }
  }

  Color _getHelperColor(String type) {
    switch (type.toLowerCase()) {
      case 'maid':
        return Colors.purple;
      case 'cook':
        return Colors.orange;
      case 'driver':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  void _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    DailyHelpModel helper,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Vendor?'),
        content: Text('Remove ${helper.name} from vendors list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (helper.assignmentId == null || helper.assignmentId!.isEmpty) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Unable to remove this entry'),
                    backgroundColor: DesignColors.error,
                  ),
                );
                return;
              }
              final ok = await ref
                  .read(dailyHelpProvider.notifier)
                  .removeDailyHelp(helper.assignmentId!);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok ? '${helper.name} removed' : 'Failed to remove helper',
                  ),
                  backgroundColor: ok
                      ? DesignColors.success
                      : DesignColors.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignColors.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
