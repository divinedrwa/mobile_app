import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../resident/presentation/pages/legal_markdown_screen.dart';
import '../../../resident/presentation/pages/legal_webview_screen.dart';
import '../../data/legal_repository.dart';
import '../providers/legal_provider.dart';

/// L2 — mandatory Terms/Privacy re-acceptance gate.
///
/// Shown by the router whenever `authProvider.requiresLegalAcceptance` is true
/// (updated legal docs, or a user who never recorded consent). The user must view
/// and accept, or log out — they cannot dismiss it to reach the app.
class LegalConsentGateScreen extends ConsumerStatefulWidget {
  const LegalConsentGateScreen({super.key});

  @override
  ConsumerState<LegalConsentGateScreen> createState() =>
      _LegalConsentGateScreenState();
}

class _LegalConsentGateScreenState
    extends ConsumerState<LegalConsentGateScreen> {
  bool _agreed = false;
  bool _submitting = false;
  String? _error;

  Future<void> _accept(LegalConsentStatus status) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(legalRepositoryProvider).accept(
            termsVersion: status.currentTermsVersion,
            privacyVersion: status.currentPrivacyVersion,
            appVersion: 'mobile',
          );
      await ref.read(authProvider.notifier).markLegalAccepted();
      // Router redirect (driven by the auth-state change) navigates home.
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Could not record your acceptance. Please try again.';
        });
      }
    }
  }

  void _openDoc({
    required String title,
    required String assetPath,
    String? hostedUrl,
  }) {
    final url = hostedUrl?.trim() ?? '';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => url.isNotEmpty
            ? LegalWebViewScreen(title: title, url: url)
            : LegalMarkdownScreen(title: title, assetPath: assetPath),
      ),
    );
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusAsync = ref.watch(legalStatusProvider);

    // Block Android back / swipe-dismiss — accepting or logging out are the only exits.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: statusAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _RetryView(
              onRetry: () => ref.invalidate(legalStatusProvider),
              onLogout: _logout,
            ),
            data: (status) => _buildContent(context, theme, status),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    LegalConsentStatus status,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Icon(Icons.gavel_outlined, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'We\'ve updated our terms',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Our Terms & Conditions and Privacy Policy have changed — including how '
            'online maintenance payments are handled. Please review and accept to '
            'continue using the app.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                _DocTile(
                  icon: Icons.description_outlined,
                  title: 'Terms & Conditions',
                  subtitle: 'Version ${status.currentTermsVersion}',
                  onTap: () => _openDoc(
                    title: 'Terms & Conditions',
                    assetPath: AppConstants.termsConditionsAsset,
                    hostedUrl:
                        status.termsUrl ?? AppConstants.termsConditionsPublicUrl,
                  ),
                ),
                const SizedBox(height: 12),
                _DocTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'Version ${status.currentPrivacyVersion}',
                  onTap: () => _openDoc(
                    title: 'Privacy Policy',
                    assetPath: AppConstants.privacyPolicyAsset,
                    hostedUrl:
                        status.privacyUrl ?? AppConstants.privacyPolicyPublicUrl,
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            Text(
              _error!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          CheckboxListTile(
            value: _agreed,
            onChanged: _submitting
                ? null
                : (v) => setState(() => _agreed = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'I have read and agree to the Terms & Conditions and Privacy Policy.',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: (_agreed && !_submitting) ? () => _accept(status) : null,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Accept & Continue'),
          ),
          TextButton(
            onPressed: _submitting ? null : _logout,
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _RetryView extends StatelessWidget {
  const _RetryView({required this.onRetry, required this.onLogout});

  final VoidCallback onRetry;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_outlined, size: 40),
          const SizedBox(height: 16),
          const Text(
            'Could not load the updated terms. Check your connection and try again.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
          TextButton(onPressed: onLogout, child: const Text('Log out')),
        ],
      ),
    );
  }
}
