/// Maps mobile picker values to Prisma `VisitorType` used by guard check-in API.
enum GuardCheckInVisitorType {
  guest('GUEST'),
  delivery('DELIVERY'),
  serviceProvider('SERVICE_PROVIDER'),
  vendor('VENDOR');

  final String apiValue;
  const GuardCheckInVisitorType(this.apiValue);
}
