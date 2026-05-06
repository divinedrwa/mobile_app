import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vendor_model.dart';
import '../repositories/vendor_repository.dart';

class VendorNotifier extends StateNotifier<AsyncValue<List<VendorModel>>> {
  VendorNotifier(this._repository) : super(const AsyncValue.loading()) {
    fetchVendors();
  }

  final VendorRepository _repository;

  Future<void> fetchVendors() async {
    state = const AsyncValue.loading();
    try {
      final items = await _repository.getVendors();
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final vendorProvider =
    StateNotifierProvider<VendorNotifier, AsyncValue<List<VendorModel>>>(
      (ref) => VendorNotifier(VendorRepository()),
    );
