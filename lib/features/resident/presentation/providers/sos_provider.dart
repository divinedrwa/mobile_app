import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client_provider.dart';
import '../../data/repositories/sos_repository.dart';
import '../../data/models/sos_alert_model.dart';

final sosRepositoryProvider = Provider<SOSRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return SOSRepository(dioClient);
});

/// Current open SOS for the resident — poll / refresh from UI when active.
final activeSosProvider =
    FutureProvider.autoDispose<SOSAlertModel?>((ref) async {
  final repository = ref.read(sosRepositoryProvider);
  return repository.fetchActiveSos();
});

final sendSOSAlertProvider =
    FutureProvider.autoDispose.family<SOSAlertModel, SOSAlertModel>(
  (ref, alert) async {
    final repository = ref.read(sosRepositoryProvider);
    return repository.sendSOSAlert(alert);
  },
);

final sosAlertsProvider =
    FutureProvider.autoDispose<List<SOSAlertModel>>((ref) async {
  final repository = ref.read(sosRepositoryProvider);
  return repository.getSOSAlerts();
});
