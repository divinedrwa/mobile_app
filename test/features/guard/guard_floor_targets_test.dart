import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:divine_app/features/guard/data/models/guard_models.dart';
import 'package:divine_app/features/guard/presentation/providers/guard_command_providers.dart';
import 'package:divine_app/features/guard/presentation/widgets/guard_flat_picker.dart';

ResidentPickerItem _resident(
  String id, {
  required String villaId,
  required String villaNumber,
  String? unitId,
  String? unitLabel,
  String? type,
  String? block = 'A',
}) {
  return ResidentPickerItem(
    userId: id,
    name: 'Person $id',
    villaId: villaId,
    villaNumber: villaNumber,
    block: block,
    unitId: unitId,
    unitLabel: unitLabel,
    residentType: type,
  );
}

// A-12: tenant on the ground floor, owner on the first floor. A-03: one owner, ground floor.
final _residents = [
  _resident('tenant12', villaId: 'v12', villaNumber: '12', unitId: 'u12gf', unitLabel: 'Ground floor', type: 'TENANT'),
  _resident('owner12', villaId: 'v12', villaNumber: '12', unitId: 'u12ff', unitLabel: 'First floor', type: 'OWNER'),
  _resident('owner03', villaId: 'v03', villaNumber: '03', unitId: 'u03gf', unitLabel: 'Ground floor', type: 'OWNER'),
];

void main() {
  group('shortFloorLabel', () {
    test('shortens the floor names used in the society', () {
      expect(shortFloorLabel('Ground floor'), 'GF');
      expect(shortFloorLabel('First floor'), 'FF');
      expect(shortFloorLabel('Second floor'), 'SF');
      expect(shortFloorLabel('Third floor'), 'TF');
      expect(shortFloorLabel('GF'), 'GF');
    });

    test('leaves unknown names alone and handles empty', () {
      expect(shortFloorLabel('Terrace'), 'Terrace');
      expect(shortFloorLabel(null), '');
      expect(shortFloorLabel('  '), '');
    });

    test('orders floors lowest first', () {
      final shorts = ['SF', 'GF', 'Terrace', 'FF']..sort((a, b) => floorRank(a).compareTo(floorRank(b)));
      expect(shorts, ['GF', 'FF', 'SF', 'Terrace']);
    });
  });

  group('visitTargetsForSelection', () {
    test('targets each selected floor, so a tenant and an owner on different floors are both asked', () {
      final t = visitTargetsForSelection(_residents, {'tenant12', 'owner12'});
      expect(t.map((x) => x.toJson()).toList(), [
        {'villaId': 'v12', 'unitId': 'u12gf'},
        {'villaId': 'v12', 'unitId': 'u12ff'},
      ]);
    });

    test('a single floor selected targets only that floor', () {
      final t = visitTargetsForSelection(_residents, {'owner12'});
      expect(t.map((x) => x.toJson()).toList(), [
        {'villaId': 'v12', 'unitId': 'u12ff'},
      ]);
    });

    test('two people on the same floor make one target', () {
      final residents = [
        ..._residents,
        _resident('family12', villaId: 'v12', villaNumber: '12', unitId: 'u12ff', unitLabel: 'First floor', type: 'FAMILY_MEMBER'),
      ];
      final t = visitTargetsForSelection(residents, {'owner12', 'family12'});
      expect(t.length, 1);
      expect(t.single.unitId, 'u12ff');
    });

    test('a resident with no floor is targeted by person', () {
      final residents = [
        ..._residents,
        _resident('nofloor12', villaId: 'v12', villaNumber: '12'),
      ];
      final t = visitTargetsForSelection(residents, {'nofloor12'});
      expect(t.single.toJson(), {'villaId': 'v12', 'residentUserId': 'nofloor12'});
    });

    test('ignores residents that are not selected', () {
      expect(visitTargetsForSelection(_residents, <String>{}), isEmpty);
    });
  });

  group('GuardVisitorRow with a visit sent to two floors of one flat', () {
    Map<String, dynamic> entry(String status) => {
          'approvalStatus': status,
          'villa': {
            'villaNumber': '12',
            'block': 'A',
            'users': [
              {'name': 'Tenant', 'phone': '9000000001'},
              {'name': 'Owner', 'phone': '9000000002'},
            ],
          },
        };

    GuardVisitorRow row(List<String> statuses) => GuardVisitorRow.fromJson({
          'id': 'v1',
          'name': 'Courier',
          'phone': '9111111111',
          'status': 'PENDING_APPROVAL',
          'villaVisits': [for (final s in statuses) entry(s)],
        });

    test('lists the flat and each resident to call once', () {
      final r = row(['PENDING', 'PENDING']);
      expect(r.villaLabel, '12');
      expect(r.residentContacts.length, 2);
    });

    test('is one flat, not a multi-flat visit with a split decision', () {
      final r = row(['PENDING', 'APPROVED']);
      expect(r.villaApprovals.length, 1);
      expect(r.isMultiVilla, isFalse);
      expect(r.hasSplitFlatDecision, isFalse);
      expect(r.villaApprovals.single.approved, isTrue, reason: 'approved beats pending');
    });

    test('declined on one floor and pending on the other stays pending', () {
      final r = row(['REJECTED', 'PENDING']);
      expect(r.villaApprovals.single.pending, isTrue);
    });
  });

  group('GuardFlatPicker', () {
    Future<void> pump(WidgetTester tester, {required bool split}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GuardFlatPicker(
                residents: _residents,
                selectedUserIds: const {},
                splitByFloor: split,
                onToggleFlat: (_) {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('lists a tile per occupied floor of a multi-floor flat, with who lives there', (tester) async {
      await pump(tester, split: true);
      expect(find.text('A-03'), findsOneWidget);
      expect(find.text('A-12 · GF'), findsOneWidget);
      expect(find.text('A-12 · FF'), findsOneWidget);
      expect(find.text('Tenant'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('A-12'), findsNothing);
      final gf = tester.getTopLeft(find.text('A-12 · GF'));
      final ff = tester.getTopLeft(find.text('A-12 · FF'));
      expect(gf.dx < ff.dx || gf.dy < ff.dy, isTrue, reason: 'ground floor comes before first floor');
    });

    testWidgets('without splitByFloor a flat stays one tile (other screens unchanged)', (tester) async {
      await pump(tester, split: false);
      expect(find.text('A-12'), findsOneWidget);
      expect(find.text('A-03'), findsOneWidget);
      expect(find.text('A-12 · GF'), findsNothing);
    });

    testWidgets('tapping a floor selects only that floor\'s residents', (tester) async {
      GuardFlatSelection? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GuardFlatPicker(
                residents: _residents,
                selectedUserIds: const {},
                splitByFloor: true,
                onToggleFlat: (f) => tapped = f,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('A-12 · FF'));
      expect(tapped?.userIds, ['owner12']);
      expect(tapped?.villaId, 'v12');
    });
  });
}
