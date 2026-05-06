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

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: GuardTokens.headingStyle(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(GuardTokens.padScreen),
        children: [
          if (user != null)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: GuardTokens.guardAccent.withValues(
                    alpha: 0.15,
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: GuardTokens.guardAccentDeep,
                  ),
                ),
                title: Text(user.name),
                subtitle: Text(
                  '${user.email} · ${user.role.value}',
                  style: GuardTokens.captionStyle(context),
                ),
              ),
            ),
          const SizedBox(height: GuardTokens.g2),
          _tile(
            context,
            icon: Icons.sensor_door_rounded,
            title: 'Shift details',
            onTap: () => context.push(GuardRoutes.shift),
          ),
          _tile(
            context,
            icon: Icons.apartment_rounded,
            title: 'Residents directory',
            onTap: () => context.push(GuardRoutes.directory),
          ),
          _tile(
            context,
            icon: Icons.report_problem_outlined,
            title: 'Incident report',
            onTap: () => context.push(GuardRoutes.incident),
          ),
          _tile(
            context,
            icon: Icons.emergency_rounded,
            title: 'Emergency broadcast',
            onTap: () => context.push(GuardRoutes.emergency),
          ),
          const Divider(height: GuardTokens.sectionGap),
          ListTile(
            leading: Icon(Icons.logout_rounded, color: DesignColors.error),
            title: Text('Log out', style: TextStyle(color: DesignColors.error)),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: GuardTokens.g2),
      child: ListTile(
        leading: Icon(icon, color: GuardTokens.guardAccent),
        title: Text(title, style: const TextStyle(fontSize: GuardTokens.body)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
