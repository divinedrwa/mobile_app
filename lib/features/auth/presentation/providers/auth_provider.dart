import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user_model.dart';
import '../../data/auth_repository.dart' show AuthRepository, RefreshResult;
import '../../../legal/data/legal_repository.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/pdf_share.dart';
import '../../../../core/utils/storage_service.dart';

/// Auth state
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;

  /// L2 — user must (re-)accept updated Terms/Privacy before using the app.
  /// The router redirects authenticated users to `/legal-consent` while true.
  final bool requiresLegalAcceptance;

  /// False until the saved session has been read at startup. Until then
  /// `user == null` means "not known yet", not "logged out", so nothing may
  /// send the user to the login screen.
  final bool isInitialized;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.requiresLegalAcceptance = false,
    this.isInitialized = true,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
    bool clearUser = false,
    bool? requiresLegalAcceptance,
    bool? isInitialized,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      requiresLegalAcceptance:
          requiresLegalAcceptance ?? this.requiresLegalAcceptance,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  bool get isAuthenticated => user != null;
}

/// Reads the cached L2 legal-acceptance flag persisted by the auth repository
/// during login/refresh (so the gate survives relaunch before the network check).
bool _cachedRequiresLegal() =>
    StorageService.getBool(AppConstants.keyRequiresLegalAcceptance) ?? false;

/// Auth state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final LegalRepository _legalRepository = LegalRepository();
  // ignore: unused_field
  final Ref ref;
  bool _loggingOut = false;

  AuthNotifier(this._authRepository, this.ref)
      : super(const AuthState(isInitialized: false)) {
    _init();
  }

  /// Restores the signed-in user from the cached profile (SharedPreferences —
  /// no platform-channel or network wait), so a logged-in user goes straight
  /// to their home screen, also when the app is opened from a notification.
  /// The token check and refresh run in the background; only a server
  /// rejection of the session logs the user out.
  Future<void> _init() async {
    UserModel? cachedUser;
    try {
      cachedUser = _authRepository.getCachedUser();
    } catch (_) {
      cachedUser = null;
    }
    if (cachedUser == null) {
      state = const AuthState();
      return;
    }
    if (cachedUser.role == UserRole.superAdmin) {
      state = const AuthState();
      unawaited(_authRepository.logout());
      return;
    }
    state = AuthState(
      user: cachedUser,
      requiresLegalAcceptance: _cachedRequiresLegal(),
    );
    unawaited(_restoreSessionInBackground());
  }

  Future<void> _restoreSessionInBackground() async {
    try {
      await _authRepository.repairCachedUserDataIfNeeded();
      // Refresh proactively only when a stored token exists and has expired.
      // If the token can't be read right now, API calls refresh on demand.
      if (await _authRepository.isLoggedIn() &&
          await _authRepository.isTokenExpired()) {
        final result = await _authRepository.refreshTokens();
        if (result == RefreshResult.rejected) {
          // Refresh token revoked or expired (logout elsewhere, password change).
          await logout();
          return;
        }
        // networkError: keep the session; the next API call retries the refresh.
      }
    } catch (_) {
      // Never sign the user out over a local read failure.
    }
    unawaited(_refreshProfile());
    // Authoritative re-check in case legal versions were bumped while the
    // access token was still valid (no login/refresh happened this launch).
    unawaited(_refreshLegalStatus());
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

  /// L2 — authoritative background check of legal-consent state. Updates both the
  /// cached flag and auth state; ignores network/transient errors (gate falls back
  /// to the last-known cached value).
  Future<void> _refreshLegalStatus() async {
    try {
      final status = await _legalRepository.getStatus();
      await StorageService.setBool(
        AppConstants.keyRequiresLegalAcceptance,
        status.requiresAcceptance,
      );
      if (mounted) {
        state = state.copyWith(
          requiresLegalAcceptance: status.requiresAcceptance,
        );
      }
    } catch (_) {
      // Ignore — keep last-known cached value.
    }
  }

  /// Called by the legal-consent gate after a successful acceptance so the router
  /// can release the gate and navigate the user to their home tree.
  Future<void> markLegalAccepted() async {
    await StorageService.setBool(
      AppConstants.keyRequiresLegalAcceptance,
      false,
    );
    state = state.copyWith(requiresLegalAcceptance: false);
  }

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

      state = AuthState(
        user: user,
        isLoading: false,
        requiresLegalAcceptance: _cachedRequiresLegal(),
      );
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
      state = AuthState(
        user: user,
        isLoading: false,
        requiresLegalAcceptance: _cachedRequiresLegal(),
      );
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

  /// Clears session, storage, Dio and resets auth state.
  /// The router's auth-state listener detects `isAuthenticated → false`
  /// and redirects to /login (or /society-select) automatically.
  /// No `restartApp()` — that caused a double splash (the router redirect
  /// navigated to /login, then the full widget-tree rebuild showed the
  /// splash screen a second time).
  Future<void> logout() async {
    if (_loggingOut) return;
    _loggingOut = true;
    try {
      await _authRepository.logout();
      await clearInvoicePdfCache();
    } catch (_) {
      // Best-effort — proceed even if cleanup partially fails.
    }
    state = const AuthState();
    _loggingOut = false;
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
