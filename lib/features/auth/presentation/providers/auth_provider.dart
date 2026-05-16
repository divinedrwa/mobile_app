import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user_model.dart';
import '../../data/auth_repository.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../resident/data/providers/dashboard_provider.dart';
import '../../../resident/data/providers/notification_provider.dart';
import '../../../resident/data/providers/visitor_history_provider.dart';
import '../../../resident/data/providers/vehicle_provider.dart';
import '../../../resident/data/providers/family_member_provider.dart';
import '../../../resident/data/providers/parcel_provider.dart';

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
  final Ref _ref;

  AuthNotifier(this._authRepository, this._ref) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    // Check if user is already logged in
    final isLoggedIn = await _authRepository.isLoggedIn();
    if (isLoggedIn) {
      await _authRepository.repairCachedUserDataIfNeeded();
      final cachedUser = _authRepository.getCachedUser();
      if (cachedUser != null) {
        if (cachedUser.role == UserRole.superAdmin) {
          await _authRepository.logout();
          state = const AuthState();
          return;
        }
        state = state.copyWith(user: cachedUser);
        // Refresh profile in background; deliberately fire-and-forget so
        // the splash doesn't block on the network round-trip.
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
      // Login payload omits nested `villa`; `/residents/me` includes `villa.villaNumber`.
      await _refreshProfile();
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
      await _refreshProfile();
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

  Future<void> logout() async {
    await _authRepository.logout();
    // Invalidate data providers so stale data from previous user doesn't flash on re-login
    _ref.invalidate(residentDashboardProvider);
    _ref.invalidate(notificationProvider);
    _ref.invalidate(visitorHistoryProvider);
    _ref.invalidate(vehicleProvider);
    _ref.invalidate(familyMemberProvider);
    _ref.invalidate(parcelProvider);
    state = const AuthState();
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
