import 'dart:io' show Platform;

/// Application-wide constants
class AppConstants {
  // App Info — single source of truth for all branding strings.
  static const String appName = 'GatePass+';
  static const String appTagline = 'Society Management Platform';
  /// Fallback version string. Runtime code should use
  /// `PackageInfo.fromPlatform()` for the actual installed version.
  static const String appVersion = '1.1.1';

  /// Splash screen credit line. Override per-build:
  /// `--dart-define=ORG_NAME=Your Welfare Association`
  static const String orgName = String.fromEnvironment(
    'ORG_NAME',
    defaultValue: 'Divine Residency Welfare Association',
  );

  /// Persisted override: full API base including `/api` when applicable.
  static const String keyApiBaseUrl = 'api_base_url';

  /// Full base URL at build time, e.g. `https://api.example.com/api`.
  /// Overrides saved URL. Example:
  /// `flutter build apk --dart-define=API_BASE_URL=https://gatepass-v037.onrender.com/api`
  static const String _apiBaseUrlFromEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://gatepass-v037.onrender.com/api',
  );

  /// LAN host only (no scheme/port). Used when `API_BASE_URL` and saved URL are empty.
  /// Example: `flutter run --dart-define=API_HOST=192.168.1.42`
  static const String _apiHostFromEnv = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );

  /// When no `API_HOST` dart-define and no saved URL: physical phones/tablets use this host
  /// (your Mac/PC LAN IP on the current Wi‑Fi). Update if your network IP changes.
  /// Last detected on this machine (en0): `192.168.1.5`.
  static const String defaultPhysicalLanHost = '192.168.1.5';

  /// Android Emulator fallback: points to host machine's loopback via the
  /// special `10.0.2.2` alias so simulator builds work out-of-the-box.
  /// For deployed backend, use `--dart-define=API_BASE_URL=https://your-api.example.com/api`.
  static const String simulatorAndroidApiBase = 'http://10.0.2.2:4000/api';

  /// iOS Simulator fallback: points to localhost on host machine.
  /// For deployed backend, use `--dart-define=API_BASE_URL=https://your-api.example.com/api`.
  static const String simulatorIosApiBase = 'http://127.0.0.1:4000/api';

  static String? _runtimeBaseUrlOverride;

  /// Set from `main()` using [device_info_plus] — env vars like `SIMULATOR_DEVICE_NAME`
  /// are usually **not** visible to Dart on Flutter iOS, so detection would wrongly use LAN IP.
  static bool? _iosSimulatorResolved;

  /// Set from `main()` using [device_info_plus] on Android — `Platform.environment` is
  /// unavailable inside Flutter, so the env-var check in [_isAndroidEmulator] always fails.
  static bool? _androidEmulatorResolved;

  /// Call once at startup on Android after [DeviceInfoPlugin].androidInfo is available.
  static void setAndroidEmulatorResolved(bool isEmulator) {
    if (!Platform.isAndroid) return;
    _androidEmulatorResolved = isEmulator;
  }

  /// Set from [StorageService] in `main` or after user saves in settings / login dialog.
  static void setRuntimeBaseUrlOverride(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      _runtimeBaseUrlOverride = null;
    } else {
      _runtimeBaseUrlOverride = normalizeApiBaseUrl(raw.trim());
    }
  }

  /// Call once at startup on iOS after [DeviceInfoPlugin].iosInfo is available.
  static void setIosSimulatorResolved(bool isSimulator) {
    if (!Platform.isIOS) return;
    _iosSimulatorResolved = isSimulator;
  }

  /// Adds `http(s)://` if missing, strips trailing slashes, and ensures the path ends with `/api`
  /// (Express mounts REST under `/api`, same as admin web `NEXT_PUBLIC_API_URL`).
  static String normalizeApiBaseUrl(String input) {
    var u = input.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (!u.endsWith('/api')) {
      u = '$u/api';
    }
    return u;
  }

  /// `10.0.2.2` works only from Android emulators and breaks on iOS simulators.
  static bool _isAndroidEmulatorOnlyHost(String value) {
    final v = value.toLowerCase();
    return v.contains('://10.0.2.2') || v.startsWith('10.0.2.2');
  }

  static bool get _isIosSimulator {
    if (!Platform.isIOS) return false;
    if (_iosSimulatorResolved != null) return _iosSimulatorResolved!;
    final e = Platform.environment;
    return e.containsKey('SIMULATOR_DEVICE_NAME') ||
        e.containsKey('SIMULATOR_HOST_HOME');
  }

  static bool get _isAndroidEmulator {
    if (!Platform.isAndroid) return false;
    if (_androidEmulatorResolved != null) return _androidEmulatorResolved!;
    // Fallback: Platform.environment is generally empty in Flutter on Android,
    // so this rarely succeeds — prefer setAndroidEmulatorResolved() from main().
    if (Platform.environment['ANDROID_EMULATOR'] == '1') return true;
    final model = (Platform.environment['MODEL'] ?? '').toLowerCase();
    if (model.contains('sdk_gphone') || model.contains('emulator')) {
      return true;
    }
    final hw = (Platform.environment['RO_HARDWARE'] ?? '').toLowerCase();
    return hw.contains('generic') || hw.contains('goldfish');
  }

  /// Resolved API root (…/api). Dio paths are absolute like `/auth/login`.
  ///
  /// Resolution order:
  /// 1. `API_BASE_URL` (dart-define), e.g. production HTTPS URL.
  /// 2. Saved URL from **Settings / API server** on the device.
  /// 3. `API_HOST` dart-define + port 4000 (physical devices).
  /// 4. **Simulators** (no saved URL / env): use [simulatorAndroidApiBase] or [simulatorIosApiBase].
  ///    **Desktop** → `http://localhost:4000/api`.
  static String get baseUrl {
    if (_apiBaseUrlFromEnv.isNotEmpty) {
      return normalizeApiBaseUrl(_apiBaseUrlFromEnv);
    }
    if (_runtimeBaseUrlOverride != null &&
        _runtimeBaseUrlOverride!.isNotEmpty) {
      // If a URL saved on Android emulator is reused on iOS simulator,
      // auto-fallback to the iOS simulator host alias.
      if (Platform.isIOS &&
          _isIosSimulator &&
          _isAndroidEmulatorOnlyHost(_runtimeBaseUrlOverride!)) {
        return simulatorIosApiBase;
      }
      return _runtimeBaseUrlOverride!;
    }

    if (Platform.isAndroid) {
      if (_apiHostFromEnv.isNotEmpty) {
        return 'http://$_apiHostFromEnv:4000/api';
      }
      if (_isAndroidEmulator) {
        return simulatorAndroidApiBase;
      }
      return 'http://${defaultPhysicalLanHost}:4000/api';
    }
    if (Platform.isIOS) {
      if (_apiHostFromEnv.isNotEmpty) {
        return 'http://$_apiHostFromEnv:4000/api';
      }
      if (_isIosSimulator) {
        return simulatorIosApiBase;
      }
      return 'http://${defaultPhysicalLanHost}:4000/api';
    }
    return 'http://localhost:4000/api';
  }
  
  // Storage Keys
  static const String keyToken = 'auth_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserId = 'user_id';
  static const String keyUserRole = 'user_role';
  static const String keyUserData = 'user_data';
  static const String keySocietyId = 'society_id';
  static const String keyVillaId = 'villa_id';

  /// Last society picked on login (Flutter resident/guard).
  static const String keyPreferredLoginSocietyId = 'preferred_login_society_id';

  /// Display name for [keyPreferredLoginSocietyId] (set on society selection screen).
  static const String keyPreferredLoginSocietyName = 'preferred_login_society_name';

  /// "Remember me" checkbox on login — persists username + password in secure storage.
  static const String keyRememberMe = 'remember_me';

  /// User opted in to biometric unlock on the login screen (credentials in secure storage).
  static const String keyBiometricLoginEnabled = 'biometric_login_enabled';

  /// Master on-device notification switch (UI + local banners); persisted across sessions.
  static const String keyNotificationsEnabled = 'pref_notifications_enabled';

  /// Push channel preference (FCM registration); persisted across sessions.
  static const String keyPushNotificationsEnabled = 'pref_push_notifications_enabled';

  /// Theme mode preference. Stored values: 'system' | 'light' | 'dark'.
  /// Falls back to `system` when missing or unrecognized.
  static const String keyThemeMode = 'pref_theme_mode';

  /// In-app legal documents (Markdown bundled via `pubspec.yaml` → `assets/legal/`).
  /// Keep in sync with `docs/legal/` in the monorepo when you update policy text.
  static const String privacyPolicyAsset = 'assets/legal/privacy_policy.md';
  static const String termsConditionsAsset = 'assets/legal/terms_and_conditions.md';

  /// Public HTTPS URLs for the legal documents, hosted on GitHub Pages.
  ///
  /// The Settings → Legal screen prefers a public URL when one is set
  /// (loaded inside an in-app WebView via `LegalWebViewScreen`) and falls
  /// back to the bundled markdown ([privacyPolicyAsset] /
  /// [termsConditionsAsset]) only when the URL is empty. The bundled
  /// markdown still ships in the app for offline browsing and for parity
  /// with the canonical text submitted to the Play Store / App Store.
  ///
  /// Override per-build (e.g., staging) with
  /// `--dart-define=PRIVACY_POLICY_URL=…`.
  static const String privacyPolicyPublicUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue:
        'https://divinedrwa.github.io/GatePass-Legal/privacy_policy.html',
  );
  static const String termsConditionsPublicUrl = String.fromEnvironment(
    'TERMS_CONDITIONS_URL',
    defaultValue:
        'https://divinedrwa.github.io/GatePass-Legal/terms_condition.html',
  );

  /// Public account-deletion landing page — required by the Google Play
  /// User Data policy so prospective users can find deletion instructions
  /// before installing the app. Defaults to the GatePass+ legal site;
  /// override per-build with `--dart-define=ACCOUNT_DELETION_URL=…`.
  static const String accountDeletionPublicUrl = String.fromEnvironment(
    'ACCOUNT_DELETION_URL',
    defaultValue:
        'https://divinedrwa.github.io/GatePass-Legal/account_deletion.html',
  );

  /// Resident-facing support inbox. Used by the in-app "Contact support"
  /// tile. Override per-build (e.g., staging vs prod) with
  /// `--dart-define=SUPPORT_EMAIL=…`.
  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'support@gatepass.app',
  );

  /// Google Play listing (`applicationId` from Android `build.gradle.kts`).
  static const String androidApplicationId = 'com.app.gatepass';

  /// Apple App Store numeric ID from App Store Connect (URL contains `idXXXXXXXX`).
  /// If empty, opens the App Store home on iOS. Example:
  /// `flutter build ios --dart-define=IOS_APP_STORE_ID=1234567890`
  static const String iosAppStoreId = String.fromEnvironment(
    'IOS_APP_STORE_ID',
    defaultValue: '',
  );

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // Timeouts
  static const int connectTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds
  
  // Date Formats
  static const String dateFormat = 'dd MMM yyyy';
  static const String timeFormat = 'hh:mm a';
  static const String dateTimeFormat = 'dd MMM yyyy, hh:mm a';
  
  // Validation
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 50;
  static const int phoneNumberLength = 10;
}

