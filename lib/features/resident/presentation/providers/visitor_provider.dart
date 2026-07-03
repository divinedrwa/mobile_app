import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client_provider.dart';
import '../../../../shared/utils/provider_cache.dart';
import '../../data/repositories/visitor_repository.dart';
import '../../data/models/pre_approved_visitor_model.dart';

/// Provider for visitor repository
final visitorRepositoryProvider = Provider<VisitorRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return VisitorRepository(dioClient);
});

/// Provider for fetching pre-approved visitors
final preApprovedVisitorsProvider =
    FutureProvider.autoDispose<List<PreApprovedVisitorModel>>((ref) async {
  cacheFor(ref, const Duration(minutes: 2));
  final repository = ref.read(visitorRepositoryProvider);
  return await repository.getPreApprovedVisitors();
});

/// Synchronous cold-start seed for pre-approved visitors, read from the
/// persistent cache written after each successful fetch. Lets the visitor hub
/// paint the upcoming-visitors section instead of a skeleton on a cold start.
final preApprovedVisitorsSeedProvider =
    Provider<List<PreApprovedVisitorModel>?>((ref) {
  return readPreApprovedVisitorsSeed();
});

/// State provider for current visitor being created
final currentVisitorProvider =
    StateProvider.autoDispose<PreApprovedVisitorModel?>((ref) => null);

/// Gate approval flow — list by tab filter (`pending`, `approved`, `rejected`, `all`).
final visitorApprovalRequestsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, filter) async {
  cacheFor(ref, const Duration(minutes: 2));
  final repository = ref.watch(visitorRepositoryProvider);
  return repository.getVisitorApprovalRequests(filter: filter);
});

/// Single visitor request detail (resident view).
final visitorApprovalDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, visitorId) async {
  final repository = ref.watch(visitorRepositoryProvider);
  return repository.getVisitorApprovalRequestDetail(visitorId);
});
