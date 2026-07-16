import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/dio_exception_mapper.dart';
import '../../../../../core/utils/pdf_share.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../data/models/maintenance_due_model.dart';
import '../../../data/providers/maintenance_provider.dart';
import '../../../data/providers/upi_payment_provider.dart';
import '../../../data/services/maintenance_invoice_pdf.dart';
import '../../widgets/maintenance/invoice_actions.dart';

/// Single entry point for invoice download across the maintenance screens.
///
/// Whether the invoice was just built or was already cached, the resident is
/// offered the same actions — View / Share / Regenerate — so a fresh download
/// behaves identically to reopening a cached one (no auto-share, no rebuild
/// every time).
Future<void> downloadOrViewInvoice({
  required BuildContext context,
  required WidgetRef ref,
  required MaintenanceDueModel m,
  required void Function(bool busy) setBusy,
}) async {
  final user = ref.read(authProvider).user;
  final filename = invoiceCacheFilename(
    m,
    userId: user?.id,
    villaId: user?.villaId,
  );

  Future<void> generate() async {
    final currentUser = ref.read(authProvider).user;
    setBusy(true);
    String? savedPath;
    try {
      Map<String, dynamic>? cfg;
      try {
        cfg = await ref.read(upiConfigProvider.future);
      } catch (_) {
        cfg = null;
      }
      final bytes = await buildInvoiceForPayment(
        repo: ref.read(maintenanceRepositoryProvider),
        user: currentUser,
        m: m,
        generatedAt: DateTime.now(),
        upiId: cfg?['upiVpa']?.toString(),
        payeeName: cfg?['payeeName']?.toString(),
        upiQrCodeUrl: cfg?['upiQrCodeUrl']?.toString(),
        letterheadUrl: cfg?['letterheadUrl']?.toString(),
        signatureUrl: cfg?['signatureUrl']?.toString(),
        stampUrl: cfg?['stampUrl']?.toString(),
        societyAddress: cfg?['societyAddress']?.toString(),
      );
      savedPath = await savePdfToCache(bytes, filename);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFacingMessage(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setBusy(false);
    }
    // After a successful build, surface the same actions as a cached invoice.
    // (On web savePdfToCache triggers a direct download and returns an empty
    // path, so there's nothing to view/share in-app.)
    if (savedPath != null && savedPath.isNotEmpty && context.mounted) {
      await showInvoiceActionsSheet(context, savedPath, onRegenerate: generate);
    }
  }

  final cached = await cachedPdfPath(filename);
  if (cached != null && context.mounted) {
    await showInvoiceActionsSheet(context, cached, onRegenerate: generate);
  } else if (cached == null) {
    await generate();
  }
}
