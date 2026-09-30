import '../../../core/constants/app_constants.dart';

/// Maps mobile picker values to Prisma `VisitorType` used by guard check-in API.
///
/// Labels are derived from the canonical [VisitorType] to stay consistent
/// across resident and guard screens.
/// Declaration order is the picker order: deliveries are the most common walk-in.
enum GuardCheckInVisitorType {
  delivery('DELIVERY'),
  guest('GUEST'),
  cab('CAB'),
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
      case cab:
        return VisitorType.cab.label;
      case serviceProvider:
        return VisitorType.service.label;
      case vendor:
        return VisitorType.vendor.label;
    }
  }

  /// One-word label that fits five tiles in a row.
  String get shortLabel {
    switch (this) {
      case delivery:
        return 'Delivery';
      case guest:
        return 'Guest';
      case cab:
        return 'Cab';
      case serviceProvider:
        return 'Service';
      case vendor:
        return 'Vendor';
    }
  }
}
