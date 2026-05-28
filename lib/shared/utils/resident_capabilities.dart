import '../models/user_model.dart';

/// Residents and society admins with a linked villa use the same billing/home APIs.
bool userCanViewResidentBilling(UserModel? user) {
  if (user == null) return false;
  if (!user.role.isResidentLike) {
    return false;
  }
  final villa = user.villaId;
  return villa != null && villa.isNotEmpty;
}

/// Profile header shows villa/unit/occupant lines (not just role + society name).
bool userShowsResidentPropertyProfile(UserModel? user) =>
    userCanViewResidentBilling(user);
