import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/utils/provider_cache.dart';
import '../models/payment_method_model.dart';
import '../repositories/payment_methods_repository.dart';

/// Single source of truth for the payment-methods repository and its list
/// provider. Previously duplicated across cycle_detail_screen,
/// maintenance_hub_screen, my_dues_screen, and payment_method_selection_screen.
final paymentMethodsRepoProvider =
    Provider<PaymentMethodsRepository>((ref) => PaymentMethodsRepository());

final paymentMethodsListProvider =
    FutureProvider.autoDispose<List<PaymentMethodModel>>((ref) async {
  // Config-like data that almost never changes — cache so the hub/dues/payment
  // screens don't re-request it on every visit.
  cacheFor(ref, const Duration(minutes: 10));
  return ref.watch(paymentMethodsRepoProvider).getPaymentMethods();
});
