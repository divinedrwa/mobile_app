import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants/app_constants.dart';
import '../core/logging/fcm_log.dart';
import '../core/network/dio_client.dart';
import '../core/services/notification_service.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/storage_service.dart';
import '../firebase_options.dart';
import 'firebase_background.dart' as fb;

/// Result of one-time native/storage initialization before [runApp].
class DivineBootstrapResult {
  DivineBootstrapResult({required this.firebaseInitialized});

  final bool firebaseInitialized;
}

/// Shared by [main] and integration tests so the same init path is exercised.
Future<DivineBootstrapResult> bootstrapDivineBeforeRunApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseInitialized = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseInitialized = true;
    debugPrint('✅ Firebase initialized successfully');
    fcmDiag(
      'MAIN',
      'Firebase.initializeApp OK projectId=${Firebase.app().options.projectId}',
    );

    FirebaseMessaging.onBackgroundMessage(fb.firebaseMessagingBackgroundEntry);
    fcmDiag('MAIN', 'FirebaseMessaging.onBackgroundMessage registered');
  } catch (e) {
    debugPrint('⚠️  Firebase not configured (app will work without push notifications)');
    debugPrint('   Error details: $e');
    fcmDiag(
      'MAIN_FAIL',
      'Firebase.initializeApp FAILED — pushes disabled until fixed. err=$e',
    );
  }

  await Hive.initFlutter();

  await StorageService.init();
  AppConstants.setRuntimeBaseUrlOverride(
    StorageService.getString(AppConstants.keyApiBaseUrl),
  );

  if (Platform.isAndroid) {
    try {
      final android = await DeviceInfoPlugin().androidInfo;
      AppConstants.setAndroidEmulatorResolved(!android.isPhysicalDevice);
    } catch (e) {
      debugPrint('⚠️  Could not detect Android emulator vs device: $e');
    }
    DioClient.reset();
  }
  if (Platform.isIOS) {
    try {
      final ios = await DeviceInfoPlugin().iosInfo;
      AppConstants.setIosSimulatorResolved(!ios.isPhysicalDevice);
    } catch (e) {
      debugPrint('⚠️  Could not detect iOS simulator vs device: $e');
    }
    DioClient.reset();
  }
  debugPrint('🌐 API base URL: ${AppConstants.baseUrl}');

  if (firebaseInitialized) {
    try {
      await NotificationService().initialize();
      debugPrint('✅ Notification service initialized');
    } catch (e, st) {
      debugPrint('⚠️  Notification service failed to initialize: $e');
      fcmDiag('MAIN', 'NotificationService.initialize crashed', e, st);
    }
  } else {
    debugPrint('ℹ️  Notification service skipped (Firebase not available)');
    fcmDiag('MAIN', 'NotificationService skipped (Firebase unavailable)');
  }

  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUiOverlayStyleLight);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  return DivineBootstrapResult(firebaseInitialized: firebaseInitialized);
}
