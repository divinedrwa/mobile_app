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
          _tile(
            context,
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'View society alerts, approvals, and activity updates',
            onTap: () => context.push(GuardRoutes.notifications),
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
              onTap: () => _showSignOutSheet(context, ref),
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

  /// Bottom sheet that confirms before clearing the auth session. Mirrors the
  /// resident `profile_screen.dart` pattern so a fat-finger tap doesn't kick
  /// a guard out of an active gate shift. Visual styling uses GuardTokens so
  /// it matches the rest of the guard module instead of the resident palette.
  Future<void> _showSignOutSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: GuardTokens.sectionGap),
                decoration: BoxDecoration(
                  color: GuardTokens.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: GuardTokens.dangerBrand.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: GuardTokens.dangerBrand,
                  size: 28,
                ),
              ),
              const SizedBox(height: GuardTokens.sectionGap),
              Text(
                'Sign out?',
                style: GuardTokens.headingStyle(context).copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: GuardTokens.g1),
              Text(
                'You will need to sign in again to record entries at this gate.',
                textAlign: TextAlign.center,
                style: GuardTokens.captionStyle(context).copyWith(
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: GuardTokens.sectionGap + 4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(GuardTokens.radiusButton),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: GuardTokens.g2),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        // logout() calls restartApp() — full relaunch.
                        await ref.read(authProvider.notifier).logout();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: GuardTokens.dangerBrand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(GuardTokens.radiusButton),
                        ),
                      ),
                      child: const Text(
                        'Sign out',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
