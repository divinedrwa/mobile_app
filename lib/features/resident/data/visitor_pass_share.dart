import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import 'models/pre_approved_visitor_model.dart';
import 'repositories/visitor_repository.dart';

/// Builds the full visitor pass text (link + OTP + validity) for SMS/WhatsApp/share sheet.
String buildVisitorPassShareMessage(PreApprovedVisitorModel visitor) {
  final name = visitor.name.trim();
  final otp = visitor.passcode?.trim() ?? '';
  final url = visitor.publicPassUrl?.trim();
  final expiry = visitor.passcodeExpiry;
  final visitDate = DateFormat('dd MMM yyyy').format(visitor.visitDate);
  final lines = <String>[
    'Visitor Pass for $name',
    '',
    if (url != null && url.isNotEmpty) ...[
      'Open visitor pass:',
      url,
      '',
    ],
    if (otp.isNotEmpty) ...['Passcode: $otp', ''],
    'Date: $visitDate',
    if (visitor.visitTime != null && visitor.visitTime!.trim().isNotEmpty)
      'Time: ${visitor.visitTime!.trim()}',
    if (expiry != null)
      'Valid until: ${DateFormat('dd MMM yyyy, hh:mm a').format(expiry.toLocal())}',
    if (visitor.flatLabel != null && visitor.flatLabel!.trim().isNotEmpty)
      'Flat: ${visitor.flatLabel!.trim()}',
    '',
    'Show the QR link or passcode at the gate.',
    '- ${AppConstants.appName}',
  ];
  return lines.join('\n').trim();
}

/// Ensures a public pass URL exists. When [rotate] is true, always issues a new link.
Future<PreApprovedVisitorModel> ensureVisitorPassShareUrl(
  VisitorRepository repository,
  PreApprovedVisitorModel visitor, {
  bool rotate = false,
}) async {
  final existing = visitor.publicPassUrl?.trim();
  if (!rotate && existing != null && existing.isNotEmpty) return visitor;
  final id = visitor.id?.trim();
  if (id == null || id.isEmpty) return visitor;
  final url = await repository.issuePreApprovedShareLink(id);
  return visitor.copyWith(publicPassUrl: url);
}

/// Rotates the share link and opens the native share sheet.
Future<void> shareVisitorPassRecord(
  VisitorRepository repository,
  PreApprovedVisitorModel visitor, {
  bool rotateLink = false,
}) async {
  final ready = await ensureVisitorPassShareUrl(
    repository,
    visitor,
    rotate: rotateLink,
  );
  await Share.share(buildVisitorPassShareMessage(ready));
}

/// Revokes the public share link (OTP still works at gate).
Future<PreApprovedVisitorModel> revokeVisitorPassShareUrl(
  VisitorRepository repository,
  PreApprovedVisitorModel visitor,
) async {
  final id = visitor.id?.trim();
  if (id == null || id.isEmpty) return visitor;
  await repository.revokePreApprovedShareLink(id);
  return visitor.copyWith(publicPassUrl: null);
}
