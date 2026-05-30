import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client_provider.dart';
import '../models/water_supply_model.dart';
import '../models/water_request_model.dart';
import '../models/garbage_collection_model.dart';
import '../repositories/utilities_repository.dart';

final utilitiesRepositoryProvider = Provider<UtilitiesRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return UtilitiesRepository(dioClient);
});

final waterSupplyStatusProvider =
    FutureProvider.autoDispose<List<WaterSupplyStatus>>((ref) async {
  final repo = ref.read(utilitiesRepositoryProvider);
  return repo.getWaterSupplyStatus();
});

final waterSupplyEventsProvider =
    FutureProvider.autoDispose<List<WaterSupplyEvent>>((ref) async {
  final repo = ref.read(utilitiesRepositoryProvider);
  return repo.getWaterSupplyEvents();
});

final garbageCollectionActiveProvider =
    FutureProvider.autoDispose<GarbageCollectionStatus?>((ref) async {
  final repo = ref.read(utilitiesRepositoryProvider);
  return repo.getGarbageCollectionActive();
});

final garbageCollectionHistoryProvider =
    FutureProvider.autoDispose<List<GarbageCollectionEvent>>((ref) async {
  final repo = ref.read(utilitiesRepositoryProvider);
  return repo.getGarbageCollectionHistory();
});

final waterSupplyMyRequestsProvider =
    FutureProvider.autoDispose<List<WaterRequestModel>>((ref) async {
  final repo = ref.read(utilitiesRepositoryProvider);
  return repo.getMyWaterRequests();
});