/// User Roles
enum UserRole {
  superAdmin('SUPER_ADMIN'),
  admin('ADMIN'),
  resident('RESIDENT'),
  guard('GUARD'),
  residentCumAdmin('RESIDENT_CUM_ADMIN');

  final String value;
  const UserRole(this.value);

  bool get isAdminLike => this == admin || this == residentCumAdmin;
  bool get isResidentLike => this == resident || this == admin || this == residentCumAdmin;

  static UserRole fromString(String role) {
    final u = role.toUpperCase().trim();
    return UserRole.values.firstWhere(
      (r) => r.value == u,
      orElse: () => UserRole.resident,
    );
  }
}

/// Resident Types
enum ResidentType {
  owner('OWNER'),
  tenant('TENANT'),
  familyMember('FAMILY_MEMBER');

  final String value;
  const ResidentType(this.value);
  
  static ResidentType fromString(String type) {
    return ResidentType.values.firstWhere(
      (t) => t.value == type.toUpperCase(),
      orElse: () => ResidentType.owner,
    );
  }

  /// Human-readable occupant label (server also sends `occupantRoleLabel` on `/residents/me`).
  String get displayLabel {
    switch (this) {
      case ResidentType.owner:
        return 'Owner';
      case ResidentType.tenant:
        return 'Tenant';
      case ResidentType.familyMember:
        return 'Family member';
    }
  }
}

