import 'package:flutter_test/flutter_test.dart';

import 'package:divine_app/features/guard/data/models/guard_models.dart';

GuardVisitorRow _visitor({
  required String id,
  required String status,
  DateTime? checkOutTime,
}) {
  return GuardVisitorRow(
    id: id,
    name: 'Visitor $id',
    phone: '9999999999',
    status: status,
    checkOutTime: checkOutTime,
  );
}

void main() {
  group('GuardLiveQueueCounts.fromActiveTab', () {
    test('counts on-premises, awaiting resident, ready to admit, and pre-approved', () {
      final data = GuardActiveVisitorsTabData(
        pendingVisitors: [
          _visitor(id: '1', status: 'CHECKED_IN'),
          _visitor(id: '2', status: 'CHECKED_IN'),
          _visitor(id: '3', status: 'PENDING_APPROVAL'),
          _visitor(id: '4', status: 'APPROVED'),
          _visitor(id: '5', status: 'APPROVED'),
          _visitor(id: '6', status: 'APPROVED'),
          _visitor(id: '7', status: 'DENIED'),
          _visitor(
            id: '8',
            status: 'CHECKED_IN',
            checkOutTime: DateTime(2026, 1, 1),
          ),
        ],
        preApproved: List.generate(
          4,
          (i) => GuardPreApprovedEntry(
            id: 'p$i',
            name: 'Guest $i',
            phone: '888888888$i',
            villaId: 'v$i',
            villaNumber: 'A-$i',
          ),
        ),
      );

      final counts = GuardLiveQueueCounts.fromActiveTab(data);

      expect(counts.onPremises, 2);
      expect(counts.awaitingResident, 1);
      expect(counts.readyToAdmit, 3);
      expect(counts.preApproved, 4);
      expect(counts.needsGuardAction, 7); // 3 admit + 4 pre-approved
      expect(counts.activeTabBadgeCount, 7);
    });

    test('badge falls back to awaiting-resident when nothing needs admit', () {
      final data = GuardActiveVisitorsTabData(
        pendingVisitors: [
          _visitor(id: '1', status: 'PENDING_APPROVAL'),
          _visitor(id: '2', status: 'PENDING_APPROVAL'),
          _visitor(id: '3', status: 'CHECKED_IN'),
        ],
        preApproved: const [],
      );

      final counts = GuardLiveQueueCounts.fromActiveTab(data);

      expect(counts.needsGuardAction, 0);
      expect(counts.awaitingResident, 2);
      expect(counts.onPremises, 1);
      expect(counts.activeTabBadgeCount, 2);
    });

    test('badge is zero when queue is empty', () {
      final data = GuardActiveVisitorsTabData(
        pendingVisitors: const [],
        preApproved: const [],
      );

      final counts = GuardLiveQueueCounts.fromActiveTab(data);

      expect(counts.activeTabBadgeCount, 0);
      expect(
        counts.dashboardSubtitle(),
        'On-site guests, approvals, pre-approved & exits',
      );
    });

    test('dashboard subtitle lists actionable and on-site counts', () {
      const counts = GuardLiveQueueCounts(
        onPremises: 3,
        awaitingResident: 1,
        readyToAdmit: 2,
        preApproved: 0,
      );

      expect(
        counts.dashboardSubtitle(),
        '2 need admit · 3 inside · 1 awaiting resident',
      );
    });

    test('singular grammar for one admit action', () {
      const counts = GuardLiveQueueCounts(
        onPremises: 0,
        awaitingResident: 0,
        readyToAdmit: 1,
        preApproved: 0,
      );

      expect(counts.dashboardSubtitle(), '1 needs admit');
      expect(counts.activeTabBadgeCount, 1);
    });
  });

  group('GuardVisitorRow status helpers used by counts', () {
    test('CHECKED_IN without checkout is on premises', () {
      final v = _visitor(id: '1', status: 'CHECKED_IN');
      expect(v.awaitingCheckout, isTrue);
      expect(v.awaitingGuardAdmission, isFalse);
      expect(v.needsResidentApproval, isFalse);
    });

    test('APPROVED is ready for guard admission', () {
      final v = _visitor(id: '1', status: 'APPROVED');
      expect(v.awaitingGuardAdmission, isTrue);
      expect(v.needsResidentApproval, isFalse);
    });

    test('PENDING_APPROVAL awaits resident', () {
      final v = _visitor(id: '1', status: 'PENDING_APPROVAL');
      expect(v.needsResidentApproval, isTrue);
      expect(v.awaitingGuardAdmission, isFalse);
    });
  });
}
