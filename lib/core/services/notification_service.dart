import 'dart:async';
import 'dart:convert';
import '../utils/platform_info.dart' as platform_info;
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter/scheduler.dart' hide Priority;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../features/guard/data/guard_data_refresh.dart';
import '../../features/resident/data/resident_data_refresh.dart';
import '../constants/app_constants.dart';
import '../logging/fcm_log.dart';
import '../routing/app_navigator_keys.dart';
import '../utils/notification_preference_storage.dart';
import '../utils/storage_service.dart';
import 'push_sync_service.dart';
import 'web_notification.dart' as web_notif;

/// Default channel id — must match backend FCM `android.notification.channelId`.
const String _androidChannelId = 'default';
const String _androidChannelName = 'General';
const String _androidChannelDescription =
    'Visitor alerts, approvals, and society updates';

/// White silhouette drawable in `android/app/src/main/res/drawable-*/`.
/// Android 5+ renders coloured PNGs as solid white squares in the status bar,
/// so the small icon must always be this transparent-background silhouette.
const String _androidNotificationIcon = '@drawable/ic_notification';

/// Brand green; tints the silhouette + the accent line in the notification
/// header. Mirrors `colors.xml/notification_brand` and `DesignColors.primary`.
const Color _androidNotificationTint = Color(0xFF004D40);

/// VAPID key for web push (public key — safe to embed in client code).
const String _webVapidKey =
    'BDOhmKRErEsWelZkhU0NpKKXrhByTOPjt1y_SWHfghJ4E4qW8lES7KkYiE_ZCKor-jg8HyT2d7Fdj44EwqHhe84';

/// SharedPreferences key for the stable web device ID.
const String _webDeviceIdKey = 'divine_web_push_device_id';

