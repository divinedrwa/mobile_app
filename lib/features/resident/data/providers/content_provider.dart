import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/document_model.dart';
import '../models/notice_model.dart';
import '../repositories/content_repository.dart';

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => ContentRepository(),
);

final noticesProvider = FutureProvider<List<NoticeModel>>((ref) async {
  return ref.watch(contentRepositoryProvider).getNotices();
});

final documentsProvider = FutureProvider<List<DocumentModel>>((ref) async {
  return ref.watch(contentRepositoryProvider).getDocuments();
});

final pollsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(contentRepositoryProvider).getPolls();
});

final eventsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(contentRepositoryProvider).getEventBanners();
});

class PollVoteNotifier extends StateNotifier<AsyncValue<void>> {
  PollVoteNotifier(this._repository) : super(const AsyncValue.data(null));

  final ContentRepository _repository;

  /// Returns `null` on success, otherwise an error message (e.g. already voted).
  Future<String?> vote({
    required String pollId,
    required String optionId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.votePoll(pollId: pollId, optionId: optionId);
      state = const AsyncValue.data(null);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['message'] is String) {
          return (data['message'] as String).trim().isEmpty
              ? 'Failed to submit vote'
              : data['message'] as String;
        }
        final msg = e.message?.trim();
        if (msg != null && msg.isNotEmpty) return msg;
      }
      return 'Failed to submit vote';
    }
  }
}

final pollVoteProvider =
    StateNotifierProvider<PollVoteNotifier, AsyncValue<void>>(
      (ref) => PollVoteNotifier(ref.watch(contentRepositoryProvider)),
    );

class EventRegistrationNotifier extends StateNotifier<AsyncValue<void>> {
  EventRegistrationNotifier(this._repository) : super(const AsyncValue.data(null));

  final ContentRepository _repository;

  Future<String?> register(String eventId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.registerForEvent(eventId);
      state = const AsyncValue.data(null);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return e is AppException ? e.message : 'Something went wrong. Please try again.';
    }
  }
}

final eventRegistrationProvider =
    StateNotifierProvider<EventRegistrationNotifier, AsyncValue<void>>(
      (ref) => EventRegistrationNotifier(ref.watch(contentRepositoryProvider)),
    );
