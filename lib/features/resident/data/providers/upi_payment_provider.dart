import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/utils/provider_cache.dart';
import '../models/upi_payment_model.dart';
import '../repositories/upi_payment_repository.dart';

final upiPaymentRepositoryProvider =
    Provider<UpiPaymentRepository>((ref) => UpiPaymentRepository());

final upiConfigProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  // Society UPI config (VPA/QR/payee) is effectively static — cache it.
  cacheFor(ref, const Duration(minutes: 10));
  return ref.watch(upiPaymentRepositoryProvider).getUpiConfig();
});

final myUpiPaymentsProvider =
    FutureProvider.autoDispose<List<UpiPaymentModel>>((ref) async {
  cacheFor(ref, const Duration(minutes: 1));
  return ref.watch(upiPaymentRepositoryProvider).getMyUpiPayments();
});
