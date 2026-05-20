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
      await _dio.post(ApiEndpoints.adminPollVote(pollId, optionId));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to vote');
    }
  }
}
