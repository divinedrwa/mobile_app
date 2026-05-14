import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:divine_app/core/utils/storage_service.dart';
import 'package:divine_app/features/auth/presentation/pages/branded_splash_screen.dart';
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
      // Use phone-sized surface — splash is designed for mobile, not 800x600 desktop default.
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: DivineApp(),
        ),
      );
      await tester.pump();

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(BrandedSplashScreen), findsOneWidget);

      // Drain pending splash timers (animation + post-hold navigation) before tearDown.
      await tester.pumpAndSettle(const Duration(seconds: 5));
    },
  );
}
