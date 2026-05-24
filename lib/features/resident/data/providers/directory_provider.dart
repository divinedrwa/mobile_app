import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client_provider.dart';
import '../models/directory_resident_model.dart';
import '../repositories/directory_repository.dart';

final directoryRepositoryProvider = Provider<DirectoryRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return DirectoryRepository(dioClient);
});

final directorySearchProvider = FutureProvider.autoDispose
    .family<List<DirectoryResident>, String>((ref, query) async {
  final repo = ref.read(directoryRepositoryProvider);
  return repo.searchDirectory(query: query);
});
