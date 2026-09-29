import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminExpenseRepository {
  Dio get _dio => DioClient.dio;

  /// The expense list endpoints return a plain JSON array; also accept
  /// `{ <key>: [...] }` in case the API adds pagination metadata.
  static List<Map<String, dynamic>> _mapList(dynamic data, String key) {
    final list = data is List ? data : (data is Map ? data[key] : null);
    if (list is! List) return const [];
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getExpenses({
    int page = 1,
    int limit = 50,
    String? categoryId,
    String? year,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.adminExpenses,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (categoryId != null) 'categoryId': categoryId,
          if (year != null) 'year': year,
        },
      );
      return _mapList(res.data, 'expenses');
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load expenses');
    }
  }

  Future<Map<String, dynamic>> getExpense(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminExpenseById(id),
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load expense');
    }
  }

  /// Create expense with optional attachments: {fileUrl, fileName, fileType, fileSize}.
  Future<void> createExpense({
    required String categoryId,
    required String title,
    String? description,
    required double amount,
    required DateTime paymentDate,
    String? paymentMode,
    String? paymentRef,
    String? paidTo,
    String? paidToContact,
    String? receiptNumber,
    String? invoiceNumber,
    double? gstAmount,
    double? gstPercentage,
    double? tdsAmount,
    double? tdsPercentage,
    String? notes,
    List<Map<String, dynamic>>? attachments,
    List<String>? tags,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.adminExpenses,
        data: {
          'categoryId': categoryId,
          'title': title,
          if (description != null) 'description': description,
          'amount': amount,
          'paymentDate': paymentDate.toIso8601String(),
          if (paymentMode != null) 'paymentMode': paymentMode,
          if (paymentRef != null) 'paymentRef': paymentRef,
          if (paidTo != null) 'paidTo': paidTo,
          if (paidToContact != null) 'paidToContact': paidToContact,
          if (receiptNumber != null) 'receiptNumber': receiptNumber,
          if (invoiceNumber != null) 'invoiceNumber': invoiceNumber,
          if (gstAmount != null) 'gstAmount': gstAmount,
          if (gstPercentage != null) 'gstPercentage': gstPercentage,
          if (tdsAmount != null) 'tdsAmount': tdsAmount,
          if (tdsPercentage != null) 'tdsPercentage': tdsPercentage,
          if (notes != null) 'notes': notes,
          if (attachments != null && attachments.isNotEmpty) 'attachments': attachments,
          if (tags != null && tags.isNotEmpty) 'tags': tags,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create expense');
    }
  }

  /// Update expense. Only provided fields are updated.
  Future<void> updateExpense(
    String id, {
    String? categoryId,
    String? title,
    String? description,
    double? amount,
    DateTime? paymentDate,
    String? paymentMode,
    String? paymentRef,
    String? paidTo,
    String? paidToContact,
    String? receiptNumber,
    String? invoiceNumber,
    double? gstAmount,
    double? gstPercentage,
    double? tdsAmount,
    double? tdsPercentage,
    String? notes,
    List<String>? tags,
  }) async {
    try {
      await _dio.put(
        ApiEndpoints.adminExpenseById(id),
        data: {
          if (categoryId != null) 'categoryId': categoryId,
          if (title != null) 'title': title,
          if (description != null) 'description': description,
          if (amount != null) 'amount': amount,
          if (paymentDate != null) 'paymentDate': paymentDate.toIso8601String(),
          if (paymentMode != null) 'paymentMode': paymentMode,
          if (paymentRef != null) 'paymentRef': paymentRef,
          if (paidTo != null) 'paidTo': paidTo,
          if (paidToContact != null) 'paidToContact': paidToContact,
          if (receiptNumber != null) 'receiptNumber': receiptNumber,
          if (invoiceNumber != null) 'invoiceNumber': invoiceNumber,
          if (gstAmount != null) 'gstAmount': gstAmount,
          if (gstPercentage != null) 'gstPercentage': gstPercentage,
          if (tdsAmount != null) 'tdsAmount': tdsAmount,
          if (tdsPercentage != null) 'tdsPercentage': tdsPercentage,
          if (notes != null) 'notes': notes,
          if (tags != null) 'tags': tags,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update expense');
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await _dio.delete(ApiEndpoints.adminExpenseById(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete expense');
    }
  }

  /// Upload 1-5 files and return: {fileName, fileUrl, fileType, fileSize}.
  Future<List<Map<String, dynamic>>> uploadAttachments(
    List<(Uint8List bytes, String filename)> files,
  ) async {
    try {
      final form = FormData();
      for (final (bytes, filename) in files) {
        final lower = filename.toLowerCase();
        final subtype = lower.endsWith('.pdf')
            ? 'pdf'
            : lower.endsWith('.png')
                ? 'png'
                : lower.endsWith('.webp')
                    ? 'webp'
                    : 'jpeg';
        form.files.add(
          MapEntry(
            'files',
            MultipartFile.fromBytes(
              bytes,
              filename: filename,
              contentType: DioMediaType(
                subtype == 'pdf' ? 'application' : 'image',
                subtype,
              ),
            ),
          ),
        );
      }
      final res = await _dio.post<Map<String, dynamic>>(
        '${ApiEndpoints.adminExpenses}/upload-attachment',
        data: form,
      );
      final list = res.data?['attachments'] as List? ?? [];
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to upload attachments');
    }
  }

  /// Attach pre-uploaded files to an expense.
  Future<void> attachFiles(String expenseId, List<Map<String, dynamic>> attachments) async {
    try {
      await _dio.post(
        '${ApiEndpoints.adminExpenseById(expenseId)}/attachments',
        data: {'attachments': attachments},
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to attach files');
    }
  }

  /// Remove an attachment from an expense.
  Future<void> removeAttachment(String expenseId, String attachmentId) async {
    try {
      await _dio.delete(
        '${ApiEndpoints.adminExpenseById(expenseId)}/attachments/$attachmentId',
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to remove attachment');
    }
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final res = await _dio.get(ApiEndpoints.adminExpenseCategories);
      return _mapList(res.data, 'categories');
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load categories');
    }
  }

  /// Create category: {name, description?, type, icon?, color?, isRecurring?, defaultAmount?}.
  Future<void> createCategory({
    required String name,
    required String type,
    String? description,
    String? icon,
    String? color,
    bool? isRecurring,
    double? defaultAmount,
  }) async {
    try {
      await _dio.post(
        '${ApiEndpoints.adminExpenses}/categories',
        data: {
          'name': name,
          'type': type,
          if (description != null) 'description': description,
          if (icon != null) 'icon': icon,
          if (color != null) 'color': color,
          if (isRecurring != null) 'isRecurring': isRecurring,
          if (defaultAmount != null) 'defaultAmount': defaultAmount,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create category');
    }
  }

  /// Update category. Only provided fields are updated.
  Future<void> updateCategory(
    String id, {
    String? name,
    String? description,
    String? type,
    String? icon,
    String? color,
    bool? isRecurring,
    double? defaultAmount,
  }) async {
    try {
      await _dio.put(
        '${ApiEndpoints.adminExpenses}/categories/$id',
        data: {
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (type != null) 'type': type,
          if (icon != null) 'icon': icon,
          if (color != null) 'color': color,
          if (isRecurring != null) 'isRecurring': isRecurring,
          if (defaultAmount != null) 'defaultAmount': defaultAmount,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update category');
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _dio.delete('${ApiEndpoints.adminExpenses}/categories/$id');
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete category');
    }
  }

  /// Monthly summary: {month, year, totalExpenses, categoryBreakdown, count}.
  Future<Map<String, dynamic>> getMonthlySummary(int month, int year) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.adminExpenses}/summary/monthly',
        queryParameters: {'month': month, 'year': year},
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load monthly summary');
    }
  }

  /// Yearly summary: {year, totalExpenses, monthlyBreakdown, categoryBreakdown, count}.
  Future<Map<String, dynamic>> getYearlySummary(int year) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.adminExpenses}/summary/yearly',
        queryParameters: {'year': year},
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load yearly summary');
    }
  }
}
