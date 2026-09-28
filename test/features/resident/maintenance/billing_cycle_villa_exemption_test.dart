import 'package:divine_app/features/resident/data/models/billing_cycle_current_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  group('BillingCycleCurrent villa exemption', () {
    test('paying villa (field absent) is not exempt', () {
      final c = BillingCycleCurrent.fromJson({'remainingDue': 0, 'pendingDues': []});
      expect(c.villaMaintenanceExemptFrom, isNull);
      expect(c.villaNotPaying, isFalse);
      expect(c.villaFullyExempt, isFalse);
    });

    test('non-paying villa with nothing left to pay is fully exempt', () {
      final c = BillingCycleCurrent.fromJson({
        'villaMaintenanceExemptFrom': '2020-01',
        'remainingDue': 0,
        'pendingDues': [],
      });
      expect(c.villaNotPaying, isTrue);
      expect(c.villaFullyExempt, isTrue);
      expect(c.villaExemptionUpcoming, isFalse);
    });

    test('non-paying villa with old dues is not fully exempt', () {
      final c = BillingCycleCurrent.fromJson({
        'villaMaintenanceExemptFrom': '2020-01',
        'remainingDue': 0,
        'pendingDues': [
          {'cycleId': 'c1', 'cycleKey': '2019-12', 'title': 'Dec', 'amount': 1500},
        ],
      });
      expect(c.villaNotPaying, isTrue);
      expect(c.villaFullyExempt, isFalse);
    });

    test('exemption starting next month is upcoming', () {
      final now = DateTime.now();
      final next = DateTime(now.year, now.month + 1);
      final c = BillingCycleCurrent.fromJson({'villaMaintenanceExemptFrom': monthKey(next)});
      expect(c.villaExemptionUpcoming, isTrue);
    });

    test('copyWith keeps the exemption', () {
      final c = BillingCycleCurrent.fromJson({'villaMaintenanceExemptFrom': '2026-10'});
      expect(c.copyWith(isPaid: true).villaMaintenanceExemptFrom, '2026-10');
    });
  });
}
