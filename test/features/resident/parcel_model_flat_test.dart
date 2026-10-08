import 'package:flutter_test/flutter_test.dart';

import 'package:divine_app/features/resident/data/models/parcel_model.dart';

void main() {
  test('reads the flat and floor a parcel was logged for', () {
    final p = ParcelModel.fromJson({
      'id': 'p1',
      'trackingNumber': 'T1',
      'deliveryService': 'Amazon',
      'status': 'PENDING',
      'flatLabel': 'A-12',
      'unitLabel': 'Ground floor',
    });
    expect(p.flatLabel, 'A-12');
    expect(p.unitLabel, 'Ground floor');
    expect(p.toJson()['flatLabel'], 'A-12');
  });

  test('older responses without a flat still parse', () {
    final p = ParcelModel.fromJson({'id': 'p2', 'status': 'PENDING'});
    expect(p.flatLabel, isNull);
    expect(p.unitLabel, isNull);
  });
}
