import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../network/dio_client.dart';
import '../theme/design_tokens.dart';
import '../utils/storage_service.dart';

/// RFC 1918 / loopback / link-local — hosts where http:// is acceptable for
/// LAN development. Anything else is treated as a public host that must use
/// HTTPS, otherwise login credentials and JWTs travel in the clear.
bool _isPrivateOrLoopbackHost(String host) {
  final h = host.toLowerCase();
  if (h.isEmpty) return false;
  if (h == 'localhost' || h == '127.0.0.1' || h == '::1') return true;
  // Android emulator alias for the dev host machine.
  if (h == '10.0.2.2') return true;
  if (h.startsWith('10.')) return true;
  if (h.startsWith('192.168.')) return true;
  if (RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(h)) return true;
  if (h.startsWith('169.254.')) return true;
  if (h.endsWith('.local')) return true;
  return false;
}

/// Lets the user point the app at any reachable API (LAN, VPN, cellular, public HTTPS).
Future<void> showApiServerConfigDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => const _ApiServerDialog(),
  );
}

class _ApiServerDialog extends StatefulWidget {
  const _ApiServerDialog();

  @override
  State<_ApiServerDialog> createState() => _ApiServerDialogState();
}

class _ApiServerDialogState extends State<_ApiServerDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: StorageService.getString(AppConstants.keyApiBaseUrl) ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = _controller.text.trim();
    if (v.isEmpty) {
      await StorageService.remove(AppConstants.keyApiBaseUrl);
      AppConstants.setRuntimeBaseUrlOverride(null);
    } else {
      // Reject plain-HTTP URLs to public hosts. The default normalization
      // adds `http://` when no scheme is typed, which would silently let
      // the user point the app at an attacker-controlled host (e.g. via
      // QR code) and have credentials/JWTs travel in the clear.
      final lower = v.toLowerCase();
      final explicitlyHttps = lower.startsWith('https://');
      String host = '';
      try {
        final parsed = Uri.parse(
          lower.startsWith('http://') || lower.startsWith('https://')
              ? lower
              : 'http://$lower',
        );
        host = parsed.host;
      } catch (_) {
        host = '';
      }
      if (!explicitlyHttps && !_isPrivateOrLoopbackHost(host)) {
        if (kReleaseMode) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Refusing non-HTTPS API URL. Use https:// or a private LAN host.',
              ),
            ),
          );
          return;
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Insecure API URL'),
            content: Text(
              'You entered "$v" which would be reached over plain HTTP. '
              'Login credentials and the auth token will travel unencrypted. '
              'Continue anyway? (Allowed in debug builds only.)',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Use anyway'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }

      final n = AppConstants.normalizeApiBaseUrl(v);
      await StorageService.setString(AppConstants.keyApiBaseUrl, n);
      AppConstants.setRuntimeBaseUrlOverride(n);
    }
    DioClient.reset();
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Using API base: ${AppConstants.baseUrl}')),
    );
  }

  Future<void> _clear() async {
    await StorageService.remove(AppConstants.keyApiBaseUrl);
    AppConstants.setRuntimeBaseUrlOverride(null);
    DioClient.reset();
    _controller.clear();
    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reset to default: ${AppConstants.baseUrl}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('API server'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Simulators (leave empty or Clear saved): Android → ${AppConstants.simulatorAndroidApiBase}, iOS → ${AppConstants.simulatorIosApiBase}. A saved URL overrides these.',
              style: TextStyle(fontSize: 12, color: DesignColors.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Production: use your HTTPS API host (scheme + domain). `/api` is added automatically if omitted.',
              style: TextStyle(fontSize: 13, color: DesignColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'https://your-server.com/api',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            Text(
              'Active: ${AppConstants.baseUrl}',
              style: const TextStyle(fontSize: 12, color: DesignColors.textSecondary),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        TextButton(onPressed: _clear, child: const Text('Clear saved')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
