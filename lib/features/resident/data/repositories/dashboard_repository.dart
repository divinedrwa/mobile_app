import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/resident_dashboard_model.dart';

class DashboardRepository {
  Dio get _dio => DioClient.dio;

  Future<ResidentDashboardModel> getDashboard() async {
    try {
      final response = await _dio.get(ApiEndpoints.dashboard);
      final data = response.data;
      if (data is Map<String, dynamic>) {
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
