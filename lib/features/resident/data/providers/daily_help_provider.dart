import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/exceptions.dart';
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

  Future<String?> addDailyHelp({
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
      return null;
    } catch (e) {
      return e is AppException ? e.message : 'Something went wrong. Please try again.';
    }
  }

  Future<String?> removeDailyHelp(String assignmentId) async {
    try {
      await _repository.removeDailyHelp(assignmentId);
      await fetchDailyHelp();
      return null;
    } catch (e) {
      return e is AppException ? e.message : 'Something went wrong. Please try again.';
    }
  }
}

final dailyHelpProvider =
    StateNotifierProvider<DailyHelpNotifier, AsyncValue<List<DailyHelpModel>>>(
      (ref) => DailyHelpNotifier(DailyHelpRepository()),
    );
