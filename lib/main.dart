import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'bootstrap/app_bootstrap.dart';
import 'core/routing/app_router.dart';
import 'core/services/push_lifecycle_binding.dart';
import 'core/telemetry/guard_analytics_bridge.dart';
import 'theme/theme.dart' as gp_theme;
import 'features/auth/presentation/providers/auth_provider.dart';
import 'core/routing/app_navigator_keys.dart';
import 'core/session/account_deactivated_handler.dart';
import 'core/session/session_expired_handler.dart';
import 'core/services/notification_service.dart';
import 'core/constants/app_constants.dart';

void main() async {
  final r = await bootstrapDivineBeforeRunApp();

  registerGuardFlowTelemetry(firebaseAvailable: r.firebaseInitialized);

  final pushBinding = PushLifecycleBinding();
  WidgetsBinding.instance.addObserver(pushBinding);

  runApp(
    const ProviderScope(
      child: DivineApp(),
    ),
  );
}

class DivineApp extends ConsumerStatefulWidget {
  const DivineApp({super.key});

  @override
  ConsumerState<DivineApp> createState() => _DivineAppState();
}

class _DivineAppState extends ConsumerState<DivineApp> {
  final _routerRefresh = RouterRefreshNotifier();
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().flushPendingNavigation();
      AccountDeactivatedHandler.register(() async {
        try {
          await ref.read(authProvider.notifier).logout();
        } catch (_) {
          // Ensure local session clears even if logout API fails.
        }
        final ctx = appRootNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          GoRouter.of(ctx).go('/login');
        }
      });
      // Same shape, but for plain expired/revoked tokens (no "deactivated"
      // server message). Fires once per burst — see SessionExpiredHandler.
      SessionExpiredHandler.register(() async {
        try {
          await ref.read(authProvider.notifier).logout();
        } catch (_) {
          // Local session must clear even if logout API fails.
        }
        final ctx = appRootNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          GoRouter.of(ctx).go('/login');
        }
      });
    });
  }

  @override
  void dispose() {
    _router?.dispose();
    _routerRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _router ??= AppRouter.router(ref, refreshListenable: _routerRefresh);

    ref.listen<AuthState>(authProvider, (prev, next) {
      _routerRefresh.notify();
    });

    // Theme preference is persisted via [gp_theme.ThemeModeNotifier]
    // (system / light / dark). `themeTokensProvider` holds the active
    // palette and is ready to accept an API-driven override later.
    final themeMode = ref.watch(gp_theme.themeModeProvider);
    final tokens = ref.watch(gp_theme.themeTokensProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: gp_theme.AppTheme.light(palette: tokens.light),
      darkTheme: gp_theme.AppTheme.dark(palette: tokens.dark),
      themeMode: themeMode,
      routerConfig: _router!,
    );
  }
}
