import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/resident/presentation/providers/resident_tab_provider.dart';

/// Opens a banner [actionUrl] — https links externally, societyapp:// and /resident paths in-app.
Future<void> openBannerActionUrl(BuildContext context, String raw) async {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return;

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    final uri = Uri.tryParse(trimmed);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (context.mounted) {
      _snack(context, 'Could not open link');
    }
    return;
  }

  if (trimmed.startsWith('/')) {
    if (!context.mounted) return;
    try {
      await context.push(trimmed);
    } catch (_) {
      if (context.mounted) _snack(context, 'Could not open: $trimmed');
    }
    return;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.scheme.toLowerCase() == 'societyapp') {
    if (!context.mounted) return;
    await _openSocietyAppUri(context, uri);
    return;
  }

  if (!context.mounted) return;
  try {
    await context.push(trimmed.startsWith('/') ? trimmed : '/$trimmed');
  } catch (_) {
    if (context.mounted) _snack(context, 'Could not open link');
  }
}

Future<void> _openSocietyAppUri(BuildContext context, Uri uri) async {
  final container = ProviderScope.containerOf(context);

  switch (uri.host.toLowerCase()) {
    case 'home':
      container.read(currentTabProvider.notifier).state = 0;
      context.go('/resident');
      return;
    case 'community':
      final segment =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.first.toLowerCase() : 'notices';
      final subTab = switch (segment) {
        'polls' => 1,
        'events' => 2,
        'docs' => 3,
        _ => 0,
      };
      container.read(communitySubTabIndexProvider.notifier).state =
          subTab.clamp(0, 3);
      container.read(currentTabProvider.notifier).state = 1;
      context.go('/resident');
      return;
    case 'visitors':
      if (uri.pathSegments.contains('pre-approve')) {
        await context.push('/resident/pre-approve-visitor');
      } else {
        await context.push('/resident/visitor-hub');
      }
      return;
    case 'maintenance':
      await context.push('/resident/maintenance');
      return;
    case 'amenities':
      await context.push('/resident/amenities');
      return;
    case 'complaints':
      if (uri.pathSegments.contains('new')) {
        await context.push('/resident/complaint');
      } else {
        await context.push('/resident/my-complaints');
      }
      return;
    case 'parcels':
      await context.push('/resident/parcels');
      return;
    case 'expenses':
      await context.push('/resident/expenses');
      return;
    case 'directory':
      await context.push('/resident/directory');
      return;
    case 'sos':
      await context.push('/resident/sos');
      return;
    case 'notices':
      await context.push('/resident/notices');
      return;
    default:
      _snack(context, 'Unknown app link');
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(message),
    ),
  );
}
