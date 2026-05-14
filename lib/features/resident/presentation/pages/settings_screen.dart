import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/security/secure_credentials_store.dart';
import '../../../../core/services/biometric_auth_service.dart';
import '../../../../core/widgets/enterprise_ui.dart';
// TODO: Re-enable when theme toggle is restored in the Appearance section.
// import '../../../../theme/widgets/theme_mode_toggle.dart';
import '../../../../core/utils/play_store_launch.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../core/utils/validators.dart';
import '../../../../theme/context_extensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/notification_settings_notifier.dart';
import 'legal_markdown_screen.dart';
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

  /// Opens bundled Markdown in-app, or a hosted HTTPS page if [publicUrl] is set via `--dart-define`.
  void _openLegalPage({
    required String title,
    required String assetPath,
    String publicUrl = '',
  }) {
    final hosted = publicUrl.trim();
    if (hosted.isNotEmpty) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => LegalWebViewScreen(title: title, url: hosted),
        ),
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            LegalMarkdownScreen(title: title, assetPath: assetPath),
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
        padding: EdgeInsets.fromLTRB(
          context.spacing.s16,
          context.spacing.s12,
          context.spacing.s16,
          context.spacing.s32,
        ),
        children: [
          const EnterpriseInfoBanner(
            icon: Icons.settings_suggest_rounded,
            title: 'Control security, notifications, and legal preferences',
            message:
                'These settings apply to your resident account on this device and help keep access trustworthy and predictable.',
            tone: EnterpriseTone.info,
          ),
          SizedBox(height: context.spacing.s24),
          _SettingsSection(
            title: 'Notifications',
            subtitle: 'Choose how this device receives resident alerts.',
            children: [
              _SettingsSwitchTile(
                icon: Icons.notifications_outlined,
                title: 'Enable notifications',
                subtitle: 'Master switch for push and society email alerts',
                value: notificationsEnabled,
                onChanged: notifBusy
                    ? null
                    : (value) => _runNotificationAction(
                          () => ref
                              .read(notificationSettingsProvider.notifier)
                              .setMasterEnabled(value),
                        ),
              ),
              _SettingsSwitchTile(
                icon: Icons.phone_android_outlined,
                title: 'Push notifications',
                subtitle:
                    'Register this device for real-time security and society updates',
                value: pushEnabled,
                onChanged: !notificationsEnabled || notifBusy
                    ? null
                    : (value) => _runNotificationAction(
                          () => ref
                              .read(notificationSettingsProvider.notifier)
                              .setPushEnabled(value),
                        ),
              ),
              _SettingsSwitchTile(
                icon: Icons.email_outlined,
                title: 'Email notifications',
                subtitle: 'Send society alerts to your account email',
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
          SizedBox(height: context.spacing.s24),
          _SettingsSection(
            title: 'Appearance',
            subtitle:
                'Keep reading and navigation simple across all resident screens.',
            children: [
              _SettingsTile(
                icon: Icons.language_rounded,
                title: 'Language',
                subtitle: 'English',
                onTap: () {
                  _showInfoDialog(
                    context,
                    title: 'Language',
                    message: 'Current app language is English.',
                  );
                },
              ),
              _SettingsTile(
                icon: Icons.light_mode_outlined,
                title: 'Theme',
                subtitle:
                    'Light mode is currently active across the mobile experience',
                onTap: () {
                  _showInfoDialog(
                    context,
                    title: 'Theme',
                    message:
                        'Dark and system theme options are being refined for a future update.',
                  );
                },
              ),
            ],
          ),
          SizedBox(height: context.spacing.s24),
          _SettingsSection(
            title: 'Privacy & Security',
            subtitle:
                'Protect sign-in, review legal documents, and manage access safely.',
            children: [
              _SettingsTile(
                icon: Icons.lock_outline_rounded,
                title: 'Change password',
                subtitle: 'Update your resident login password',
                onTap: () => _showChangePasswordDialog(context),
              ),
              _SettingsSwitchTile(
                icon: Icons.fingerprint,
                title: 'Biometric login',
                subtitle: _biometricEnabled
                    ? 'Use fingerprint, face, or device PIN on the login screen'
                    : 'Enable and sign in once with password to finish setup',
                value: _biometricEnabled,
                onChanged: _busyBiometric ? null : _setBiometricEnabled,
              ),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy policy',
                subtitle: 'Review how account and society data is handled',
                onTap: () => _openLegalPage(
                  title: 'Privacy Policy',
                  assetPath: AppConstants.privacyPolicyAsset,
                  publicUrl: AppConstants.privacyPolicyPublicUrl,
                ),
              ),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Terms & conditions',
                subtitle: 'Review legal terms for using the mobile app',
                onTap: () => _openLegalPage(
                  title: 'Terms & Conditions',
                  assetPath: AppConstants.termsConditionsAsset,
                  publicUrl: AppConstants.termsConditionsPublicUrl,
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing.s24),
          _SettingsSection(
            title: 'About',
            subtitle: 'Product information and store links.',
            children: [
              const _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'App version',
                subtitle: AppConstants.appVersion,
              ),
              _SettingsTile(
                icon: Icons.rate_review_outlined,
                title: 'Rate the app',
                subtitle: 'Open the app store listing for this release',
                onTap: _openPlayStore,
              ),
            ],
          ),
          SizedBox(height: context.spacing.s24),
          EnterpriseInfoBanner(
            icon: Icons.delete_forever_rounded,
            title: 'Deactivate account',
            message:
                'Disable sign-in for this resident account while keeping society records intact.',
            tone: EnterpriseTone.danger,
            actionLabel: 'Review',
            onAction: () => _showDeleteAccountDialog(context),
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
                      autofocus: false,
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EnterpriseSectionHeader(title: title, subtitle: subtitle),
        SizedBox(height: context.spacing.s12),
        EnterprisePanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.spacing.s16,
                    vertical: context.spacing.s4,
                  ),
                  child: children[i],
                ),
                if (i != children.length - 1)
                  Divider(height: 1, color: context.surface.border),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: context.brand.primary),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: context.text.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.text.secondary,
            ),
      ),
      trailing: onTap == null
          ? null
          : Icon(Icons.chevron_right_rounded, color: context.text.tertiary),
      onTap: onTap,
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: context.spacing.s12),
          child: Icon(icon, color: context.brand.primary),
        ),
        SizedBox(width: context.spacing.s12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: context.spacing.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: context.text.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                SizedBox(height: context.spacing.s4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.text.secondary,
                      ),
                ),
              ],
            ),
          ),
        ),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }
}
