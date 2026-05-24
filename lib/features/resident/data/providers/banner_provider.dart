import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client_provider.dart';
import '../models/banner_model.dart';
import '../repositories/banner_repository.dart';

final bannerRepositoryProvider = Provider<BannerRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return BannerRepository(dioClient);
});

final activeBannersProvider =
    FutureProvider.autoDispose<List<BannerModel>>((ref) async {
  final repo = ref.read(bannerRepositoryProvider);
  return repo.getActiveBanners();
});
