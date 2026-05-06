import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/services/push_sync_service.dart';
import '../../../../core/utils/notification_preference_storage.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class NotificationSettingsState {
  final bool masterEnabled;
  final bool pushEnabled;
  final bool emailEnabled;
  final bool isBusy;

  const NotificationSettingsState({
    required this.masterEnabled,
    required this.pushEnabled,
    required this.emailEnabled,
    this.isBusy = false,
  });

  NotificationSettingsState copyWith({
    bool? masterEnabled,
    bool? pushEnabled,
    bool? emailEnabled,
    bool? isBusy,
  }) {
    return NotificationSettingsState(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>(
  (ref) => NotificationSettingsNotifier(ref),
);

class NotificationSettingsNotifier extends StateNotifier<NotificationSettingsState> {
  NotificationSettingsNotifier(this._ref) : super(_initial(_ref)) {
    _ref.listen<AuthState>(authProvider, (previous, next) {
      final user = next.user;
      if (user == null) {
        if (state.emailEnabled) {
          state = state.copyWith(emailEnabled: false);
        }
        return;
      }
      if (user.notifyEmail != state.emailEnabled) {
        state = state.copyWith(emailEnabled: user.notifyEmail);
      }
    });
  }

  final Ref _ref;

  static NotificationSettingsState _initial(Ref ref) {
    final user = ref.read(authProvider).user;
    return NotificationSettingsState(
      masterEnabled: NotificationPreferenceStorage.notificationsEnabled,
      pushEnabled: NotificationPreferenceStorage.pushNotificationsEnabled,
      emailEnabled: user?.notifyEmail ?? false,
    );
  }

  /// Master off: clears push + email on server, unregisters FCM for this device.
  /// Master on: re-enables push (requests Android permission) and syncs the token.
  Future<void> setMasterEnabled(bool enabled) async {
    state = state.copyWith(isBusy: true);
    try {
      await NotificationPreferenceStorage.setNotificationsEnabled(enabled);
      if (!enabled) {
        await NotificationPreferenceStorage.setPushNotificationsEnabled(false);
        await _ref.read(authRepositoryProvider).updateNotifyEmail(false);
        await _ref.read(authProvider.notifier).refreshProfile();
        await PushSyncService.unregister();
        state = state.copyWith(
          masterEnabled: false,
          pushEnabled: false,
          emailEnabled: false,
        );
      } else {
        await NotificationPreferenceStorage.setPushNotificationsEnabled(true);
        state = state.copyWith(
          masterEnabled: true,
          pushEnabled: true,
        );
        final ok = await _requestPermissionAndSyncPush();
        if (!ok && Platform.isAndroid) {
          await NotificationPreferenceStorage.setPushNotificationsEnabled(false);
          state = state.copyWith(pushEnabled: false);
        }
      }
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  Future<void> setPushEnabled(bool enabled) async {
    state = state.copyWith(isBusy: true);
    try {
      await NotificationPreferenceStorage.setPushNotificationsEnabled(enabled);
      state = state.copyWith(pushEnabled: enabled);
      if (enabled) {
        final ok = await _requestPermissionAndSyncPush();
        if (!ok && Platform.isAndroid) {
          await NotificationPreferenceStorage.setPushNotificationsEnabled(false);
          state = state.copyWith(pushEnabled: false);
        }
      } else {
        await PushSyncService.unregister();
      }
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  Future<void> setEmailEnabled(bool enabled) async {
    state = state.copyWith(isBusy: true);
    try {
      await _ref.read(authRepositoryProvider).updateNotifyEmail(enabled);
      await _ref.read(authProvider.notifier).refreshProfile();
      state = state.copyWith(emailEnabled: enabled);
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  /// Returns true if push sync was allowed (permission granted on Android, or not Android).
  Future<bool> _requestPermissionAndSyncPush() async {
    if (Platform.isAndroid) {
      var st = await Permission.notification.status;
      if (!st.isGranted) {
        st = await Permission.notification.request();
      }
      if (!st.isGranted) {
        return false;
      }
    }
    await PushSyncService.sync();
    return true;
  }
}
