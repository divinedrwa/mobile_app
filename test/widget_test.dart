import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:divine_app/core/utils/storage_service.dart';
import 'package:divine_app/features/auth/presentation/pages/splash_screen.dart';
import 'package:divine_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  testWidgets(
    'App shows splash screen and MaterialApp after boot',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: DivineApp(),
        ),
      );
      await tester.pump();

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(2));

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
    },
  );
}
