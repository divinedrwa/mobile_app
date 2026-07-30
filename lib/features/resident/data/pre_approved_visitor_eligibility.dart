import 'models/pre_approved_visitor_model.dart';

/// Mirrors backend `isPreApprovalGateEligible` — pass can still admit at gate.
bool isPreApprovalGateEligible(
  PreApprovedVisitorModel visitor, {
  DateTime? now,
}) {
  final at = (now ?? DateTime.now()).toLocal();
  if (!visitor.isActive) return false;

  final validFrom = visitor.validFrom?.toLocal();
  if (validFrom != null && validFrom.isAfter(at)) return false;

  final validUntil = visitor.passcodeExpiry?.toLocal();
  if (validUntil != null && !validUntil.isAfter(at)) return false;

  if (visitor.isFrequent) {
    final max = visitor.maxUses;
    if (max != null && visitor.usedCount >= max) return false;
    return true;
  }

  return !visitor.isUsed;
}

/// Shown in hub "Upcoming Visitors" and Active tab — not yet consumed at gate.
bool isPreApprovalUpcoming(PreApprovedVisitorModel visitor, {DateTime? now}) {
  return isPreApprovalGateEligible(visitor, now: now);
}
