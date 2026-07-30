import 'package:flutter_test/flutter_test.dart';

import 'package:divine_app/core/constants/app_constants.dart';
import 'package:divine_app/features/resident/data/models/pre_approved_visitor_model.dart';
import 'package:divine_app/features/resident/data/pre_approved_visitor_eligibility.dart';

PreApprovedVisitorModel _visitor({
  bool isUsed = false,
  bool isFrequent = false,
  int usedCount = 0,
  int? maxUses,
  DateTime? passcodeExpiry,
}) {
  return PreApprovedVisitorModel(
    name: 'Mohit',
    phone: '9876543210',
    type: VisitorType.guest,
    visitDate: DateTime(2026, 7, 31),
    passcode: '851606',
    passcodeExpiry: passcodeExpiry ?? DateTime(2026, 7, 31, 23, 59),
    isFrequent: isFrequent,
    isUsed: isUsed,
    usedCount: usedCount,
    maxUses: maxUses,
  );
}

void main() {
  final now = DateTime(2026, 7, 30, 12);

  test('upcoming pass hides after one-time use', () {
    expect(isPreApprovalUpcoming(_visitor(), now: now), isTrue);
    expect(
      isPreApprovalUpcoming(_visitor(isUsed: true), now: now),
      isFalse,
    );
  });

  test('expired pass is not upcoming', () {
    expect(
      isPreApprovalUpcoming(
        _visitor(passcodeExpiry: DateTime(2026, 7, 29, 23, 59)),
        now: now,
      ),
      isFalse,
    );
  });

  test('recurring pass stays upcoming until max uses', () {
    final recurring = _visitor(
      isFrequent: true,
      maxUses: 3,
      usedCount: 2,
    );
    expect(isPreApprovalUpcoming(recurring, now: now), isTrue);
    expect(
      isPreApprovalUpcoming(
        _visitor(isFrequent: true, maxUses: 3, usedCount: 3),
        now: now,
      ),
      isFalse,
    );
  });

  test('model parses isUsed from API json', () {
    final model = PreApprovedVisitorModel.fromJson({
      'name': 'A',
      'phone': '9999999999',
      'visitorType': 'GUEST',
      'validUntil': '2026-07-31T18:29:00.000Z',
      'isUsed': true,
      'usedCount': 1,
    });
    expect(model.isUsed, isTrue);
    expect(model.usedCount, 1);
    expect(model.isFrequent, isFalse);
    expect(AppConstants.appName, isNotEmpty);
  });
}
