import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// ---------------------------------------------------------------------------
// Native screen info for iOS Display Zoom detection.
//
// On iOS, Display Zoom changes BOTH the physical and logical sizes reported
// to Flutter (while keeping devicePixelRatio the same). The only way to know
// the device's *real* hardware resolution is UIScreen.nativeBounds, which we
// fetch via a platform channel before runApp.
// ---------------------------------------------------------------------------
double? _naturalLogicalWidth;
double? _naturalLogicalHeight;

Future<void> _fetchNativeScreenInfo() async {
  if (!Platform.isIOS) return;
  try {
    const channel = MethodChannel('com.app.gatepass/display');
    final info =
        await channel.invokeMapMethod<String, dynamic>('getNativeScreenInfo');
    if (info != null) {
      final w = (info['nativeWidth'] as num).toDouble();
      final h = (info['nativeHeight'] as num).toDouble();
      final s = (info['nativeScale'] as num).toDouble();
      if (s > 0) {
        _naturalLogicalWidth = w / s;
        _naturalLogicalHeight = h / s;
      }
    }
  } catch (_) {
    // Channel unavailable — Display Zoom correction disabled.
  }
}

void main() async {
  final r = await bootstrapDivineBeforeRunApp();

  // Fetch iOS native resolution before building the UI.
  await _fetchNativeScreenInfo();

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
      builder: _buildFixedScale,
    );
  }

  /// Wraps the entire widget tree so the app always renders at its designed
  /// sizes — ignoring both the device text-size setting (Dynamic Type /
  /// Android Font Size) AND the display-zoom setting (iOS Display Zoom /
  /// Android Display Size).
  Widget _buildFixedScale(BuildContext context, Widget? child) {
    final data = MediaQuery.of(context);

    // 1. Lock text scaling to the app's designed font sizes.
    var fixedData = data.copyWith(textScaler: TextScaler.noScaling);

    // Debug output — visible in `flutter run` console.
    assert(() {
      debugPrint(
        '[FixedScale] textScaler=${data.textScaler} '
        'size=${data.size} '
        'natural=${_naturalLogicalWidth?.toStringAsFixed(1)}x'
        '${_naturalLogicalHeight?.toStringAsFixed(1)}',
      );
      return true;
    }());

    // 2. Counteract iOS Display Zoom (or Android Display Size).
    //
    // On iOS, Display Zoom changes the reported physical AND logical
    // resolution (DPR stays constant), so MediaQuery alone can't detect it.
    // We compare the current logical size with the native hardware size
    // obtained via the platform channel at startup.
    //
    // On Android, the native MainActivity resets fontScale and densityDpi
    // so this path usually won't trigger; it's here as a safety net.
    final naturalW = _naturalLogicalWidth;
    final naturalH = _naturalLogicalHeight;

    if (naturalW != null &&
        naturalH != null &&
        data.size.width < naturalW - 2) {
      final scale = (data.size.width / naturalW).clamp(0.5, 1.0);
      final correctedH = naturalH;

      fixedData = fixedData.copyWith(
        size: Size(naturalW, correctedH),
        padding: data.padding / scale,
        viewPadding: data.viewPadding / scale,
        viewInsets: data.viewInsets / scale,
      );

      return MediaQuery(
        data: fixedData,
        child: FittedBox(
          fit: BoxFit.fill,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: naturalW,
            height: correctedH,
            child: child!,
          ),
        ),
      );
    }

    return MediaQuery(
      data: fixedData,
      child: child!,
    );
  }
}
