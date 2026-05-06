import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../network/dio_client.dart';
import '../theme/design_tokens.dart';
import '../utils/storage_service.dart';

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
            Text(
              'Simulators (leave empty or Clear saved): Android → ${AppConstants.simulatorAndroidApiBase}, iOS → ${AppConstants.simulatorIosApiBase}. A saved URL overrides these.',
              style: TextStyle(fontSize: 12, color: DesignColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Other devices: any reachable URL (Wi‑Fi, cellular, VPN). Include /api when your server uses it.',
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
              style: TextStyle(fontSize: 12, color: DesignColors.textSecondary),
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
