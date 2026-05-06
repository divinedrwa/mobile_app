import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/models/pre_approved_visitor_model.dart';

/// Success screen after pre-approving visitor
class VisitorSuccessScreen extends StatelessWidget {
  const VisitorSuccessScreen({super.key, required this.visitor});

  final PreApprovedVisitorModel visitor;

  bool get _hasPasscode {
    final otp = visitor.passcode?.trim();
    return otp != null && otp.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final qrData = _qrPayload();

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: DesignColors.surface,
        foregroundColor: DesignColors.textPrimary,
        centerTitle: true,
        title: Text(
          'Visitor approved',
          style: DesignTypography.headingM.copyWith(fontSize: 17),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _exitToResidentHome(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DesignSpacing.lg),
        child: Column(
          children: [
            Icon(
              _hasPasscode ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              size: 80,
              color: _hasPasscode ? DesignColors.success : DesignColors.warning,
            ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
            const SizedBox(height: DesignSpacing.md),
            Text(
              _hasPasscode
                  ? 'Visitor pre-approved'
                  : 'Pass created with a warning',
              style: DesignTypography.headingL.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: DesignSpacing.sm),
            Text(
              _hasPasscode
                  ? 'Share the passcode with ${visitor.name}'
                  : 'The visitor was saved, but no passcode came back from the server.',
              style: DesignTypography.body.copyWith(
                color: DesignColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: DesignSpacing.xl),
            Container(
              decoration: DesignComponents.cardDecoration(boxShadow: DesignElevation.md),
              padding: const EdgeInsets.all(DesignSpacing.lg),
              child: Column(
                children: [
                  Text(
                    '6-digit passcode',
                    style: DesignTypography.headingM.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: DesignSpacing.md),
                  Text(
                    _hasPasscode ? visitor.passcode!.trim() : 'Unavailable',
                    style: DesignTypography.headingXL.copyWith(
                      fontSize: 32,
                      letterSpacing: _hasPasscode ? 8 : 1,
                      color: _hasPasscode
                          ? DesignColors.primary
                          : DesignColors.warning,
                    ),
                  ),
                  const SizedBox(height: DesignSpacing.md),
                  if (visitor.passcodeExpiry != null)
                    _InfoStrip(
                      icon: Icons.schedule_rounded,
                      text:
                          'Valid until ${DateFormat('dd MMM yyyy, hh:mm a').format(visitor.passcodeExpiry!.toLocal())}',
                    ),
                  if (!_hasPasscode) ...[
                    if (visitor.passcodeExpiry != null)
                      const SizedBox(height: DesignSpacing.md),
                    const _InfoStrip(
                      icon: Icons.info_outline_rounded,
                      text:
                          'Ask security to use visitor name and flat details until passcode sync is fixed.',
                      warning: true,
                    ),
                  ],
                  const SizedBox(height: DesignSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy_rounded, size: 20),
                          label: const Text('Copy'),
                          onPressed: _hasPasscode
                              ? () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text: visitor.passcode!.trim(),
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      content: const Text('Passcode copied'),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                }
                              : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: DesignColors.textPrimary,
                            side: const BorderSide(color: DesignColors.border),
                            padding: const EdgeInsets.symmetric(vertical: DesignSpacing.md),
                            shape: RoundedRectangleBorder(
                              borderRadius: DesignRadius.borderMD,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: DesignSpacing.md),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.ios_share_rounded, size: 20),
                          label: const Text('Share'),
                          onPressed: _hasPasscode ? _sharePasscode : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: DesignColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: DesignSpacing.md),
                            shape: RoundedRectangleBorder(
                              borderRadius: DesignRadius.borderMD,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
            const SizedBox(height: DesignSpacing.lg),
            Container(
              decoration: DesignComponents.cardDecoration(boxShadow: DesignElevation.md),
              padding: const EdgeInsets.all(DesignSpacing.lg),
              child: Column(
                children: [
                  Text(
                    'QR code',
                    style: DesignTypography.headingM.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: DesignSpacing.md),
                  if (_hasPasscode)
                    Container(
                      padding: const EdgeInsets.all(DesignSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: DesignRadius.borderMD,
                        border: Border.all(color: DesignColors.borderLight),
                      ),
                      child: QrImageView(
                        data: qrData!,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                      ),
                    )
                  else
                    Container(
                      width: 200,
                      padding: const EdgeInsets.all(DesignSpacing.lg),
                      decoration: BoxDecoration(
                        color: DesignColors.surfaceSoft,
                        borderRadius: DesignRadius.borderMD,
                        border: Border.all(color: DesignColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.qr_code_2_rounded,
                            size: 44,
                            color: DesignColors.textTertiary,
                          ),
                          const SizedBox(height: DesignSpacing.sm),
                          Text(
                            'QR unavailable until a passcode is issued.',
                            textAlign: TextAlign.center,
                            style: DesignTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: DesignSpacing.sm),
                  Text(
                    _hasPasscode
                        ? 'Guards can scan this at the gate'
                        : 'QR appears once a passcode exists',
                    style: DesignTypography.caption,
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),
            const SizedBox(height: DesignSpacing.lg),
            Container(
              decoration: DesignComponents.cardDecoration(),
              padding: const EdgeInsets.all(DesignSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visitor details',
                    style: DesignTypography.headingM.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: DesignSpacing.md),
                  _buildDetailRow(context, 'Name', visitor.name),
                  _buildDetailRow(context, 'Phone', visitor.phone),
                  _buildDetailRow(context, 'Type', visitor.type.value),
                  if (visitor.purpose != null &&
                      visitor.purpose!.trim().isNotEmpty)
                    _buildDetailRow(context, 'Purpose', visitor.purpose!),
                  _buildDetailRow(
                    context,
                    'Visit date',
                    DateFormat('dd MMM yyyy').format(visitor.visitDate),
                  ),
                  if (visitor.visitTime != null)
                    _buildDetailRow(context, 'Visit time', visitor.visitTime!),
                  if (visitor.passcodeExpiry != null)
                    _buildDetailRow(
                      context,
                      'Pass expires',
                      DateFormat(
                        'dd MMM yyyy, hh:mm a',
                      ).format(visitor.passcodeExpiry!.toLocal()),
                    ),
                ],
              ),
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: DesignSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  context.push('/resident/my-pre-approved-visitors');
                },
                icon: const Icon(Icons.list_alt_rounded),
                label: const Text('My pre-approved visitors'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DesignColors.textPrimary,
                  side: const BorderSide(color: DesignColors.border),
                  padding: const EdgeInsets.symmetric(vertical: DesignSpacing.md + 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: DesignRadius.borderMD,
                  ),
                ),
              ),
            ),
            const SizedBox(height: DesignSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _exitToResidentHome(context),
                style: FilledButton.styleFrom(
                  backgroundColor: DesignColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: DesignSpacing.md + 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: DesignRadius.borderMD,
                  ),
                ),
                child: Text(
                  'Done',
                  style: DesignTypography.label.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: DesignTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _exitToResidentHome(BuildContext context) {
    if (!context.mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    }
    if (!context.mounted) return;
    context.go('/resident');
  }

  void _sharePasscode() {
    final otp = visitor.passcode!.trim();
    final expiry = visitor.passcodeExpiry != null
        ? '\nValid until: ${DateFormat('dd MMM yyyy, hh:mm a').format(visitor.passcodeExpiry!.toLocal())}'
        : '';
    final message =
        '''
Visitor Pass for ${visitor.name}

Passcode: $otp

Date: ${DateFormat('dd MMM yyyy').format(visitor.visitDate)}
${visitor.visitTime != null ? 'Time: ${visitor.visitTime}\n' : ''}$expiry

Please show this code at the gate.
- ${AppConstants.appName}
''';

    Share.share(message);
  }

  String? _qrPayload() {
    final otp = visitor.passcode?.trim();
    if (otp == null || otp.isEmpty) return null;

    final payload = <String, String>{
      'source': 'resident_preapproved_v1',
      'otp': otp,
      'name': visitor.name,
      'phone': visitor.phone,
    };
    final villaId = visitor.villaId?.trim();
    if (villaId != null && villaId.isNotEmpty) {
      payload['villaId'] = villaId;
    }
    return jsonEncode(payload);
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({
    required this.icon,
    required this.text,
    this.warning = false,
  });

  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final bg = warning ? const Color(0xFFFFF7ED) : const Color(0xFFEFF6FF);
    final fg = warning ? DesignColors.warning : DesignColors.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DesignSpacing.md),
      decoration: BoxDecoration(color: bg, borderRadius: DesignRadius.borderMD),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: DesignSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: DesignTypography.bodySmall.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
