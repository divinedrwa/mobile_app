import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:divine_app/core/constants/app_constants.dart';
import 'package:divine_app/features/resident/data/models/pre_approved_visitor_model.dart';
import 'package:divine_app/features/resident/data/visitor_pass_share.dart';

void main() {
  test('buildVisitorPassShareMessage includes link and passcode', () {
    final visitor = PreApprovedVisitorModel(
      name: 'Mohit',
      phone: '9876543210',
      type: VisitorType.guest,
      visitDate: DateTime(2026, 7, 31),
      passcode: '851606',
      publicPassUrl:
          'https://admin-frontend-kappa-beige.vercel.app/visit/test-token',
      passcodeExpiry: DateTime(2026, 7, 31, 10, 48),
    );

    final message = buildVisitorPassShareMessage(visitor);
    expect(message, contains('Visitor Pass for Mohit'));
    expect(message, contains('Open visitor pass:'));
    expect(message, contains('vercel.app/visit/test-token'));
    expect(message, contains('Passcode: 851606'));
    expect(
      message,
      contains(
        DateFormat('dd MMM yyyy').format(visitor.visitDate),
      ),
    );
    expect(message, contains(AppConstants.appName));
  });
}
