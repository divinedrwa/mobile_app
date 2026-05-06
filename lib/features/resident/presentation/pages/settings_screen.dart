import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/security/secure_credentials_store.dart';
import '../../../../core/services/biometric_auth_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/play_store_launch.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/notification_settings_notifier.dart';
import 'legal_webview_screen.dart';

/// Settings Screen
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _busyBiometric = false;

  @override
  void initState() {
    super.initState();
    _biometricEnabled =
        StorageService.getBool(AppConstants.keyBiometricLoginEnabled) == true;
  }

  Future<void> _setBiometricEnabled(bool enable) async {
    setState(() => _busyBiometric = true);
    try {
      final bio = BiometricAuthService();
      if (enable) {
        if (!await bio.deviceCanUseBiometric()) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric sign-in is not available on this device.'),
            ),
          );
          return;
        }
        final ok = await bio.authenticate(
          localizedReason: 'Enable biometric login for ${AppConstants.appName}',
        );
        if (!ok) return;
        await StorageService.setBool(AppConstants.keyBiometricLoginEnabled, true);
        if (!mounted) return;
        setState(() => _biometricEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Enabled. Sign in once with your password to finish setup.',
            ),
          ),
        );
      } else {
        await SecureCredentialsStore.instance.clearCredentials();
        await StorageService.setBool(AppConstants.keyBiometricLoginEnabled, false);
        if (!mounted) return;
        setState(() => _biometricEnabled = false);
      }
    } finally {
      if (mounted) setState(() => _busyBiometric = false);
    }
  }

  void _openLegalWebView(String title, String url) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LegalWebViewScreen(title: title, url: url),
      ),
    );
  }

  Future<void> _openPlayStore() async {
    final ok = await openPlayStoreListing();
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the store.')),
    );
  }

  Future<void> _runNotificationAction(Future<void> Function() action) async {
    try {
      await action();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notif = ref.watch(notificationSettingsProvider);
    final notificationsEnabled = notif.masterEnabled;
    final pushEnabled = notif.pushEnabled;
    final emailEnabled = notif.emailEnabled;
    final notifBusy = notif.isBusy;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Notifications Section
          Text(
            'Notifications',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Enable Notifications'),
                  subtitle: const Text(
                    'Master switch for push and society email alerts',
                  ),
                  value: notificationsEnabled,
                  onChanged: notifBusy
                      ? null
                      : (value) => _runNotificationAction(
                            () => ref
                                .read(notificationSettingsProvider.notifier)
                                .setMasterEnabled(value),
                          ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Push Notifications'),
                  subtitle: const Text(
                    'Firebase push — registers this device when enabled',
                  ),
                  value: pushEnabled,
                  onChanged: !notificationsEnabled || notifBusy
                      ? null
                      : (value) => _runNotificationAction(
                            () => ref
                                .read(notificationSettingsProvider.notifier)
                                .setPushEnabled(value),
                          ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Email Notifications'),
                  subtitle: const Text(
                    'Society email alerts — saved to your account',
                  ),
                  value: emailEnabled,
                  onChanged: !notificationsEnabled || notifBusy
                      ? null
                      : (value) => _runNotificationAction(
                            () => ref
                                .read(notificationSettingsProvider.notifier)
                                .setEmailEnabled(value),
                          ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Appearance Section (dark mode hidden)
          Text(
            'Appearance',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Language'),
                  subtitle: const Text('English'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showInfoDialog(
                      context,
                      title: 'Language',
                      message: 'Current app language is English.',
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Privacy & Security Section
          Text(
            'Privacy & Security',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showChangePasswordDialog(context),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Biometric login'),
                  subtitle: Text(
                    _biometricEnabled
                        ? 'Use fingerprint, face, or device PIN on the login screen'
                        : 'After enabling, sign in once with your password to save securely',
                  ),
                  value: _biometricEnabled,
                  onChanged: _busyBiometric
                      ? null
                      : (v) {
                          _setBiometricEnabled(v);
                        },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openLegalWebView(
                    'Privacy Policy',
                    AppConstants.privacyPolicyUrl,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms & Conditions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openLegalWebView(
                    'Terms & Conditions',
                    AppConstants.termsConditionsUrl,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // About Section
          Text(
            'About',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('App Version'),
                  subtitle: const Text('1.0.0 (Build 100)'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.rate_review),
                  title: const Text('Rate Us'),
                  subtitle: const Text('Opens Play Store or App Store'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openPlayStore,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Danger Zone
          Card(
            color: Colors.red.withValues(alpha: 0.1),
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Deactivate account',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Deactivate your account — you won’t be able to sign in; data stays with your society',
              ),
              onTap: () {
                _showDeleteAccountDialog(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    var obscureCurrent = true;
    var obscureNew = true;
    var submitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> submit() async {
              final current = currentController.text;
              final next = newController.text.trim();
              final errCurrent = Validators.password(current.trim());
              if (errCurrent != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(errCurrent)),
                );
                return;
              }
              final errNew = Validators.password(next);
              if (errNew != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(errNew)),
                );
                return;
              }
              if (current.trim() == next) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('New password must be different from current password'),
                  ),
                );
                return;
              }
              setLocal(() => submitting = true);
              try {
                await ref.read(authRepositoryProvider).changePassword(
                      currentPassword: current,
                      newPassword: next,
                    );
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                await ref.read(authProvider.notifier).logout();
                if (!context.mounted) return;
                context.go('/login');
              } catch (e) {
                setLocal(() => submitting = false);
                final msg = e is AppException
                    ? e.message
                    : 'Could not change password';
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(msg)),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Text('Change password'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: currentController,
                      obscureText: obscureCurrent,
                      enabled: !submitting,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Current password',
                        suffixIcon: IconButton(
                          tooltip: obscureCurrent ? 'Show' : 'Hide',
                          icon: Icon(
                            obscureCurrent
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: submitting
                              ? null
                              : () =>
                                  setLocal(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newController,
                      obscureText: obscureNew,
                      enabled: !submitting,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => submit(),
                      decoration: InputDecoration(
                        labelText: 'New password',
                        suffixIcon: IconButton(
                          tooltip: obscureNew ? 'Show' : 'Hide',
                          icon: Icon(
                            obscureNew ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: submitting
                              ? null
                              : () => setLocal(() => obscureNew = !obscureNew),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      submitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: submitting ? null : submit,
                  child: submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Change password'),
                ),
              ],
            );
          },
        );
      },
    );

    currentController.dispose();
    newController.dispose();
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var busy = false;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> confirmDeactivate() async {
              setLocal(() => busy = true);
              try {
                await ref.read(authRepositoryProvider).deactivateAccount();
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                await ref.read(authProvider.notifier).logout();
                if (!context.mounted) return;
                context.go('/login');
              } catch (e) {
                setLocal(() => busy = false);
                final msg = e is AppException
                    ? e.message
                    : 'Could not deactivate account';
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(msg)),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Text('Deactivate account?'),
              content: const Text(
                'Your login will be disabled and push alerts stopped. '
                'Your society keeps historical records; an admin can restore access if needed. '
                'This does not erase your data from the society database.',
              ),
              actions: [
                TextButton(
                  onPressed:
                      busy ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: busy ? null : confirmDeactivate,
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Deactivate'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
