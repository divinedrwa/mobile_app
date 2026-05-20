import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/upi_payment_model.dart';
import '../repositories/upi_payment_repository.dart';

final upiPaymentRepositoryProvider =
    Provider<UpiPaymentRepository>((ref) => UpiPaymentRepository());

final upiConfigProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(upiPaymentRepositoryProvider).getUpiConfig();
});

final myUpiPaymentsProvider =
    FutureProvider.autoDispose<List<UpiPaymentModel>>((ref) async {
  return ref.watch(upiPaymentRepositoryProvider).getMyUpiPayments();
});
