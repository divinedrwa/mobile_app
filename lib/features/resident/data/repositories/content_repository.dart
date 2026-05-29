import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/document_model.dart';
import '../models/notice_model.dart';

class ContentRepository {
  Dio get _dio => DioClient.dio;

  Future<List<NoticeModel>> getNotices() async {
    try {
      final response = await _dio.get(ApiEndpoints.notices);
      final list = response.data['notices'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((e) => NoticeModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch notices');
    }
  }

  Future<List<DocumentModel>> getDocuments() async {
    try {
      final response = await _dio.get(ApiEndpoints.documents);
      final list = response.data['documents'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((e) => DocumentModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch documents');
    }
  }

  Future<List<Map<String, dynamic>>> getPolls() async {
    try {
      final response = await _dio.get(ApiEndpoints.polls);
      final polls = response.data['polls'] as List? ?? [];
      return polls
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch polls');
    }
  }

  Future<void> votePoll({
    required String pollId,
    required String optionId,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.votePoll(pollId),
        data: {'optionId': optionId},
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to submit vote');
    }
  }

  Future<List<Map<String, dynamic>>> getEventBanners() async {
    try {
      final response = await _dio.get(ApiEndpoints.banners);
      final banners = response.data['banners'] as List? ?? [];
      return banners
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch events');
    }
  }

  /// Register resident for an event banner/campaign.
  Future<void> registerForEvent(String eventId) async {
    try {
      await _dio.post(ApiEndpoints.bannerRegister(eventId));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to register for event');
    }
  }
}
