import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user_model.dart';
import '../../data/auth_repository.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_restart.dart';

/// Auth state
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  bool get isAuthenticated => user != null;
}

/// Auth state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  // Retained for future provider invalidation needs; restartApp() handles
  // cleanup for now but individual invalidation may return.
  // ignore: unused_field
  final Ref ref;
  bool _loggingOut = false;

  AuthNotifier(this._authRepository, this.ref) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final isLoggedIn = await _authRepository.isLoggedIn();
    if (isLoggedIn) {
      // Proactively refresh the access token on app launch if it's expired
      // (or close to expiry). The user stays logged in seamlessly as long as
      // their refresh token is still valid.
      if (await _authRepository.isTokenExpired()) {
        final refreshed = await _authRepository.refreshTokens();
        if (!refreshed) {
          // Refresh token is also dead — force a clean logout.
          await _authRepository.logout();
          state = const AuthState();
          return;
        }
      }

      await _authRepository.repairCachedUserDataIfNeeded();
      final cachedUser = _authRepository.getCachedUser();
      if (cachedUser != null) {
        if (cachedUser.role == UserRole.superAdmin) {
          await _authRepository.logout();
          state = const AuthState();
          return;
        }
        state = state.copyWith(user: cachedUser);
        unawaited(_refreshProfile());
      }
    }
  }

  Future<void> _refreshProfile() async {
    try {
      final user = await _authRepository.getProfile();
      state = state.copyWith(user: user);
    } catch (e) {
      // Ignore errors during background refresh
    }
  }

  /// Public refresh after profile-changing calls (e.g. notification email toggle).
  Future<void> refreshProfile() => _refreshProfile();

  Future<bool> login({
    required String societyId,
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final user = await _authRepository.login(
        societyId: societyId,
        username: username,
        password: password,
      );

      state = AuthState(user: user, isLoading: false);
      // Fire-and-forget — router navigates on the state change above.
      unawaited(_refreshProfile());
      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'An unexpected error occurred',
      );
      return false;
    }
  }

  Future<bool> registerWithInvitation({
    required String token,
    required String username,
    required String name,
    required String email,
    required String password,
    String? phone,
    String? villaId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _authRepository.registerWithInvitation(
        token: token,
        username: username,
        name: name,
        email: email,
        password: password,
        phone: phone,
        villaId: villaId,
      );
      state = AuthState(user: user, isLoading: false);
      unawaited(_refreshProfile());
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'An unexpected error occurred',
      );
      return false;
    }
  }

  /// Clears session, storage, Dio — then restarts the entire app.
  /// The splash screen picks up from persisted preferences (preferred
  /// society, etc.) and routes to /login or /society-select.
  Future<void> logout() async {
    if (_loggingOut) return;
    _loggingOut = true;
    try {
      await _authRepository.logout();
    } catch (_) {
      // Best-effort — proceed to restart even if cleanup partially fails.
    }
    state = const AuthState();
    _loggingOut = false;
    // Full app restart — destroys all providers, router, and caches.
    restartApp();
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// Auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Auth state provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository, ref);
});
