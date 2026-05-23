import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/special_project_model.dart';

class SpecialProjectRepository {
  Dio get _dio => DioClient.dio;

  // ── Resident endpoints ──────────────────────────────────────

  Future<List<SpecialProjectModel>> getMyProjects({String? status}) async {
    try {
      final params = <String, dynamic>{};
      if (status != null && status.isNotEmpty) params['status'] = status;
      final response = await _dio.get(
        ApiEndpoints.residentSpecialProjects,
        queryParameters: params,
      );
      final list = response.data['projects'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((raw) =>
              SpecialProjectModel.fromJson(Map<String, dynamic>.from(raw)))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch special projects');
    }
  }

  Future<Map<String, dynamic>> getProjectDetail(String id) async {
    try {
      final response =
          await _dio.get(ApiEndpoints.residentSpecialProjectDetail(id));
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch project details');
    }
  }

  Future<List<ProjectExpenseModel>> getProjectExpenses(String id) async {
    try {
      final response =
          await _dio.get(ApiEndpoints.residentSpecialProjectExpenses(id));
      final list = response.data['expenses'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((raw) =>
              ProjectExpenseModel.fromJson(Map<String, dynamic>.from(raw)))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch project expenses');
    }
  }

  // ── Admin endpoints ─────────────────────────────────────────

  Future<List<SpecialProjectModel>> getAdminProjects({String? status}) async {
    try {
      final params = <String, dynamic>{'limit': '200'};
      if (status != null && status.isNotEmpty) params['status'] = status;
      final response = await _dio.get(
        ApiEndpoints.adminSpecialProjects,
        queryParameters: params,
      );
      final list = response.data['projects'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((raw) =>
              SpecialProjectModel.fromJson(Map<String, dynamic>.from(raw)))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch projects');
    }
  }

  Future<Map<String, dynamic>> getAdminProjectDetail(String id) async {
    try {
      final response =
          await _dio.get(ApiEndpoints.adminSpecialProjectDetail(id));
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch project details');
    }
  }

  Future<SpecialProjectModel> createProject(
      Map<String, dynamic> data) async {
    try {
      final response =
          await _dio.post(ApiEndpoints.adminSpecialProjects, data: data);
      return SpecialProjectModel.fromJson(
          response.data['project'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create project');
    }
  }

  Future<void> updateProjectStatus(String id, String status) async {
    try {
      await _dio.patch(
        ApiEndpoints.adminSpecialProjectStatus(id),
        data: {'status': status},
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update project status');
    }
  }

  Future<void> recordPayment(
    String projectId,
    String contributionId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _dio.post(
        ApiEndpoints.adminSpecialProjectPayment(projectId, contributionId),
        data: data,
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to record payment');
    }
  }

  Future<void> addExpense(
      String projectId, Map<String, dynamic> data) async {
    try {
      await _dio.post(
        ApiEndpoints.adminSpecialProjectExpenses(projectId),
        data: data,
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to add expense');
    }
  }

  Future<void> updateProject(
      String id, Map<String, dynamic> data) async {
    try {
      await _dio.patch(
        ApiEndpoints.adminSpecialProjectDetail(id),
        data: data,
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update project');
    }
  }

  Future<void> deleteProject(String id) async {
    try {
      await _dio.delete(ApiEndpoints.adminSpecialProjectDetail(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete project');
    }
  }

  Future<void> deletePayment(
      String projectId, String contribId, String paymentId) async {
    try {
      await _dio.delete(
        ApiEndpoints.adminSpecialProjectPaymentDetail(
            projectId, contribId, paymentId),
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete payment');
    }
  }

  Future<void> updateExpense(
      String projectId, String expenseId, Map<String, dynamic> data) async {
    try {
      await _dio.patch(
        ApiEndpoints.adminSpecialProjectExpenseDetail(projectId, expenseId),
        data: data,
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update expense');
    }
  }

  Future<void> deleteExpense(String projectId, String expenseId) async {
    try {
      await _dio.delete(
        ApiEndpoints.adminSpecialProjectExpenseDetail(projectId, expenseId),
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete expense');
    }
  }

  Future<List<ProjectContributionModel>> getContributions(
      String projectId, {String? status}) async {
    try {
      final params = <String, dynamic>{'limit': '500'};
      if (status != null && status.isNotEmpty) params['status'] = status;
      final response = await _dio.get(
        ApiEndpoints.adminSpecialProjectContributions(projectId),
        queryParameters: params,
      );
      final list = response.data['contributions'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((raw) => ProjectContributionModel.fromJson(
              Map<String, dynamic>.from(raw)))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch contributions');
    }
  }
}
