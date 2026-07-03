import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../shared/utils/persistent_list_cache.dart';
import '../models/resident_dashboard_model.dart';

/// Persistent cache name for the resident home dashboard payload.
const _dashboardCacheName = 'resident_dashboard';

/// Cold-start seed for the resident dashboard, re-parsed from the raw cached
/// API map through [ResidentDashboardModel.fromJson] (full fidelity). Returns
/// `null` on missing/corrupt entry so callers fall through to the network.
ResidentDashboardModel? readResidentDashboardSeed() {
  final key = PersistentListCache.scopedKey(_dashboardCacheName);
  if (key == null) return null;
  return PersistentListCache.read<ResidentDashboardModel>(key, (json) {
    return ResidentDashboardModel.fromJson(Map<String, dynamic>.from(json as Map));
  });
}

class DashboardRepository {
  Dio get _dio => DioClient.dio;

  Future<ResidentDashboardModel> getDashboard() async {
    try {
      final response = await _dio.get(ApiEndpoints.dashboard);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final key = PersistentListCache.scopedKey(_dashboardCacheName);
        if (key != null) {
          await PersistentListCache.write(key, data);
        }
        return ResidentDashboardModel.fromJson(data);
      }
      return ResidentDashboardModel(
        stats: ResidentDashboardStats.fromJson(null),
        fund: ResidentFundSnapshot.fromJson(null),
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load dashboard');
    }
  }
}
