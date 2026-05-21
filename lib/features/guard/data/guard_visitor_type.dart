import '../../../core/constants/app_constants.dart';

/// Maps mobile picker values to Prisma `VisitorType` used by guard check-in API.
///
/// Labels are derived from the canonical [VisitorType] to stay consistent
/// across resident and guard screens.
enum GuardCheckInVisitorType {
  guest('GUEST'),
  delivery('DELIVERY'),
  serviceProvider('SERVICE_PROVIDER'),
  vendor('VENDOR');

  final String apiValue;
  const GuardCheckInVisitorType(this.apiValue);

  /// Human-readable label pulled from the canonical [VisitorType] enum.
  String get label {
    switch (this) {
      case guest:
        return VisitorType.guest.label;
      case delivery:
        return VisitorType.delivery.label;
      case serviceProvider:
        return VisitorType.service.label;
      case vendor:
        return VisitorType.vendor.label;
    }
  }
}