/// Service to manage push notifications, local (foreground) display, and device tokens.
class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  FirebaseMessaging? _firebaseMessaging;
  FirebaseMessaging get firebaseMessaging {
    _firebaseMessaging ??= FirebaseMessaging.instance;
    return _firebaseMessaging!;
  }

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? _deviceId;
  String? _deviceType;
  String? _deviceName;
  bool _isFirebaseAvailable = false;
  bool _localNotificationsReady = false;
  bool _isIosSimulator = false;

  int _foregroundNotifId = 0;

  /// True when FCM token + device id are suitable for backend registration.
  bool get isPushBackendReady =>
      _fcmToken != null &&
      _fcmToken!.isNotEmpty &&
      _deviceId != null &&
      _deviceId!.isNotEmpty &&
      !isPlaceholderToken;

  bool get isPlaceholderToken =>
      _fcmToken != null && _fcmToken!.startsWith('ios_sim_');

  Map<String, String>? _pendingPushData;

  Future<void> initialize() async {
    if (kIsWeb) {
      return _initializeWeb();
    }
    try {
      fcmDiag('INIT', 'NotificationService.initialize() starting');
      await _getDeviceInfo();

      try {
        if (platform_info.isAndroid) {
          final st = await Permission.notification.status;
          fcmDiag(
            'PERM_ANDROID',
            'POST_NOTIFICATIONS before request: $st (granted=${st.isGranted})',
          );
          if (!st.isGranted) {
            final after = await Permission.notification.request();
            fcmDiag(
              'PERM_ANDROID',
              'POST_NOTIFICATIONS after request: $after (granted=${after.isGranted})',
            );
          }
        }

        await _requestPermissions();
        await _initLocalNotifications();
        fcmDiag(
          'CHANNEL',
          'local notifications ready=$_localNotificationsReady (channel=$_androidChannelId)',
        );

        await _getFCMToken();
        _setupTokenRefreshListener();
        _setupMessageListeners();
        fcmDiag('STREAMS', 'onMessage / onMessageOpenedApp listeners attached');

        _isFirebaseAvailable = true;
        fcmDiag(
          'INIT_OK',
          'deviceId=${_previewId(_deviceId)} deviceType=$_deviceType '
              'placeholderToken=$isPlaceholderToken '
              'pushBackendReady=$isPushBackendReady '
              'fcmPreview=${_previewToken(_fcmToken)}',
        );
      } catch (firebaseError, st) {
        fcmDiag('INIT_FAIL', 'Firebase-facing init error', firebaseError, st);
      }
    } catch (e, st) {
      fcmDiag('INIT_FAIL', 'NotificationService.initialize outer', e, st);
    }
  }

  /// Web-specific initialization: browser permission prompt, VAPID token, foreground listener.
  Future<void> _initializeWeb() async {
    try {
      fcmDiag('INIT_WEB', 'NotificationService web init starting');

      // Stable device ID persisted in SharedPreferences (survives sessions).
      _deviceId = StorageService.getString(_webDeviceIdKey);
      if (_deviceId == null || _deviceId!.isEmpty) {
        _deviceId = const Uuid().v4();
        await StorageService.setString(_webDeviceIdKey, _deviceId!);
      }
      _deviceType = 'WEB';
      _deviceName = 'Web Browser';

      // Browser notification permission prompt.
      try {
        final settings = await firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        fcmDiag(
          'PERM_WEB',
          'requestPermission → ${settings.authorizationStatus}',
        );
      } catch (e, st) {
        fcmDiag('PERM_WEB_FAIL', '$e', e, st);
      }

      // Get FCM token with VAPID key.
      try {
        _fcmToken = await firebaseMessaging.getToken(vapidKey: _webVapidKey);
        fcmDiag('TOKEN_WEB', 'getToken OK preview=${_previewToken(_fcmToken)}');
      } catch (e, st) {
        fcmDiag('TOKEN_WEB_FAIL', 'getToken failed', e, st);
      }

      // Token refresh.
      _setupTokenRefreshListener();

      // Foreground messages — show browser notification + refresh providers.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        fcmDiag('RX_FOREGROUND_WEB', describeRemoteMessage(message));
        final data = _normalizeData(message.data);
        _refreshProvidersForPushType(data['type'] ?? '');

        if (!NotificationPreferenceStorage.shouldDeliverPush) {
          fcmDiag('RX_FOREGROUND_WEB', 'skip display: push disabled in settings');
          return;
        }
        final title = message.notification?.title ?? data['title'] ?? 'Notification';
        final body = message.notification?.body ?? data['body'] ?? '';
        web_notif.showWebNotification(title, body, data);
      });

      // Message-opened (user clicked browser notification while app was open).
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        fcmDiag('RX_OPENED_APP_WEB', describeRemoteMessage(message));
        final normalized = _normalizeData(message.data);
        applyNavigationFromPushData(normalized, openDetails: true);
      });

      // Cold-start tap.
      firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
        if (message == null) return;
        fcmDiag('RX_INITIAL_WEB', describeRemoteMessage(message));
        final normalized = _normalizeData(message.data);
        applyNavigationFromPushData(normalized, openDetails: true);
      });

      _isFirebaseAvailable = true;
      fcmDiag(
        'INIT_WEB_OK',
        'deviceId=${_previewId(_deviceId)} deviceType=$_deviceType '
            'pushBackendReady=$isPushBackendReady '
            'fcmPreview=${_previewToken(_fcmToken)}',
      );
    } catch (e, st) {
      fcmDiag('INIT_WEB_FAIL', 'web init error', e, st);
    }
  }

  static String _previewToken(String? t) {
    if (t == null || t.isEmpty) return '(none)';
    if (t.length <= 28) return t;
    return '${t.substring(0, 28)}...(${t.length} chars)';
  }

  static String _previewId(String? id) {
    if (id == null || id.isEmpty) return '(none)';
    if (id.length <= 16) return id;
    return '${id.substring(0, 16)}...';
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings(_androidNotificationIcon);
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: _androidChannelDescription,
        importance: Importance.high,
      ),
    );

    _localNotificationsReady = true;
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final m = <String, String>{};
        for (final e in decoded.entries) {
          m[e.key.toString()] = e.value?.toString() ?? '';
        }
        applyNavigationFromPushData(m, openDetails: true);
      }
    } catch (e, st) {
      fcmDiag('LOCAL_TAP_FAIL', 'payload parse/nav failed', e, st);
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final settings = await firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      fcmDiag(
        'PERM_FCM_IOS',
        'firebaseMessaging.requestPermission → ${settings.authorizationStatus}',
      );
    } catch (e, st) {
      fcmDiag('PERM_FCM_IOS_FAIL', '$e', e, st);
    }

    if (platform_info.isIOS) {
      try {
        await _local
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      } catch (e) {
        debugPrint('⚠️ Local notification iOS permission: $e');
      }

      // System banners / sound when app is in foreground (APNs → FCM pipeline).
      try {
        await firebaseMessaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (e) {
        debugPrint('⚠️ Foreground presentation options: $e');
      }
    }
  }

  Future<void> _getDeviceInfo() async {
    try {
      if (platform_info.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
        _deviceType = 'ANDROID';
        _deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (platform_info.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _isIosSimulator = !iosInfo.isPhysicalDevice;
        _deviceId = iosInfo.identifierForVendor;
        _deviceType = 'IOS';
        _deviceName = '${iosInfo.name} ${iosInfo.model}';
      }
    } catch (e, st) {
      fcmDiag('DEVICE_INFO_FAIL', 'device id/name fallback applied', e, st);
      _deviceId = 'unknown';
      _deviceType = platform_info.isAndroid ? 'ANDROID' : 'IOS';
      _deviceName = 'Unknown Device';
    }
  }

  static String _iosSimulatorPlaceholderFcmToken() {
    final bytes = List<int>.generate(72, (_) => Random.secure().nextInt(256));
    final core = base64Url.encode(bytes).replaceAll('=', '');
    return 'ios_sim_${DateTime.now().millisecondsSinceEpoch}_$core';
  }

  Future<void> _getFCMToken() async {
    if (platform_info.isIOS && _isIosSimulator) {
      _fcmToken = _iosSimulatorPlaceholderFcmToken();
      fcmDiag(
        'TOKEN_SIMULATOR',
        'iOS Simulator → placeholder preview=${_previewToken(_fcmToken)} (real FCM N/A)',
      );
      return;
    }

    try {
      if (platform_info.isIOS) {
        await _waitForApnsToken();
      }
      _fcmToken = await _getTokenWithRetry();
      fcmDiag('TOKEN', 'getToken OK preview=${_previewToken(_fcmToken)}');
    } catch (e, st) {
      fcmDiag('TOKEN_FAIL', 'getToken failed', e, st);
    }
  }

  Future<void> _waitForApnsToken() async {
    const attempts = 24;
    const delay = Duration(milliseconds: 250);
    for (var i = 0; i < attempts; i++) {
      final apns = await firebaseMessaging.getAPNSToken();
      if (apns != null) return;
      await Future<void>.delayed(delay);
    }
  }

  static bool _isApnsNotReadyError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('apns-token-not-set') || s.contains('apns token has not been set');
  }

  Future<String?> _getTokenWithRetry() async {
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        return await firebaseMessaging.getToken();
      } catch (e) {
        if (platform_info.isIOS && _isApnsNotReadyError(e) && attempt < 3) {
          await Future<void>.delayed(const Duration(seconds: 1));
          continue;
        }
        rethrow;
      }
    }
    return null;
  }

  void _setupTokenRefreshListener() {
    firebaseMessaging.onTokenRefresh.listen((newToken) {
      if (platform_info.isIOS && _isIosSimulator) return;
      fcmDiag(
        'TOKEN_REFRESH',
        'new token preview=${_previewToken(newToken)} → sync backend',
      );
      _fcmToken = newToken;
      unawaited(PushSyncService.sync());
    });
  }

  void _setupMessageListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      fcmDiag('RX_FOREGROUND', describeRemoteMessage(message));
      _refreshProvidersForPushType(_normalizeData(message.data)['type'] ?? '');
      unawaited(_showForegroundLocalNotification(message));
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      fcmDiag('RX_OPENED_APP', describeRemoteMessage(message));
      final normalized = _normalizeData(message.data);
      fcmDiag('NAV', 'openedApp data type=${normalized['type']} keys=${normalized.keys.toList()}');
      applyNavigationFromPushData(normalized, openDetails: true);
    });

    firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message == null) {
        fcmDiag('RX_INITIAL', 'getInitialMessage → null (not launched from tap)');
        return;
      }
      fcmDiag('RX_INITIAL', describeRemoteMessage(message));
      final normalized = _normalizeData(message.data);
      fcmDiag(
        'NAV',
        'initialMessage type=${normalized['type']} keys=${normalized.keys.toList()}',
      );
      applyNavigationFromPushData(normalized, openDetails: true);
    });
  }

  Map<String, String> _normalizeData(Map<String, dynamic> data) {
    return data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }

  /// Guard check-in often sends `photoUrl` as a data URL — decode for local big-picture style.
  Uint8List? _decodeDataUrlImage(String? raw) {
    final s = raw?.trim();
    if (s == null || !s.startsWith('data:image')) return null;
    final comma = s.indexOf(',');
    if (comma < 0 || comma >= s.length - 1) return null;
    try {
      return Uint8List.fromList(base64Decode(s.substring(comma + 1)));
    } catch (_) {
      return null;
    }
  }

  /// Prefer HTTPS image for expanded Android notification (matches backend FCM rules).
  String? _pickHttpsImageUrl(Map<String, dynamic> data) {
    for (final key in ['imageUrl', 'photoUrl']) {
      final u = data[key]?.toString().trim();
      if (u == null || u.isEmpty) continue;
      if (u.startsWith('https://') || u.startsWith('http://')) return u;
    }
    return null;
  }

  /// Rich tray text for visitor approval pushes (name, type, purpose).
  String _visitorApprovalTitle(RemoteMessage message, String fallback) {
    final d = message.data;
    if (d['type']?.toString() != 'VISITOR_APPROVAL_REQUEST') return fallback;
    final name = d['visitorName']?.toString().trim();
    if (name != null && name.isNotEmpty) return 'Visitor: $name';
    return fallback;
  }

  String _visitorApprovalBody(RemoteMessage message, String fallback) {
    final d = message.data;
    if (d['type']?.toString() != 'VISITOR_APPROVAL_REQUEST') return fallback;
    final typeLabel = d['visitorTypeLabel']?.toString().trim();
    final purpose = d['purpose']?.toString().trim();
    final parts = <String>[];
    if (typeLabel != null && typeLabel.isNotEmpty) parts.add(typeLabel);
    if (purpose != null && purpose.isNotEmpty) parts.add(purpose);
    final line = parts.isEmpty ? fallback : parts.join(' · ');
    return '$line\nTap to approve or decline.';
  }

  Future<void> _showForegroundLocalNotification(RemoteMessage message) async {
    if (!NotificationPreferenceStorage.shouldDeliverPush) {
      fcmDiag(
        'FOREGROUND_LOCAL',
        'skip: notifications/push disabled in settings (messageId=${message.messageId})',
      );
      return;
    }
    if (!_localNotificationsReady) {
      fcmDiag(
        'FOREGROUND_LOCAL',
        'abort: local plugin not ready (messageId=${message.messageId})',
      );
      return;
    }

    // Android 13+: show in status bar requires POST_NOTIFICATIONS.
    if (platform_info.isAndroid) {
      PermissionStatus st = await Permission.notification.status;
      if (!st.isGranted) {
        if (st.isPermanentlyDenied) {
          fcmDiag(
            'FOREGROUND_LOCAL',
            'abort: POST_NOTIFICATIONS permanently denied',
          );
          return;
        }
        st = await Permission.notification.request();
        if (!st.isGranted) {
          fcmDiag(
            'FOREGROUND_LOCAL',
            'abort: POST_NOTIFICATIONS denied after request',
          );
          return;
        }
      }
      fcmDiag(
        'FOREGROUND_LOCAL',
        'POST_NOTIFICATIONS granted → composing local notification',
      );
    }

    final titleFromData = message.data['title']?.toString().trim();
    final bodyFromData = message.data['body']?.toString().trim();

    final nTitle = message.notification?.title?.trim();
    final nBody = message.notification?.body?.trim();
    var title = (nTitle != null && nTitle.isNotEmpty)
        ? nTitle
        : (titleFromData?.isNotEmpty == true ? titleFromData! : 'Notification');
    var bodyRaw = (nBody != null && nBody.isNotEmpty)
        ? nBody
        : (bodyFromData ?? '');
    var body = bodyRaw.isNotEmpty ? bodyRaw : title;

    if (message.data['type']?.toString() == 'VISITOR_APPROVAL_REQUEST') {
      title = _visitorApprovalTitle(message, title);
      body = _visitorApprovalBody(message, body);
    }

    _foregroundNotifId = (_foregroundNotifId + 1) % 100000;
    final id = message.messageId?.hashCode.abs() ?? _foregroundNotifId;

    final payload = jsonEncode(message.data);

    StyleInformation? androidStyle;
    if (platform_info.isAndroid) {
      Uint8List? picBytes =
          _decodeDataUrlImage(message.data['photoUrl']?.toString());
      if (picBytes == null || picBytes.isEmpty) {
        final picUrl = _pickHttpsImageUrl(message.data);
        if (picUrl != null) {
          try {
            final dio = Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 6),
              ),
            );
            final res = await dio.get<List<int>>(
              picUrl,
              options: Options(responseType: ResponseType.bytes),
            );
            final raw = res.data;
            if (raw != null && raw.isNotEmpty) {
              picBytes = Uint8List.fromList(raw);
            }
          } catch (e) {
            fcmDiag('FOREGROUND_LOCAL', 'big picture download skipped: $e');
          }
        }
      }
      if (picBytes != null && picBytes.isNotEmpty) {
        androidStyle = BigPictureStyleInformation(
          ByteArrayAndroidBitmap(picBytes),
          contentTitle: title,
          summaryText: body,
        );
      }
      androidStyle ??=
          BigTextStyleInformation(body, contentTitle: title);
    }

    final iosSubtitle = message.data['type']?.toString() ==
            'VISITOR_APPROVAL_REQUEST'
        ? message.data['visitorTypeLabel']?.toString()
        : null;

    try {
      fcmDiag(
        'FOREGROUND_LOCAL',
        'show id=$id title="$title" bodyLen=${body.length} '
            'payloadKeys=${message.data.keys.toList()}',
      );
      await _local.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannelId,
            _androidChannelName,
            channelDescription: _androidChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            visibility: NotificationVisibility.public,
            playSound: true,
            enableVibration: true,
            icon: _androidNotificationIcon,
            color: _androidNotificationTint,
            colorized: false,
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            styleInformation: androidStyle,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            subtitle: iosSubtitle,
          ),
        ),
        payload: payload,
      );
      fcmDiag('FOREGROUND_LOCAL', 'flutter_local_notifications.show OK id=$id');
    } catch (e, st) {
      fcmDiag('FOREGROUND_LOCAL_FAIL', 'show failed id=$id', e, st);
    }
  }

  /// Validates that an ID from push data is safe to embed in a route path.
  /// Accepts alphanumeric strings with hyphens and underscores (10-50 chars),
  /// covering UUID, CUID, and similar formats.
  static final _safeIdPattern = RegExp(r'^[a-zA-Z0-9_-]{10,50}$');
  static bool _isValidPushId(String id) => _safeIdPattern.hasMatch(id);

  static bool _isGuardSession() {
    final role = StorageService.getUserRole();
    return UserRole.fromString(role ?? '') == UserRole.guard;
  }

  /// Called when user taps a push (background/terminated) or we retry pending routes.
  /// Returns true when a route was matched (navigation attempted).
  bool applyNavigationFromPushData(
    Map<String, String> data, {
    required bool openDetails,
  }) {
    final type = data['type'] ?? '';

    bool go() {
      final ctx = appRootNavigatorKey.currentContext;
      if (ctx == null) {
        fcmDiag('NAV', 'go(): navigator context still null → route skipped');
        return false;
      }
      final router = GoRouter.of(ctx);
      try {
        if (type == 'VISITOR_APPROVAL_REQUEST' && openDetails) {
          final id = data['visitorId'] ?? '';
          if (id.isNotEmpty && _isValidPushId(id)) {
            router.push('/resident/visitor-requests/$id');
          } else {
            router.push('/resident/visitor-requests');
          }
          return true;
        }
        if (type == 'VISITOR_GATE_NOTIFY' && openDetails) {
          router.push('/resident/visitor-requests');
          return true;
        }
        if (type == 'VISITOR_APPROVAL_RESOLVED') {
          if (_isGuardSession()) {
            router.go('/guard/entries');
          } else {
            router.push('/resident/visitor-requests');
          }
          return true;
        }
        if (type == 'VISITOR_PRE_APPROVED_CREATED') {
          final id = data['preApprovedId'] ?? '';
          if (id.isNotEmpty && _isValidPushId(id)) {
            router.push(
              Uri(
                path: '/guard/pre-approved',
                queryParameters: {'focus': id},
              ).toString(),
            );
          } else {
            router.push('/guard/pre-approved');
          }
          return true;
        }
        if (type == 'SOS_CREATED' || type == 'SOS_ESCALATION') {
          router.go('/guard/dashboard');
          return true;
        }
        if (type == 'SOS_ESCALATION_ADMIN') {
          if (_isGuardSession()) {
            router.go('/guard/dashboard');
          } else {
            router.push('/resident/admin-sos');
          }
          return true;
        }
        if (type == 'SOS_UPDATE' || type == 'SOS_CANCELLED') {
          router.go('/resident/sos/active');
          return true;
        }
        if (type == 'VISITOR_PRE_APPROVED_ARRIVED') {
          router.push('/resident/visitor-requests');
          return true;
        }
        if (type == 'VISITOR_VILLA_RESPONSE') {
          if (_isGuardSession()) {
            router.go('/guard/entries');
          } else {
            router.push('/resident/visitor-requests');
          }
          return true;
        }
        if (type == 'complaint_status' ||
            type == 'COMPLAINT_SLA_BREACH' ||
            type == 'COMPLAINT_AUTO_CLOSED') {
          router.push('/resident/my-complaints');
          return true;
        }
        if (type == 'notice') {
          router.push('/resident/notices');
          return true;
        }
        if (type == 'BILLING_CYCLE_CREATED' ||
            type == 'MAINTENANCE_REMINDER' ||
            type == 'MAINTENANCE_PAYMENT_RECORDED' ||
            type == 'MAINTENANCE_PAYMENT_REVERSED' ||
            type == 'MAINTENANCE_LEDGER_UPDATED' ||
            type == 'billing_payment_failed' ||
            type == 'billing_payment_success') {
          requestResidentDataRefresh();
          router.push('/resident/maintenance');
          return true;
        }
        if (type == 'PARCEL_RECEIVED') {
          router.push('/resident/parcels');
          return true;
        }
        if (type == 'amenity_booking_status') {
          router.push('/resident/amenity-bookings');
          return true;
        }
        if (type == 'WATER_SUPPLY_REQUEST') {
          router.push('/resident/admin-gate-utilities');
          return true;
        }
        if (type == 'WATER_SUPPLY_REQUEST_RESOLVED') {
          router.push('/resident/utilities');
          return true;
        }
        if (type == 'UPI_PAYMENT_SUBMITTED') {
          router.push('/resident/admin-upi-verifications');
          return true;
        }
        if (type == 'UPI_PAYMENT_VERIFIED' || type == 'UPI_PAYMENT_REJECTED') {
          router.push('/resident/maintenance');
          return true;
        }
        if (type == 'SPECIAL_PROJECT_CREATED' ||
            type == 'SPECIAL_PROJECT_PAYMENT_RECORDED') {
          final projectId = data['projectId'] ?? '';
          if (projectId.isNotEmpty && _isValidPushId(projectId)) {
            router.push('/resident/special-projects/$projectId');
          } else {
            router.push('/resident/special-projects');
          }
          return true;
        }
        fcmDiag(
          'NAV_SKIP',
          'no matching route type="$type" openDetails=$openDetails '
              'visitorId=${data['visitorId']}',
        );
        return false;
      } catch (e, st) {
        fcmDiag('NAV_ERR', 'go() failed type="$type"', e, st);
        return false;
      }
    }

    final ctx = appRootNavigatorKey.currentContext;
    if (ctx == null) {
      fcmDiag(
        'NAV',
        'defer: no navigator context yet → pending type=$type '
            'visitorId=${data['visitorId']}',
      );
      _pendingPushData = Map<String, String>.from(data);
      return false;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      fcmDiag('NAV', 'post-frame navigate type=$type openDetails=$openDetails');
      go();
    });
    return _isKnownPushNavigationType(type);
  }

  static bool _isKnownPushNavigationType(String type) {
    if (type.isEmpty) return false;
    const known = {
      'VISITOR_APPROVAL_REQUEST',
      'VISITOR_GATE_NOTIFY',
      'VISITOR_APPROVAL_RESOLVED',
      'VISITOR_PRE_APPROVED_CREATED',
      'VISITOR_PRE_APPROVED_ARRIVED',
      'VISITOR_VILLA_RESPONSE',
      'SOS_CREATED',
      'SOS_ESCALATION',
      'SOS_ESCALATION_ADMIN',
      'SOS_UPDATE',
      'SOS_CANCELLED',
      'complaint_status',
      'COMPLAINT_SLA_BREACH',
      'COMPLAINT_AUTO_CLOSED',
      'notice',
      'BILLING_CYCLE_CREATED',
      'MAINTENANCE_REMINDER',
      'MAINTENANCE_PAYMENT_RECORDED',
      'MAINTENANCE_PAYMENT_REVERSED',
      'MAINTENANCE_LEDGER_UPDATED',
      'billing_payment_failed',
      'billing_payment_success',
      'PARCEL_RECEIVED',
      'amenity_booking_status',
      'WATER_SUPPLY_REQUEST',
      'WATER_SUPPLY_REQUEST_RESOLVED',
      'UPI_PAYMENT_SUBMITTED',
      'UPI_PAYMENT_VERIFIED',
      'UPI_PAYMENT_REJECTED',
      'SPECIAL_PROJECT_CREATED',
      'SPECIAL_PROJECT_PAYMENT_RECORDED',
    };
    return known.contains(type) || type.startsWith('VISITOR_');
  }

  /// Whether inbox rows should show a navigation affordance for this push type.
  static bool applyNavigationFromPushDataPreview(String type) {
    return _isKnownPushNavigationType(type);
  }

  /// Invalidate cached providers when a push indicates server data changed.
  void _refreshProvidersForPushType(String type) {
    if (type.isEmpty) return;

    const maintenanceTypes = {
      'MAINTENANCE_PAYMENT_REVERSED',
      'MAINTENANCE_PAYMENT_RECORDED',
      'MAINTENANCE_LEDGER_UPDATED',
      'BILLING_CYCLE_CREATED',
      'MAINTENANCE_REMINDER',
      'billing_payment_success',
      'billing_window_open',
      'billing_due_reminder',
      'BILLING_GRACE_REMINDER',
      'UPI_PAYMENT_SUBMITTED',
      'UPI_PAYMENT_VERIFIED',
      'UPI_PAYMENT_REJECTED',
      'WATER_SUPPLY_REQUEST',
      'WATER_SUPPLY_REQUEST_RESOLVED',
      'COMPLAINT_SLA_BREACH',
      'COMPLAINT_AUTO_CLOSED',
      'SOS_CANCELLED',
    };
    const residentContentTypes = {
      'PARCEL_RECEIVED',
      'complaint_status',
      'notice',
      'amenity_booking_status',
      'SPECIAL_PROJECT_CREATED',
      'SPECIAL_PROJECT_PAYMENT_RECORDED',
    };
    const visitorTypes = {
      'VISITOR_APPROVAL_REQUEST',
      'VISITOR_PRE_APPROVED_ARRIVED',
      'VISITOR_PRE_APPROVED_CREATED',
      'VISITOR_APPROVAL_RESOLVED',
      'VISITOR_CHECKED_IN',
      'VISITOR_CHECKED_OUT',
    };

    if (maintenanceTypes.contains(type) ||
        residentContentTypes.contains(type) ||
        visitorTypes.contains(type) ||
        type.startsWith('VISITOR_')) {
      requestResidentDataRefresh();
    }
    if (visitorTypes.contains(type) || type.startsWith('VISITOR_')) {
      requestGuardDataRefresh();
    }
  }

  /// Drain navigation queued before the first frame (cold start).
  void flushPendingNavigation() {
    final pending = _pendingPushData;
    _pendingPushData = null;
    if (pending == null || pending.isEmpty) return;
    fcmDiag(
      'NAV',
      'flushPending type=${pending['type']} keys=${pending.keys.toList()}',
    );
    applyNavigationFromPushData(pending, openDetails: true);
  }

  Map<String, String?> getDeviceTokenInfo() {
    return {
      'fcmToken': _fcmToken,
      'deviceId': _deviceId,
      'deviceType': _deviceType,
      'deviceName': _deviceName,
    };
  }

  String? get fcmToken => _fcmToken;
  String? get deviceId => _deviceId;
  String? get deviceType => _deviceType;
  String? get deviceName => _deviceName;

  bool get hasDeviceToken => _fcmToken != null && _deviceId != null;

  Future<void> subscribeToTopic(String topic) async {
    if (!_isFirebaseAvailable) return;
    try {
      await firebaseMessaging.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('❌ subscribeToTopic: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    if (!_isFirebaseAvailable) return;
    try {
      await firebaseMessaging.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('❌ unsubscribeFromTopic: $e');
    }
  }

  Future<void> deleteToken() async {
    if (platform_info.isIOS && _isIosSimulator) {
      _fcmToken = null;
      return;
    }
    if (!_isFirebaseAvailable) return;
    try {
      await firebaseMessaging.deleteToken();
      _fcmToken = null;
    } catch (e) {
      debugPrint('❌ deleteToken: $e');
    }
  }
}

/// Background FCM handler (top-level).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Data-only pushes run full Dart handlers here; notification+hybrid payloads
  // are often surfaced by the OS without entering this isolate.
  fcmDiag(
    'RX_BACKGROUND_ISOLATE',
    describeRemoteMessage(message),
  );
}
