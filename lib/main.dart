import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
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
import 'core/widgets/offline_banner.dart';

// ---------------------------------------------------------------------------
// Native screen info for Display Zoom / Display Size detection.
//
// iOS Display Zoom and Android Display Size both change the effective density,
// making everything appear larger. Flutter can't detect this from MediaQuery
// alone. We fetch the device's true physical resolution via a platform channel
// (UIScreen.nativeBounds on iOS, Display.getRealMetrics on Android) and
// compute the natural logical size. If the current logical size is smaller
// (= zoomed in), _buildFixedScale uses FittedBox to render at the natural
// resolution and scale down to fit.
// ---------------------------------------------------------------------------
double? _naturalLogicalWidth;
double? _naturalLogicalHeight;

Future<void> _fetchNativeScreenInfo() async {
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

  // Fetch native screen resolution before building the UI (iOS + Android).
  await _fetchNativeScreenInfo();

  registerGuardFlowTelemetry(firebaseAvailable: r.firebaseInitialized);

  // Set up Firebase Crashlytics (release builds only).
  if (r.firebaseInitialized && kReleaseMode) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  }

  final pushBinding = PushLifecycleBinding();
  WidgetsBinding.instance.addObserver(pushBinding);

  void startApp() {
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

  // In release builds, catch uncaught async errors via Crashlytics.
  if (r.firebaseInitialized && kReleaseMode) {
    runZonedGuarded(
      startApp,
      (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      },
    );
  } else {
    startApp();
  }
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
      themeMode: ref.watch(gp_theme.themeModeProvider),
      routerConfig: _router!,
      builder: (context, child) {
        final scaled = _buildFixedScale(context, child);
        return OfflineBanner(child: scaled);
      },
    );
  }

  /// The logical width the app was designed for. Screens narrower than
  /// this render the full UI at [_designWidth] dp and use [FittedBox] to
  /// scale everything (text, icons, padding, margins) down proportionally.
  /// Screens wider than this render at their native size.
  static const double _designWidth = 420;

  /// Wraps the entire widget tree so the app always renders at its designed
  /// proportions — ignoring device text-size, display-zoom, and screen
  /// density settings. On narrow screens the whole UI is scaled down
  /// uniformly so text, icons, and spacing stay balanced.
  Widget _buildFixedScale(BuildContext context, Widget? child) {
    final data = MediaQuery.of(context);

    // 1. Lock text scaling and bold-text accessibility override.
    var fixedData = data.copyWith(
      textScaler: TextScaler.linear(data.textScaler.scale(14).clamp(14, 18.2) / 14),
      boldText: false,
    );

    // 2. Determine the target render width.
    //    Priority: display-zoom correction > design-width scaling > none.
    final naturalW = _naturalLogicalWidth;
    double targetW;

    if (naturalW != null && data.size.width < naturalW - 2) {
      // Display Zoom (iOS) or Display Size (Android) is active.
      targetW = naturalW;
    } else if (data.size.width < _designWidth) {
      // Narrow screen — render at design width for a compact look.
      targetW = _designWidth;
    } else {
      targetW = data.size.width;
    }

    // Debug output — visible in `flutter run` console.
    assert(() {
      debugPrint(
        '[FixedScale] textScaler=${data.textScaler} '
        'size=${data.size} targetW=${targetW.toStringAsFixed(1)} '
        'natural=${_naturalLogicalWidth?.toStringAsFixed(1)}x'
        '${_naturalLogicalHeight?.toStringAsFixed(1)}',
      );
      return true;
    }());

    // 3. Apply proportional scaling if needed.
    if (targetW > data.size.width + 2) {
      final scale = (data.size.width / targetW).clamp(0.5, 1.0);
      final correctedH = data.size.height / scale;

      fixedData = fixedData.copyWith(
        size: Size(targetW, correctedH),
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
            width: targetW,
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
