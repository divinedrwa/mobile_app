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

/// Masks a phone number showing first 2 and last 2 digits: "98****34".
/// Returns the original string if it has fewer than 6 characters.
String maskPhone(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 6) return raw;
  return '${digits.substring(0, 2)}${'*' * (digits.length - 4)}${digits.substring(digits.length - 2)}';
}
