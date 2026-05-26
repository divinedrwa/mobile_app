import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

import '../logging/fcm_log.dart';
import '../routing/app_navigator_keys.dart';
import '../utils/notification_preference_storage.dart';
import 'push_sync_service.dart';

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
const Color _androidNotificationTint = Color(0xFF3D8361);

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
    try {
      fcmDiag('INIT', 'NotificationService.initialize() starting');
      await _getDeviceInfo();

      try {
        if (Platform.isAndroid) {
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

    if (Platform.isIOS) {
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
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
        _deviceType = 'ANDROID';
        _deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _isIosSimulator = !iosInfo.isPhysicalDevice;
        _deviceId = iosInfo.identifierForVendor;
        _deviceType = 'IOS';
        _deviceName = '${iosInfo.name} ${iosInfo.model}';
      }
    } catch (e, st) {
      fcmDiag('DEVICE_INFO_FAIL', 'device id/name fallback applied', e, st);
      _deviceId = 'unknown';
      _deviceType = Platform.isAndroid ? 'ANDROID' : 'IOS';
      _deviceName = 'Unknown Device';
    }
  }

  static String _iosSimulatorPlaceholderFcmToken() {
    final bytes = List<int>.generate(72, (_) => Random.secure().nextInt(256));
    final core = base64Url.encode(bytes).replaceAll('=', '');
    return 'ios_sim_${DateTime.now().millisecondsSinceEpoch}_$core';
  }

  Future<void> _getFCMToken() async {
    if (Platform.isIOS && _isIosSimulator) {
      _fcmToken = _iosSimulatorPlaceholderFcmToken();
      fcmDiag(
        'TOKEN_SIMULATOR',
        'iOS Simulator → placeholder preview=${_previewToken(_fcmToken)} (real FCM N/A)',
      );
      return;
    }

    try {
      if (Platform.isIOS) {
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
        if (Platform.isIOS && _isApnsNotReadyError(e) && attempt < 3) {
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
      if (Platform.isIOS && _isIosSimulator) return;
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
    if (Platform.isAndroid) {
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
    if (Platform.isAndroid) {
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

  /// Called when user taps a push (background/terminated) or we retry pending routes.
  void applyNavigationFromPushData(
    Map<String, String> data, {
    required bool openDetails,
  }) {
    final type = data['type'] ?? '';

    void go() {
      final ctx = appRootNavigatorKey.currentContext;
      if (ctx == null) {
        fcmDiag('NAV', 'go(): navigator context still null → route skipped');
        return;
      }
      final router = GoRouter.of(ctx);
      try {
        if (type == 'VISITOR_APPROVAL_REQUEST' && openDetails) {
          final id = data['visitorId'] ?? '';
          if (id.isNotEmpty) {
            router.push('/resident/visitor-requests/$id');
          } else {
            router.push('/resident/visitor-requests');
          }
          return;
        }
        if (type == 'VISITOR_GATE_NOTIFY' && openDetails) {
          router.push('/resident/visitor-requests');
          return;
        }
        if (type == 'VISITOR_APPROVAL_RESOLVED') {
          router.go('/guard/entries');
          return;
        }
        if (type == 'VISITOR_PRE_APPROVED_CREATED') {
          final id = data['preApprovedId'] ?? '';
          if (id.isNotEmpty) {
            router.push(
              Uri(
                path: '/guard/pre-approved',
                queryParameters: {'focus': id},
              ).toString(),
            );
          } else {
            router.push('/guard/pre-approved');
          }
          return;
        }
        if (type == 'SOS_CREATED' ||
            type == 'SOS_ESCALATION' ||
            type == 'SOS_ESCALATION_ADMIN') {
          router.go('/guard/dashboard');
          return;
        }
        if (type == 'SOS_UPDATE') {
          router.go('/resident/sos/active');
          return;
        }
        if (type == 'VISITOR_PRE_APPROVED_ARRIVED') {
          router.push('/resident/visitor-requests');
          return;
        }
        if (type == 'complaint_status') {
          router.push('/resident/my-complaints');
          return;
        }
        if (type == 'notice') {
          router.go('/resident');
          return;
        }
        if (type == 'BILLING_CYCLE_CREATED' ||
            type == 'MAINTENANCE_REMINDER' ||
            type == 'MAINTENANCE_PAYMENT_RECORDED' ||
            type == 'MAINTENANCE_PAYMENT_REVERSED') {
          router.push('/resident/maintenance');
          return;
        }
        if (type == 'PARCEL_RECEIVED') {
          router.go('/resident');
          return;
        }
        if (type == 'SPECIAL_PROJECT_CREATED' ||
            type == 'SPECIAL_PROJECT_PAYMENT_RECORDED') {
          final projectId = data['projectId'] ?? '';
          if (projectId.isNotEmpty) {
            router.push('/resident/special-projects/$projectId');
          } else {
            router.push('/resident/special-projects');
          }
          return;
        }
        fcmDiag(
          'NAV_SKIP',
          'no matching route type="$type" openDetails=$openDetails '
              'visitorId=${data['visitorId']}',
        );
      } catch (e, st) {
        fcmDiag('NAV_ERR', 'go() failed type="$type"', e, st);
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
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      fcmDiag('NAV', 'post-frame navigate type=$type openDetails=$openDetails');
      go();
    });
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
    if (Platform.isIOS && _isIosSimulator) {
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
