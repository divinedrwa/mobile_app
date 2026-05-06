import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_help_model.dart';
import '../repositories/daily_help_repository.dart';

class DailyHelpNotifier
    extends StateNotifier<AsyncValue<List<DailyHelpModel>>> {
  DailyHelpNotifier(this._repository) : super(const AsyncValue.loading()) {
    fetchDailyHelp();
  }

  final DailyHelpRepository _repository;

  Future<void> fetchDailyHelp() async {
    state = const AsyncValue.loading();
    try {
      final items = await _repository.getDailyHelp();
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> addDailyHelp({
    required String name,
    required String type,
    required String phone,
    String? address,
  }) async {
    try {
      await _repository.addDailyHelp(
        name: name,
        type: type,
        phone: phone,
        address: address,
      );
      await fetchDailyHelp();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeDailyHelp(String assignmentId) async {
    try {
      await _repository.removeDailyHelp(assignmentId);
      await fetchDailyHelp();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final dailyHelpProvider =
    StateNotifierProvider<DailyHelpNotifier, AsyncValue<List<DailyHelpModel>>>(
      (ref) => DailyHelpNotifier(DailyHelpRepository()),
    );
