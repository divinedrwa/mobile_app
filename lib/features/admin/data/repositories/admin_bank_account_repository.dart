import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminBankAccountRepository {
  Dio get _dio => DioClient.dio;

  Future<List<Map<String, dynamic>>> getBankAccounts() async {
    try {
      final res = await _dio.get(ApiEndpoints.adminBankAccounts);
      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (data is Map && data['bankAccounts'] is List) {
        return (data['bankAccounts'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load bank accounts');
    }
  }

  Future<Map<String, dynamic>> createBankAccount({
    required String accountName,
    required String bankName,
    required String accountNumber,
    String? ifscCode,
    String? accountType,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminBankAccounts,
        data: {
          'accountName': accountName,
          'bankName': bankName,
          'accountNumber': accountNumber,
          if (ifscCode != null && ifscCode.isNotEmpty) 'ifscCode': ifscCode,
          if (accountType != null && accountType.isNotEmpty)
            'accountType': accountType,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create bank account');
    }
  }

  Future<Map<String, dynamic>> updateBankAccount(
    String id, {
    String? accountName,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? accountType,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.adminBankAccountById(id),
        data: {
          if (accountName != null) 'accountName': accountName,
          if (bankName != null) 'bankName': bankName,
          if (accountNumber != null) 'accountNumber': accountNumber,
          if (ifscCode != null) 'ifscCode': ifscCode,
          if (accountType != null) 'accountType': accountType,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update bank account');
    }
  }

  Future<void> deleteBankAccount(String id) async {
    try {
      await _dio.delete(ApiEndpoints.adminBankAccountById(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete bank account');
    }
  }
}
