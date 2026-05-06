import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../models/visitor_model.dart';
import '../repositories/visitor_repository.dart';

final visitorHistoryRepositoryProvider = Provider<VisitorRepository>(
  (ref) => VisitorRepository(DioClient()),
);

final visitorHistoryProvider = FutureProvider<List<VisitorModel>>((ref) async {
  return ref.watch(visitorHistoryRepositoryProvider).getVisitorHistory();
});
