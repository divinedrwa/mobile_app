/// Global hooks so push notifications and app resume can refresh resident UI
/// without holding a [WidgetRef] (registered from [DivineApp] in main.dart).
void Function()? onResidentDataRefreshRequested;

/// Refresh maintenance, billing, dashboard, and related resident providers.
void requestResidentDataRefresh() {
  onResidentDataRefreshRequested?.call();
}

/// @deprecated Use [requestResidentDataRefresh]
void requestMaintenanceDataRefresh() => requestResidentDataRefresh();
