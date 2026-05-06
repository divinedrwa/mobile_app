import 'package:url_launcher/url_launcher.dart';

/// Opens the device dialer when [raw] contains enough digits (e.g. 10+).
Future<bool> launchDial(String? raw) async {
  if (raw == null || raw.trim().isEmpty) return false;
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 10) return false;
  final uri = Uri(scheme: 'tel', path: digits);
  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri);
}