/// SOS Alert Types — aligned with backend `SOSType`.
enum SOSType {
  medical('MEDICAL'),
  fire('FIRE'),
  security('SECURITY'),
  accident('ACCIDENT'),
  other('OTHER');

  final String value;
  const SOSType(this.value);
}

/// SOS lifecycle — backend `SOSType` / `SOSStatus`.
enum SOSStatus {
  created('CREATED'),
  pending('PENDING'),
  active('ACTIVE'),
  acknowledged('ACKNOWLEDGED'),
  inProgress('IN_PROGRESS'),
  resolved('RESOLVED'),
  cancelled('CANCELLED');

  final String value;
  const SOSStatus(this.value);

  bool get isTerminal =>
      this == SOSStatus.resolved || this == SOSStatus.cancelled;

  bool get isOpen => !isTerminal;
}

/// Visitor Types — single source of truth for labels shown across resident
/// and guard screens.
enum VisitorType {
  guest('GUEST', 'Guest', 'Friends, family, or social visitors'),
  delivery('DELIVERY', 'Delivery', 'Packages, food, or courier drop-offs'),
  /// Matches backend Prisma `VisitorType.SERVICE_PROVIDER` and `/residents/pre-approve-visitor` zod schema.
  service('SERVICE_PROVIDER', 'Service', 'Repairs, cleaning, or one-off appointments'),
  vendor('VENDOR', 'Vendor', 'Regular suppliers or contracted staff');

