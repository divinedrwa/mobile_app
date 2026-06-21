import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../shared/utils/provider_cache.dart';
import '../models/document_model.dart';
import '../models/notice_model.dart';
import '../repositories/content_repository.dart';

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => ContentRepository(),
);

final noticesProvider =
    FutureProvider.autoDispose<List<NoticeModel>>((ref) async {
  cacheFor(ref, const Duration(minutes: 3));
  return ref.watch(contentRepositoryProvider).getNotices();
});

final documentsProvider =
    FutureProvider.autoDispose<List<DocumentModel>>((ref) async {
  cacheFor(ref, const Duration(minutes: 3));
  return ref.watch(contentRepositoryProvider).getDocuments();
});

final pollsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  cacheFor(ref, const Duration(minutes: 3));
  return ref.watch(contentRepositoryProvider).getPolls();
});

final eventsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  cacheFor(ref, const Duration(minutes: 3));
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
      // The repo maps Dio errors to AppException, so surface the mapper's
      // user-facing message (e.g. the backend's "Already voted") instead of
      // a generic fallback.
      return userFacingMessage(e, 'Failed to submit vote');
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
