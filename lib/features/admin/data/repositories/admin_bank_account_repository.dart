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
      if (data is Map) {
        // Backend wraps the list under `accounts` (older clients used `bankAccounts`).
        final list = data['accounts'] ?? data['bankAccounts'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      return [];
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load bank accounts');
    }
  }

  // Backend (createBankAccountSchema) requires all of these fields.
  Future<Map<String, dynamic>> createBankAccount({
    required String accountHolderName,
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    required String accountType,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminBankAccounts,
        data: {
          'accountHolderName': accountHolderName,
          'bankName': bankName,
          'accountNumber': accountNumber,
          'ifscCode': ifscCode,
          'accountType': accountType,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create bank account');
    }
  }

  // Note: the backend update schema does not allow changing the account number.
  Future<Map<String, dynamic>> updateBankAccount(
    String id, {
    String? accountHolderName,
    String? bankName,
    String? ifscCode,
    String? accountType,
    bool? isActive,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.adminBankAccountById(id),
        data: {
          if (accountHolderName != null) 'accountHolderName': accountHolderName,
          if (bankName != null) 'bankName': bankName,
          if (ifscCode != null) 'ifscCode': ifscCode,
          if (accountType != null) 'accountType': accountType,
          if (isActive != null) 'isActive': isActive,
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
