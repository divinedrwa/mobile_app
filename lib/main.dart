import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'bootstrap/app_bootstrap.dart';
import 'core/routing/app_router.dart';
import 'core/services/push_lifecycle_binding.dart';
import 'core/telemetry/guard_analytics_bridge.dart';
import 'core/utils/app_restart.dart';
import 'theme/theme.dart' as gp_theme;
import 'features/auth/presentation/providers/auth_provider.dart';
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
    // Changing [appRestartKey] rebuilds the entire tree including
    // ProviderScope — a full in-process restart (see [restartApp]).
    ValueListenableBuilder<Key>(
      valueListenable: appRestartKey,
      builder: (_, key, _) => ProviderScope(
        key: key,
        child: const DivineApp(),
      ),
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
        } catch (_) {}
        // logout() calls restartApp() — no navigation needed.
      });
      SessionExpiredHandler.register(() async {
        try {
          await ref.read(authProvider.notifier).logout();
        } catch (_) {}
        // logout() calls restartApp() — no navigation needed.
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

    // Only refresh the router when the user actually logs in or out.
    ref.listen<AuthState>(authProvider, (prev, next) {
      final wasAuth = prev?.isAuthenticated ?? false;
      final nowAuth = next.isAuthenticated;
      if (wasAuth != nowAuth) {
        _routerRefresh.notify();
      }
    });

    final tokens = ref.watch(gp_theme.themeTokensProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: gp_theme.AppTheme.light(palette: tokens.light),
      darkTheme: gp_theme.AppTheme.dark(palette: tokens.dark),
      themeMode: ThemeMode.light,
      routerConfig: _router!,
    );
  }
}
