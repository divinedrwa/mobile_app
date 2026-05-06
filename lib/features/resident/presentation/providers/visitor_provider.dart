import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client_provider.dart';
import '../../data/repositories/visitor_repository.dart';
import '../../data/models/pre_approved_visitor_model.dart';

/// Provider for visitor repository
final visitorRepositoryProvider = Provider<VisitorRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return VisitorRepository(dioClient);
});

/// Provider for pre-approving a visitor
final preApproveVisitorProvider = FutureProvider.autoDispose
    .family<PreApprovedVisitorModel, PreApprovedVisitorModel>(
  (ref, visitor) async {
    final repository = ref.read(visitorRepositoryProvider);
    return await repository.preApproveVisitor(visitor);
  },
);

/// Provider for fetching pre-approved visitors
final preApprovedVisitorsProvider =
    FutureProvider.autoDispose<List<PreApprovedVisitorModel>>((ref) async {
  final repository = ref.read(visitorRepositoryProvider);
  return await repository.getPreApprovedVisitors();
});

/// State provider for current visitor being created
final currentVisitorProvider =
    StateProvider.autoDispose<PreApprovedVisitorModel?>((ref) => null);

/// Gate approval flow — list by tab filter (`pending`, `approved`, `rejected`, `all`).
final visitorApprovalRequestsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, filter) async {
  final repository = ref.watch(visitorRepositoryProvider);
  return repository.getVisitorApprovalRequests(filter: filter);
});

/// Single visitor request detail (resident view).
final visitorApprovalDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, visitorId) async {
  final repository = ref.watch(visitorRepositoryProvider);
  return repository.getVisitorApprovalRequestDetail(visitorId);
});
