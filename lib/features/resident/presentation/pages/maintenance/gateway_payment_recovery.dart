import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/routing/app_navigator_keys.dart';
import '../../../data/providers/maintenance_provider.dart';
import '../../../data/repositories/maintenance_repository.dart';
import '../../../data/services/payment_orchestrator.dart';

/// @deprecated Use [PaymentOrchestrator.recoverPendingPayment] — kept for imports during migration.
class GatewayPaymentRecovery {
  GatewayPaymentRecovery._();

  static Future<void> tryRecover({
    BuildContext? context,
    WidgetRef? ref,
    MaintenanceRepository? repository,
    bool navigate = true,
  }) =>
      PaymentOrchestrator.recoverPendingPayment(
        context: context,
        ref: ref,
        repository: repository,
        navigate: navigate,
      );
}
