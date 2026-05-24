import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client_provider.dart';
import '../models/vehicle_log_model.dart';
import '../repositories/vehicle_log_repository.dart';

final vehicleLogRepositoryProvider = Provider<VehicleLogRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return VehicleLogRepository(dioClient);
});

final vehicleLogProvider =
    FutureProvider.autoDispose<List<VehicleLogEntry>>((ref) async {
  final repo = ref.read(vehicleLogRepositoryProvider);
  return repo.getMyVehicleLog();
});
