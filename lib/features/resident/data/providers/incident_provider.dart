import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client_provider.dart';
import '../models/incident_model.dart';
import '../repositories/incident_repository.dart';

final incidentRepositoryProvider = Provider<IncidentRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return IncidentRepository(dioClient);
});

final incidentsProvider =
    FutureProvider.autoDispose<List<IncidentModel>>((ref) async {
  final repo = ref.read(incidentRepositoryProvider);
  return repo.getIncidents();
});
