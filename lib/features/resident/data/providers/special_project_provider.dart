import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/special_project_model.dart';
import '../repositories/special_project_repository.dart';

// ── Resident providers ────────────────────────────────────

class ResidentSpecialProjectNotifier
    extends StateNotifier<AsyncValue<List<SpecialProjectModel>>> {
  ResidentSpecialProjectNotifier(this._repository)
      : super(const AsyncValue.loading()) {
    fetchProjects();
  }

  final SpecialProjectRepository _repository;

  Future<void> fetchProjects() async {
    state = const AsyncValue.loading();
    try {
      final items = await _repository.getMyProjects();
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final residentSpecialProjectsProvider = StateNotifierProvider<
    ResidentSpecialProjectNotifier,
    AsyncValue<List<SpecialProjectModel>>>(
  (ref) => ResidentSpecialProjectNotifier(SpecialProjectRepository()),
);

final residentSpecialProjectDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, projectId) async {
    final repo = SpecialProjectRepository();
    return repo.getProjectDetail(projectId);
  },
);

final residentSpecialProjectExpensesProvider =
    FutureProvider.autoDispose.family<List<ProjectExpenseModel>, String>(
  (ref, projectId) async {
    final repo = SpecialProjectRepository();
    return repo.getProjectExpenses(projectId);
  },
);

// ── Admin providers ───────────────────────────────────────

class AdminSpecialProjectNotifier
    extends StateNotifier<AsyncValue<List<SpecialProjectModel>>> {
  AdminSpecialProjectNotifier(this._repository)
      : super(const AsyncValue.loading()) {
    fetchProjects();
  }

  final SpecialProjectRepository _repository;

  Future<void> fetchProjects() async {
    state = const AsyncValue.loading();
    try {
      final items = await _repository.getAdminProjects();
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final adminSpecialProjectsProvider = StateNotifierProvider<
    AdminSpecialProjectNotifier,
    AsyncValue<List<SpecialProjectModel>>>(
  (ref) => AdminSpecialProjectNotifier(SpecialProjectRepository()),
);

final adminSpecialProjectDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, projectId) async {
    final repo = SpecialProjectRepository();
    return repo.getAdminProjectDetail(projectId);
  },
);
