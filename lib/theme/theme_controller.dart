import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/network/dio_client_provider.dart';
import '../core/theme/theme_repository.dart';
import '../core/utils/storage_service.dart';
import '../core/theme/app_colors_bridge.dart';
import 'app_colors.dart';

/// =========================================================================
///  Theme-mode controller
///
///  Persists the user's Light / Dark / System preference in
///  [SharedPreferences] under [AppConstants.keyThemeMode]. Defaults to
///  [ThemeMode.system] so the OS setting wins until the user picks.
///
///  This is the same persistence key as the legacy `themeModeProvider` in
///  `lib/core/theme/theme_mode_provider.dart`, so both controllers can
///  co-exist during the gradual migration of existing screens.
/// =========================================================================
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(_readInitial());

  static ThemeMode _readInitial() =>
      _decode(StorageService.getString(AppConstants.keyThemeMode));

  static ThemeMode _decode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      case null:
      default:
        return ThemeMode.system;
    }
  }

  static String _encode(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await StorageService.setString(AppConstants.keyThemeMode, _encode(mode));
  }
}

/// Riverpod entry point. Widgets:
/// ```dart
/// final mode = ref.watch(themeModeProvider);
/// ref.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
/// ```
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// =========================================================================
///  Theme-tokens controller
///
///  Holds the active [AppColorPalette] for each brightness. **Today**
///  these are the compile-time defaults. **Tomorrow**, when you wire an
///  API endpoint such as `GET /api/theme`, do:
///
///  ```dart
///  ref.read(themeTokensProvider.notifier).set(
///    light: paletteFromApiLight,
///    dark: paletteFromApiDark,
///  );
///  ```
///
///  `MaterialApp` will rebuild because it watches this provider, and every
///  widget that reads `context.brand` / `context.surface` / `context.text`
///  / `context.state` will reflect the new values atomically.
/// =========================================================================
@immutable
class ThemeTokens {
  const ThemeTokens({required this.light, required this.dark});

  final AppColorPalette light;
  final AppColorPalette dark;

  ThemeTokens copyWith({AppColorPalette? light, AppColorPalette? dark}) =>
      ThemeTokens(
        light: light ?? this.light,
        dark: dark ?? this.dark,
      );

  static const ThemeTokens defaults = ThemeTokens(
    light: AppColorPalette.light,
    dark: AppColorPalette.dark,
  );
}

class ThemeTokensNotifier extends StateNotifier<ThemeTokens> {
  ThemeTokensNotifier() : super(_readInitialTokens()) {
    // Seed the static bridge with the (possibly cached) initial light palette
    // so DesignColors/AppColors resolve correctly on the very first frame.
    AppColorBridge.applyPalette(state.light);
  }

  /// Initial tokens: the last society palette cached from a prior session
  /// (applied synchronously so there's no default→society flash on launch),
  /// falling back to the compile-time defaults.
  static ThemeTokens _readInitialTokens() {
    final cached = _readCachedLightPalette();
    if (cached == null) return ThemeTokens.defaults;
    return ThemeTokens.defaults.copyWith(light: cached);
  }

  static AppColorPalette? _readCachedLightPalette() {
    final raw = StorageService.getString(AppConstants.keyCachedSocietyTheme);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AppColorPalette.fromApiJson(decoded, AppColorPalette.light);
      }
    } catch (_) {
      // Corrupt cache — ignore and fall back to defaults.
    }
    return null;
  }

  void set({AppColorPalette? light, AppColorPalette? dark}) {
    if (light != null) {
      state = state.copyWith(light: light);
      AppColorBridge.applyPalette(light);
    }
    if (dark != null) {
      state = state.copyWith(dark: dark);
    }
  }

  /// Reset to the compile-time defaults and drop the cached society palette.
  void reset() {
    state = ThemeTokens.defaults;
    AppColorBridge.reset();
    unawaited(StorageService.setString(AppConstants.keyCachedSocietyTheme, ''));
  }
}

final themeTokensProvider =
    StateNotifierProvider<ThemeTokensNotifier, ThemeTokens>((ref) {
  return ThemeTokensNotifier();
});

// =========================================================================
//  Remote theme providers
// =========================================================================

/// Provides a [ThemeRepository] backed by the shared [DioClient].
final themeRepositoryProvider = Provider<ThemeRepository>((ref) {
  return ThemeRepository(ref.watch(dioClientProvider));
});

/// Fetches the society's custom theme colors from the API and applies them
/// to [themeTokensProvider] (light palette only).
///
/// This is a fire-and-forget [FutureProvider.autoDispose] — it silently
/// no-ops when the user is not logged in (the API returns 401, which the
/// repository catches and returns null). Watching it in [MaterialApp.builder]
/// ensures it re-runs whenever the provider is invalidated (e.g., after login
/// or a society switch).
final applyRemoteThemeProvider = FutureProvider.autoDispose<void>((ref) async {
  final repo = ref.watch(themeRepositoryProvider);
  final theme = await repo.fetchSocietyTheme();
  // Splash image is independent of the palette — cache it (or clear) for the
  // next launch's splash screen regardless of whether colors are customized.
  await StorageService.setString(
    AppConstants.keyCachedSplashUrl,
    theme.splashUrl ?? '',
  );
  if (theme.colors == null) {
    // reset() also clears the cached society palette.
    AppColorBridge.reset();
    ref.read(themeTokensProvider.notifier).reset();
    return;
  }
  // Cache the raw palette so the next launch paints it on the first frame
  // (no default→society flash) before this network fetch completes.
  await StorageService.setString(
    AppConstants.keyCachedSocietyTheme,
    jsonEncode(theme.colors),
  );
  final newLight = AppColorPalette.fromApiJson(theme.colors!, AppColorPalette.light);
  ref.read(themeTokensProvider.notifier).set(light: newLight);
});
