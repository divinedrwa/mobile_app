import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/providers/guard_providers.dart';

/// Global hook for guard push / resume refresh (registered from [DivineApp]).
void Function()? onGuardDataRefreshRequested;

/// Refreshes active shift, gate assignment, and roster (no re-login required).
void refreshGuardShiftContext(WidgetRef ref) {
  ref.invalidate(guardMyGateProvider);
  ref.invalidate(guardMyShiftsProvider);
  ref.invalidate(guardDashboardProvider);
}

void requestGuardDataRefresh() {
  onGuardDataRefreshRequested?.call();
}
