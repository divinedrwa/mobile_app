import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/models/daily_help_model.dart';
import '../../data/providers/daily_help_provider.dart';
import '../widgets/list_skeleton.dart';
import 'add_daily_help_screen.dart';

/// Vendors screen (daily help / household services).
class DailyHelpScreen extends ConsumerWidget {
  const DailyHelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final helpersState = ref.watch(dailyHelpProvider);

    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(
        backgroundColor: context.surface.defaultSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.text.primary),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Staff & Vendors', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: context.text.primary)),
            Text('Your household service providers', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.text.secondary, height: 1.2)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add vendor',
            icon: Icon(Icons.add_rounded, size: 26, color: context.brand.primary),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDailyHelpScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: () => ref.read(dailyHelpProvider.notifier).fetchDailyHelp(),
        child: helpersState.when(
          loading: () => const ListSkeleton(itemHeight: 72),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              EnterpriseInfoBanner(
                icon: Icons.support_agent_outlined,
                title: 'Could not load staff & vendors',
                message: userFacingMessage(error),
                tone: EnterpriseTone.danger,
                actionLabel: 'Retry',
                onAction: () => ref.read(dailyHelpProvider.notifier).fetchDailyHelp(),
              ),
            ],
          ),
          data: (helpers) => helpers.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    EmptyStateWidget(
                      icon: Icons.support_agent_outlined,
                      title: 'No staff added yet',
                      subtitle: 'Add your regular helpers like maids, cooks, or drivers.',
                      actionLabel: 'Add staff',
                      onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDailyHelpScreen())),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: helpers.length,
                  itemBuilder: (context, index) {
                    final helper = helpers[index];
                    final helperColor = _getHelperColor(helper.type);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: EnterprisePanel(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: helperColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_getHelperIcon(helper.type), color: helperColor, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(helper.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: context.text.primary)),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(color: helperColor.withValues(alpha: 0.1), borderRadius: DesignRadius.borderXS),
                                        child: Text(helper.type, style: TextStyle(fontSize: 11, color: helperColor, fontWeight: FontWeight.w700)),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(Icons.phone_outlined, size: 12, color: context.text.tertiary),
                                      const SizedBox(width: 3),
                                      Text(helper.phone, style: TextStyle(fontSize: 12, color: context.text.secondary)),
                                    ],
                                  ),
                                  if (helper.timings != null) ...[
                                    const SizedBox(height: 2),
                                    Row(children: [
                                      Icon(Icons.access_time_outlined, size: 12, color: context.text.tertiary),
                                      const SizedBox(width: 3),
                                      Text(helper.timings!, style: TextStyle(fontSize: 12, color: context.text.secondary)),
                                    ]),
                                  ],
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Call',
                                  icon: Icon(Icons.call_rounded, color: DesignColors.success, size: 22),
                                  onPressed: () => _makeCall(helper.phone),
                                ),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert_rounded, color: context.text.tertiary, size: 20),
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _showDeleteSheet(context, ref, helper);
                                    } else {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => AddDailyHelpScreen(helper: helper)));
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    PopupMenuItem(value: 'delete', child: Text('Remove')),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 300.ms, delay: DesignAnimations.staggerFor(index));
                  },
                ),
        ),
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

  void _showDeleteSheet(
    BuildContext context,
    WidgetRef ref,
    DailyHelpModel helper,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: DesignColors.borderLight, borderRadius: BorderRadius.circular(2)),
                ),
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(color: DesignColors.error.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(Icons.person_remove_outlined, color: DesignColors.error, size: 28),
                ),
                const SizedBox(height: 16),
                Text('Remove staff?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: DesignColors.textPrimary)),
                const SizedBox(height: 8),
                Text(
                  'Remove ${helper.name} from your staff list?\nThis cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: DesignColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          Navigator.pop(sheetCtx);
                          if (helper.assignmentId == null || helper.assignmentId!.isEmpty) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Unable to remove this entry'), backgroundColor: DesignColors.error),
                            );
                            return;
                          }
                          final error = await ref.read(dailyHelpProvider.notifier).removeDailyHelp(helper.assignmentId!);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error ?? '${helper.name} removed'),
                              backgroundColor: error == null ? DesignColors.success : DesignColors.error,
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(backgroundColor: DesignColors.error, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                        child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
