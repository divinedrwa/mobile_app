import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';

class AdminPollRepository {
  Dio get _dio => DioClient.dio;

  /// Fetch all polls with option vote counts.
  Future<List<Map<String, dynamic>>> getPolls() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminPolls,
      );
      final list = res.data?['polls'] as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load polls');
    }
  }

  /// Fetch a single poll with results and vote status.
  Future<Map<String, dynamic>> getPollById(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminPollById(id),
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load poll');
    }
  }

  /// Create a new poll.
  Future<void> createPoll({
    required String title,
    String? description,
    required String startDate,
    required String endDate,
    required List<String> options,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.adminPolls,
        data: {
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          'startDate': startDate,
          'endDate': endDate,
          'options': options,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create poll');
    }
  }

  /// Options can't be changed after creation (the backend keeps votes tied to them).
  Future<void> updatePoll(
    String id, {
    String? title,
    String? description,
    String? startDate,
    String? endDate,
  }) async {
    try {
      await _dio.put(
        ApiEndpoints.adminPollById(id),
        data: {
          if (title != null) 'title': title,
          if (description != null) 'description': description,
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to update poll');
    }
  }

  Future<void> deletePoll(String id) async {
    try {
      await _dio.delete(ApiEndpoints.adminPollById(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete poll');
    }
  }

  /// Close/end an active poll.
  Future<void> closePoll(String id) async {
    try {
      await _dio.patch(ApiEndpoints.adminPollClose(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to close poll');
    }
  }

  /// Vote on a poll option.
  Future<void> vote(String pollId, String optionId) async {
    try {
      await _dio.post(
        ApiEndpoints.adminPollVote(pollId),
        data: {'optionId': optionId},
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to vote');
    }
  }
}
