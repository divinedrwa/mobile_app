import 'package:flutter_test/flutter_test.dart';

import 'package:divine_app/core/constants/app_constants.dart';
import 'package:divine_app/core/services/push_display_text.dart';

final _zeroWidth = String.fromCharCode(0x200B);
final _noBreakSpace = String.fromCharCode(0x00A0);
final _bom = String.fromCharCode(0xFEFF);

void main() {
  group('cleanPushText', () {
    test('keeps ordinary text and tidies spaces', () {
      expect(cleanPushText('  Visitor   admitted '), 'Visitor admitted');
    });

    test('text with nothing visible is empty', () {
      for (final blank in <String?>[null, '', '   ', '\n\t', _noBreakSpace, _zeroWidth, '$_bom$_zeroWidth $_noBreakSpace']) {
        expect(cleanPushText(blank), '', reason: 'blank: ${blank?.codeUnits}');
      }
    });

    test('invisible characters inside real text are removed; real text is untouched', () {
      expect(cleanPushText('Gate$_zeroWidth pass'), 'Gate pass');
      expect(cleanPushText('आगंतुक को अनुमति मिली'), 'आगंतुक को अनुमति मिली');
      expect(cleanPushText('Rs. 1,200 due ✅'), 'Rs. 1,200 due ✅');
    });
  });

  group('resolvePushDisplayText', () {
    test('uses the notification text as given', () {
      final r = resolvePushDisplayText(notificationTitle: 'Visitor admitted', notificationBody: "Ravi's entry was approved.");
      expect(r, (title: 'Visitor admitted', body: "Ravi's entry was approved."));
    });

    test('falls back to the text repeated in the data block', () {
      final r = resolvePushDisplayText(dataTitle: 'Parcel at gate', dataBody: 'A parcel is waiting.');
      expect(r, (title: 'Parcel at gate', body: 'A parcel is waiting.'));
    });

    test('a push with no words is not shown (it used to become "Notification" / "Notification")', () {
      expect(resolvePushDisplayText(), isNull);
      expect(resolvePushDisplayText(notificationTitle: '', notificationBody: ''), isNull);
      expect(resolvePushDisplayText(notificationTitle: _zeroWidth, notificationBody: _noBreakSpace, dataTitle: '  ', dataBody: ''), isNull);
    });

    test('only a title: the body repeats it; only a body: the title is the app name', () {
      expect(resolvePushDisplayText(notificationTitle: 'Parcel at gate', notificationBody: _zeroWidth),
          (title: 'Parcel at gate', body: 'Parcel at gate'));
      expect(resolvePushDisplayText(notificationTitle: '', notificationBody: 'Your water request was fulfilled.'),
          (title: AppConstants.appName, body: 'Your water request was fulfilled.'));
    });

    test('never returns the placeholder word on its own', () {
      final r = resolvePushDisplayText(notificationBody: 'Hello');
      expect(r!.title, isNot('Notification'));
    });
  });
}
