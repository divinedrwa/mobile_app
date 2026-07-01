/// Global hooks so push notifications and app resume can refresh resident UI
/// without holding a [WidgetRef] (registered from [DivineApp] in main.dart).
void Function()? onResidentDataRefreshRequested;

/// Minimum gap between full resident-data refreshes. This callback invalidates
/// ~14 providers at once (a thundering herd against a possibly-cold backend),
/// and it's triggered on every Home-tab tap and app resume — so without a guard
/// the freshly-cached data is thrown away and every Home visit shows skeletons.
const _minRefreshGap = Duration(seconds: 30);
DateTime? _lastResidentRefresh;

/// Refresh maintenance, billing, dashboard, and related resident providers.
///
/// Debounced: repeated calls within [_minRefreshGap] are ignored unless [force]
/// is set. Push handlers that need data immediately (e.g. a new visitor request)
/// should pass `force: true`.
void requestResidentDataRefresh({bool force = false}) {
  final now = DateTime.now();
  if (!force &&
      _lastResidentRefresh != null &&
      now.difference(_lastResidentRefresh!) < _minRefreshGap) {
    return;
  }
  _lastResidentRefresh = now;
  onResidentDataRefreshRequested?.call();
}

/// @deprecated Use [requestResidentDataRefresh]
void requestMaintenanceDataRefresh() => requestResidentDataRefresh();
