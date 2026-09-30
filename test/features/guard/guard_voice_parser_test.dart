import 'package:flutter_test/flutter_test.dart';
import 'package:divine_app/features/guard/data/guard_visitor_type.dart';
import 'package:divine_app/features/guard/voice/guard_voice_parser.dart';

void main() {
  const flats = ['A-03', 'A-25', 'A-26', 'B-43'];

  group('parseVisitorUtterance', () {
    test('name, spoken phone, flat and category in one sentence', () {
      final p = parseVisitorUtterance(
        'Ramesh Kumar nine eight seven six five four three two one zero flat A twenty five delivery',
        knownFlatLabels: flats,
      );
      expect(p.name, 'Ramesh Kumar');
      expect(p.phone, '9876543210');
      expect(p.flatLabels, ['A-25']);
      expect(p.visitorType, GuardCheckInVisitorType.delivery);
    });

    test('digits as recognized by the phone, glued block+number', () {
      final p = parseVisitorUtterance(
        'Suresh 98765 43210 for A25 amazon',
        knownFlatLabels: flats,
      );
      expect(p.name, 'Suresh');
      expect(p.phone, '9876543210');
      expect(p.flatLabels, ['A-25']);
      expect(p.visitorType, GuardCheckInVisitorType.delivery);
    });

    test('double/triple digits and +91 prefix', () {
      final p = parseVisitorUtterance('nine one nine eight double seven triple six five four three');
      expect(p.phone, '9877666543');
    });

    test('several flats and a leading-zero flat', () {
      final p = parseVisitorUtterance('A 25 and A 26 and A 3 swiggy', knownFlatLabels: flats);
      expect(p.flatLabels, ['A-25', 'A-26', 'A-03']);
      expect(p.visitorType, GuardCheckInVisitorType.delivery);
    });

    test('name after "name is" and a cab', () {
      final p = parseVisitorUtterance('driver name is Mohan Lal uber B 43', knownFlatLabels: flats);
      expect(p.name, 'Mohan Lal');
      expect(p.visitorType, GuardCheckInVisitorType.cab);
      expect(p.flatLabels, ['B-43']);
    });

    test('vehicle number spoken letter by letter', () {
      final p = parseVisitorUtterance('guest Anil vehicle M H one two A B one two three four');
      expect(p.vehicleNumber, 'MH12AB1234');
      expect(p.name, 'Anil');
    });

    test('unknown flat is not selected', () {
      final p = parseVisitorUtterance('Ravi flat C 99', knownFlatLabels: flats);
      expect(p.flatLabels, isEmpty);
      expect(p.name, 'Ravi');
    });
  });

  test('digitsFromSpeech', () {
    expect(digitsFromSpeech('nine eight double seven 6 5'), '987765');
  });

  test('vehicleFromText handles OCR-style text', () {
    expect(vehicleFromText('KA 01 AB 1234'), 'KA01AB1234');
    expect(vehicleFromText('22 BH 1234 AA'), '22BH1234AA');
    expect(vehicleFromText('hello'), isNull);
  });
}
