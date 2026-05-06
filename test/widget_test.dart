import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:divine_app/core/utils/storage_service.dart';
import 'package:divine_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  testWidgets(
    'App shows splash title and MaterialApp after boot',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: DivineApp(),
        ),
      );
      await tester.pump();
      expect(find.text('My Society'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(MaterialApp), findsOneWidget);
    },
  );
}
