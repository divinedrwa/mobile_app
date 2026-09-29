import 'dart:async';

import 'package:divine_app/core/utils/storage_service.dart';
import 'package:divine_app/features/auth/data/auth_repository.dart';
import 'package:divine_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:divine_app/shared/models/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({
    required this.loggedIn,
    this.user,
    this.tokenExpired = false,
    this.refreshResult = RefreshResult.success,
    this.refreshGate,
  });

  final bool loggedIn;
  final UserModel? user;
  final bool tokenExpired;
  final RefreshResult refreshResult;
  final Completer<RefreshResult>? refreshGate;
  int refreshCalls = 0;
  bool loggedOut = false;

  @override
  Future<bool> isLoggedIn() async => loggedIn;

  @override
  Future<void> repairCachedUserDataIfNeeded() async {}

  @override
  UserModel? getCachedUser() => loggedOut ? null : user;

  @override
  Future<bool> isTokenExpired() async => tokenExpired;

  @override
  Future<RefreshResult> refreshTokens() {
    refreshCalls++;
    return refreshGate?.future ?? Future.value(refreshResult);
  }

  @override
  Future<UserModel> getProfile() async => throw Exception('offline in tests');

  @override
  Future<void> logout() async {
    loggedOut = true;
  }
}

final _resident = UserModel.fromJson({
  'id': 'u1',
  'name': 'Resident One',
  'email': 'r1@test.localhost',
  'username': 'r1',
  'role': 'RESIDENT',
  'societyId': 's1',
  'isActive': true,
});

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  ProviderContainer containerWith(_FakeAuthRepository repo) {
    final c = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    return c;
  }

  test('signed-in user is available immediately, with no async wait', () {
    final c = containerWith(_FakeAuthRepository(loggedIn: true, user: _resident));
    final state = c.read(authProvider);
    expect(state.isInitialized, isTrue);
    expect(state.user?.id, 'u1');
  });

  test('a missing token does not sign the user out at startup', () async {
    final repo = _FakeAuthRepository(loggedIn: false, user: _resident, tokenExpired: true);
    final c = containerWith(repo);
    c.read(authProvider);
    await _settle();

    expect(c.read(authProvider).user?.id, 'u1');
    expect(repo.loggedOut, isFalse);
    expect(repo.refreshCalls, 0);
  });

  test('restores the saved user without waiting for a token refresh', () async {
    final gate = Completer<RefreshResult>();
    final repo = _FakeAuthRepository(
      loggedIn: true,
      user: _resident,
      tokenExpired: true,
      refreshGate: gate,
    );
    final c = containerWith(repo);
    c.read(authProvider);
    await _settle();

    final state = c.read(authProvider);
    expect(state.isInitialized, isTrue);
    expect(state.user?.id, 'u1');
    expect(repo.refreshCalls, 1, reason: 'refresh runs in the background');
    gate.complete(RefreshResult.success);
    await _settle();
    expect(c.read(authProvider).user?.id, 'u1');
  });

  test('stays logged in when the refresh fails for network reasons', () async {
    final repo = _FakeAuthRepository(
      loggedIn: true,
      user: _resident,
      tokenExpired: true,
      refreshResult: RefreshResult.networkError,
    );
    final c = containerWith(repo);
    c.read(authProvider);
    await _settle();

    expect(c.read(authProvider).user?.id, 'u1');
    expect(repo.loggedOut, isFalse);
  });

  test('logs out only when the server rejects the session', () async {
    final repo = _FakeAuthRepository(
      loggedIn: true,
      user: _resident,
      tokenExpired: true,
      refreshResult: RefreshResult.rejected,
    );
    final c = containerWith(repo);
    c.read(authProvider);
    await _settle();

    final state = c.read(authProvider);
    expect(repo.loggedOut, isTrue);
    expect(state.user, isNull);
    expect(state.isInitialized, isTrue);
  });

  test('a valid token is not refreshed at startup', () async {
    final repo = _FakeAuthRepository(loggedIn: true, user: _resident);
    final c = containerWith(repo);
    c.read(authProvider);
    await _settle();

    expect(c.read(authProvider).user?.id, 'u1');
    expect(repo.refreshCalls, 0);
  });

  test('no saved session: initialized and signed out', () async {
    final c = containerWith(_FakeAuthRepository(loggedIn: false));
    c.read(authProvider);
    await _settle();

    final state = c.read(authProvider);
    expect(state.isInitialized, isTrue);
    expect(state.user, isNull);
  });
}
