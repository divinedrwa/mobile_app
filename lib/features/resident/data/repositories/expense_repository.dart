import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/expense_category_model.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  Dio get _dio => DioClient.dio;

  Future<({List<ExpenseModel> expenses, int total, bool hasMore})> getExpenses({
    String? categoryId,
    int? month,
    int? year,
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final params = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      if (categoryId != null && categoryId.isNotEmpty) {
        params['categoryId'] = categoryId;
      }
      if (month != null) params['month'] = month;
      if (year != null) params['year'] = year;
      if (search != null && search.trim().isNotEmpty) {
        params['search'] = search.trim();
      }

      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.societyExpenses,
        queryParameters: params,
      );
      final data = res.data;
      if (data == null) {
        return (expenses: <ExpenseModel>[], total: 0, hasMore: false);
      }

      final raw = data['expenses'] as List<dynamic>? ?? [];
      final expenses = raw
          .map((e) =>
              ExpenseModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      return (
        expenses: expenses,
        total: data['total'] as int? ?? expenses.length,
        hasMore: data['hasMore'] as bool? ?? false,
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load expenses');
    }
  }

  Future<ExpenseModel> getExpenseById(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.societyExpenseById(id),
      );
      if (res.data == null) {
        throw Exception('Expense not found');
      }
      return ExpenseModel.fromJson(res.data!);
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load expense details');
    }
  }

  Future<List<ExpenseCategoryModel>> getCategories() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.societyExpenseCategories,
      );
      final data = res.data;
      if (data == null) return [];
      final raw = data['categories'] as List<dynamic>? ?? [];
      return raw
          .map((e) => ExpenseCategoryModel.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load expense categories');
    }
  }
}
