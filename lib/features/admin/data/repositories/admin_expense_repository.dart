import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminExpenseRepository {
  Dio get _dio => DioClient.dio;

  /// Fetch admin expenses with optional filters.
  Future<List<Map<String, dynamic>>> getAdminExpenses({
    int? month,
    int? year,
    String? categoryId,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.adminExpenses,
        queryParameters: {
          if (month != null) 'month': month,
          if (year != null) 'year': year,
          if (categoryId != null) 'categoryId': categoryId,
        },
      );
      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load expenses');
    }
  }

  /// Fetch expense categories.
  Future<List<Map<String, dynamic>>> getAdminCategories() async {
    try {
      final res = await _dio.get(ApiEndpoints.adminExpenseCategories);
      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load expense categories');
    }
  }

  /// Create a new expense.
  Future<Map<String, dynamic>> createExpense({
    required String categoryId,
    required String title,
    required double amount,
    required String paymentDate,
    required String paymentMode,
    String? paidTo,
    String? description,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminExpenses,
        data: {
          'categoryId': categoryId,
          'title': title,
          'amount': amount,
          'paymentDate': paymentDate,
          'paymentMode': paymentMode,
          if (paidTo != null && paidTo.isNotEmpty) 'paidTo': paidTo,
          if (description != null && description.isNotEmpty)
            'description': description,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create expense');
    }
  }

  /// Delete an expense.
  Future<void> deleteExpense(String id) async {
    try {
      await _dio.delete(ApiEndpoints.adminExpenseById(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete expense');
    }
  }
}
