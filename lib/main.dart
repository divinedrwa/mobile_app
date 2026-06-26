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
import 'core/services/app_update_lifecycle_binding.dart';
import 'core/services/gateway_payment_lifecycle_binding.dart';
import 'core/telemetry/guard_analytics_bridge.dart';
import 'core/utils/app_restart.dart';
import 'theme/theme.dart' as gp_theme;
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/guard/data/guard_data_refresh.dart';
import 'features/guard/presentation/providers/guard_providers.dart';
import 'features/resident/data/providers/banner_provider.dart';
import 'features/resident/data/providers/complaint_provider.dart';
import 'features/resident/data/providers/content_provider.dart';
import 'features/resident/data/providers/dashboard_provider.dart';
import 'features/resident/data/providers/maintenance_provider.dart';
import 'features/resident/data/providers/notification_provider.dart';
import 'features/resident/data/providers/parcel_provider.dart';
import 'features/resident/data/providers/special_project_provider.dart';
import 'features/resident/presentation/providers/visitor_provider.dart';
import 'features/resident/data/resident_data_refresh.dart';
import 'core/session/account_deactivated_handler.dart';
import 'core/session/session_expired_handler.dart';
import 'core/services/notification_service.dart';
import 'core/constants/app_constants.dart';
import 'core/services/app_version_service.dart';
import 'core/services/in_app_update_wrapper.dart';
import 'core/utils/platform_info.dart' as platform_info;
import 'core/widgets/app_update_dialog.dart';
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
  if (kIsWeb) return;
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

  // Set up global error handlers in release builds.
  // Use Crashlytics when Firebase is available, fallback to debugPrint otherwise.
  if (kReleaseMode) {
    if (r.firebaseInitialized && !kIsWeb) {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    } else {
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('[FatalError] ${details.exceptionAsString()}');
        debugPrint('[FatalError] ${details.stack}');
      };
    }
  }

  final pushBinding = PushLifecycleBinding();
  final appUpdateBinding = AppUpdateLifecycleBinding();
  final gatewayPaymentBinding = GatewayPaymentLifecycleBinding();
  WidgetsBinding.instance.addObserver(pushBinding);
  WidgetsBinding.instance.addObserver(appUpdateBinding);
  WidgetsBinding.instance.addObserver(gatewayPaymentBinding);

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

  // In release builds, catch uncaught async errors.
  if (kReleaseMode) {
    runZonedGuarded(
      startApp,
      (error, stack) {
        if (r.firebaseInitialized && !kIsWeb) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        } else {
          debugPrint('[UncaughtError] $error');
          debugPrint('[UncaughtError] $stack');
        }
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
      _registerResidentDataRefresh();
      _registerGuardDataRefresh();
      _checkAppVersion();
    });
  }

  Future<void> _checkAppVersion() async {
    // Resume a stalled Play immediate update before prompting again.
    if (platform_info.isAndroid) {
      final resumed = await AppVersionService.resumeInterruptedImmediateUpdate();
      if (resumed == AppUpdateResult.success || !mounted) return;
    }

    final result = await AppVersionService.check();
    if (!mounted) return;
    switch (result.status) {
      case UpdateStatus.forceUpdate:
        unawaited(showAppUpdateDialog(context, result, forceUpdate: true));
      case UpdateStatus.softUpdate:
        final dismissed = result.latestVersion != null &&
            await wasSoftUpdateDismissed(result.latestVersion!);
        if (!dismissed && mounted) {
          unawaited(showAppUpdateDialog(context, result, forceUpdate: false));
        }
      case UpdateStatus.upToDate:
        break;
    }
  }

  void _registerResidentDataRefresh() {
    onResidentDataRefreshRequested = () {
      unawaited(ref.read(authProvider.notifier).refreshProfile());
      ref.invalidate(pendingMaintenanceProvider);
      ref.invalidate(outstandingDuesProvider);
      ref.invalidate(maintenanceHistoryProvider);
      ref.invalidate(residentBillingCycleProvider);
      ref.invalidate(billingFinancialYearsProvider);
      ref.invalidate(residentDashboardProvider);
      ref.invalidate(noticesProvider);
      ref.invalidate(pollsProvider);
      ref.invalidate(eventsProvider);
      ref.invalidate(documentsProvider);
      ref.invalidate(notificationProvider);
      ref.invalidate(myComplaintsProvider);
      ref.invalidate(activeBannersProvider);
      ref.read(residentSpecialProjectsProvider.notifier).fetchProjects();
      ref.invalidate(visitorApprovalRequestsProvider('pending'));
      ref.invalidate(visitorApprovalRequestsProvider('all'));
      ref.read(parcelProvider.notifier).fetchParcels();
    };
  }

  void _registerGuardDataRefresh() {
    onGuardDataRefreshRequested = () {
      ref.invalidate(guardMyGateProvider);
      ref.invalidate(guardVillasProvider);
      ref.invalidate(guardResidentsDirectoryProvider);
      ref.invalidate(guardMyPatrolsProvider);
      ref.invalidate(guardMyShiftsProvider);
      ref.invalidate(guardActiveVisitorsTabProvider);
      ref.invalidate(guardPendingVisitorsProvider);
      ref.invalidate(guardDashboardProvider);
      ref.invalidate(guardPreApprovedEntriesProvider);
    };
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
      if (wasAuth && !nowAuth) {
        ref.read(gp_theme.themeTokensProvider.notifier).reset();
        ref.invalidate(gp_theme.applyRemoteThemeProvider);
      } else if (!wasAuth && nowAuth) {
        ref.invalidate(gp_theme.applyRemoteThemeProvider);
      }
    });

    final tokens = ref.watch(gp_theme.themeTokensProvider);

    // Fetch the society's theme + splash on boot and whenever auth changes.
    // Resolves the society id from storage (logged-in or last-selected), so it
    // applies even before login. No-ops when no society is known yet.
    ref.watch(authProvider);
    ref.watch(gp_theme.applyRemoteThemeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: gp_theme.AppTheme.light(palette: tokens.light),
      darkTheme: gp_theme.AppTheme.dark(palette: tokens.dark),
      // Locked to light: ~134 screens still resolve colors via the light-only
      // AppColorBridge (DesignColors/AppColors), so dark mode renders unreadable
      // (dark text on dark bg). Re-enable only after those are migrated off the
      // static bridge to brightness-aware tokens.
      themeMode: ThemeMode.light,
      routerConfig: _router!,
      builder: (context, child) {
        final scaled = _buildFixedScale(context, child);
        final withBanner = OfflineBanner(child: scaled);
        Widget result = kIsWeb ? SelectionArea(child: withBanner) : withBanner;

        // On wide web viewports, cap content at 900dp centered.
        if (kIsWeb && MediaQuery.sizeOf(context).width > 900) {
          result = ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: result,
              ),
            ),
          );
        }

        return result;
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

    // On web, browsers handle viewport sizing natively — skip all
    // FittedBox / SizedBox scaling. Only keep textScaler clamping.
    if (kIsWeb) {
      return MediaQuery(
        data: fixedData,
        child: child!,
      );
    }

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
