import '../models/user_model.dart';
import '../../core/constants/app_constants.dart';

/// Residents and society admins with a linked villa use the same billing/home APIs.
bool userCanViewResidentBilling(UserModel? user) {
  if (user == null) return false;
  if (user.role != UserRole.resident && user.role != UserRole.admin) {
    return false;
  }
  final villa = user.villaId;
  return villa != null && villa.isNotEmpty;
}

/// Profile header shows villa/unit/occupant lines (not just role + society name).
bool userShowsResidentPropertyProfile(UserModel? user) =>
    userCanViewResidentBilling(user);
