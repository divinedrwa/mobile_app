import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../ui/guard_tokens.dart';
import '../router/guard_routes.dart';

/// Guard profile hub — shortcuts to auxiliary flows without polluting tabs.
class GuardProfilePage extends ConsumerWidget {
  const GuardProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? GuardTokens.darkCard : Colors.white;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : GuardTokens.textSecondary;
    final guardMeta = [
      user?.email.trim(),
      user?.societyName?.trim(),
    ].whereType<String>().where((value) => value.isNotEmpty).join('  •  ');

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: GuardTokens.headingStyle(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(GuardTokens.padScreen),
        children: [
          if (user != null) ...[
            Container(
              padding: const EdgeInsets.all(GuardTokens.g2),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(GuardTokens.radiusLg),
                border: Border.all(
                  color: isDark
                      ? GuardTokens.darkBorder
                      : GuardTokens.borderSubtle,
                ),
                boxShadow: GuardTokens.softCardShadow(context),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: GuardTokens.guardAccent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      user.name.trim().isEmpty
                          ? 'G'
                          : user.name.trim()[0].toUpperCase(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: GuardTokens.guardAccentDeep,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: GuardTokens.g2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: GuardTokens.headingStyle(context).copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: GuardTokens.guardAccent.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(
                              GuardTokens.radiusChip,
                            ),
                          ),
                          child: Text(
                            'Security guard',
                            style: GuardTokens.captionStyle(context).copyWith(
                              color: GuardTokens.guardAccentDeep,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (guardMeta.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            guardMeta,
                            style: GuardTokens.bodyStyle(
                              context,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: GuardTokens.sectionGap),
          ],
          _sectionLabel(context, 'Operations'),
          const SizedBox(height: GuardTokens.g2),
          _tile(
            context,
            icon: Icons.sensor_door_rounded,
            title: 'Shift details',
            subtitle: 'Check assigned gates, roster, and active duty status',
            onTap: () => context.push(GuardRoutes.shift),
          ),
          _tile(
            context,
            icon: Icons.apartment_rounded,
            title: 'Residents directory',
            subtitle: 'Search residents and start approval flows quickly',
            onTap: () => context.push(GuardRoutes.directory),
          ),
          _tile(
            context,
            icon: Icons.report_problem_outlined,
            title: 'Incident report',
            subtitle: 'Record security events with clear operational notes',
            onTap: () => context.push(GuardRoutes.incident),
          ),
          _tile(
            context,
            icon: Icons.emergency_rounded,
            title: 'Emergency broadcast',
            subtitle: 'Trigger urgent alerts for the society when needed',
            onTap: () => context.push(GuardRoutes.emergency),
          ),
          const SizedBox(height: GuardTokens.sectionGap),
          _sectionLabel(context, 'Session'),
          const SizedBox(height: GuardTokens.g2),
          Container(
            decoration: BoxDecoration(
              color: GuardTokens.dangerMuted.withValues(alpha: isDark ? 0.22 : 0.55),
              borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
              border: Border.all(
                color: GuardTokens.dangerBrand.withValues(alpha: 0.22),
              ),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: DesignColors.error,
              ),
              title: const Text(
                'Log out',
                style: TextStyle(
                  color: DesignColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'End this guard session and return to sign in',
                style: GuardTokens.captionStyle(context, color: subtitleColor),
              ),
              onTap: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: GuardTokens.g2),
      child: ListTile(
        leading: Icon(icon, color: GuardTokens.guardAccent),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: GuardTokens.body,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: GuardTokens.captionStyle(context),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: GuardTokens.captionStyle(context).copyWith(
        fontWeight: FontWeight.w700,
        color: GuardTokens.textSecondary,
      ),
    );
  }
}