  final String value;
  final String label;
  final String description;
  const VisitorType(this.value, this.label, this.description);
}

/// Booking Status
enum BookingStatus {
  pending('PENDING'),
  confirmed('CONFIRMED'),
  cancelled('CANCELLED'),
  completed('COMPLETED');

  final String value;
  const BookingStatus(this.value);
}

/// Parcel Status
enum ParcelStatus {
  received('RECEIVED'),
  delivered('DELIVERED'),
  pending('PENDING');

  final String value;
  const ParcelStatus(this.value);
}

/// Notice Category
enum NoticeCategory {
  general('GENERAL'),
  maintenance('MAINTENANCE'),
  event('EVENT'),
  emergency('EMERGENCY'),
  announcement('ANNOUNCEMENT'),
  meeting('MEETING');

  final String value;
  const NoticeCategory(this.value);
}

/// Notice Priority
enum NoticePriority {
  low('LOW'),
  normal('NORMAL'),
  high('HIGH'),
  urgent('URGENT');

  final String value;
  const NoticePriority(this.value);
}

/// Event Category
enum EventCategory {
  social('SOCIAL'),
  sports('SPORTS'),
  cultural('CULTURAL'),
  meeting('MEETING'),
  workshop('WORKSHOP'),
  festival('FESTIVAL');

  final String value;
  const EventCategory(this.value);
}

/// Document Category
enum DocumentCategory {
  general('GENERAL'),
  bylaws('BYLAWS'),
  minutes('MINUTES'),
  financial('FINANCIAL'),
  policy('POLICY'),
  form('FORM');

  final String value;
  const DocumentCategory(this.value);
}
