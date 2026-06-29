import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/network/dio_client_provider.dart';
import '../core/network/interceptors/society_context_interceptor.dart';
import '../core/theme/society_theme_cache.dart';
import '../core/theme/theme_repository.dart';
import '../core/utils/storage_service.dart';
import '../core/theme/app_colors_bridge.dart';
import 'app_colors.dart';

/// =========================================================================
///  Theme-mode controller
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

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

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
    AppColorBridge.applyPalette(state.light);
  }

  static ThemeTokens _readInitialTokens() {
    final boot = SocietyThemeCache.peekBootstrapPalette();
    if (boot != null) {
      return ThemeTokens.defaults.copyWith(light: boot);
    }
    final sid = SocietyThemeCache.activeSocietyId();
    if (sid == null) return ThemeTokens.defaults;
    final cached = SocietyThemeCache.readPalette(sid);
    if (cached == null) return ThemeTokens.defaults;
    return ThemeTokens.defaults.copyWith(light: cached);
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

  /// Logout / explicit default: re-apply cached palette for the last picked
  /// society when available — avoids a green flash on the login screen.
  void resetToCachedOrDefaults({String? societyId}) {
    final sid = societyId?.trim() ??
        SocietyThemeCache.activeSocietyId();
    final cached =
        sid != null && sid.isNotEmpty ? SocietyThemeCache.readPalette(sid) : null;
    if (cached != null) {
      state = ThemeTokens.defaults.copyWith(light: cached);
      AppColorBridge.applyPalette(cached);
      return;
    }
    state = ThemeTokens.defaults;
    AppColorBridge.reset();
  }

  /// Society uses platform defaults (null theme in DB).
  Future<void> clearSocietyTheme(String societyId) async {
    await SocietyThemeCache.clearTheme(societyId);
    resetToCachedOrDefaults(societyId: societyId);
  }
}

final themeTokensProvider =
    StateNotifierProvider<ThemeTokensNotifier, ThemeTokens>((ref) {
  return ThemeTokensNotifier();
});

final societyThemeScopeIdProvider = StateProvider<String?>((ref) {
  return SocietyThemeCache.activeSocietyId();
});

/// Bumped on each refresh so stale in-flight fetches cannot overwrite the palette.
final _themeFetchGenerationProvider = StateProvider<int>((ref) => 0);

/// Apply the on-disk palette for [societyId] immediately (no network).
void applyCachedSocietyTheme(WidgetRef ref, String societyId) {
  final palette = SocietyThemeCache.readPalette(societyId);
  if (palette != null) {
    ref.read(themeTokensProvider.notifier).set(light: palette);
  }
}

void applyCachedSocietyThemeFromRef(Ref ref, String societyId) {
  final palette = SocietyThemeCache.readPalette(societyId);
  if (palette != null) {
    ref.read(themeTokensProvider.notifier).set(light: palette);
  }
}

/// Apply cached palette + update scope id (instant, no network).
void syncSocietyThemeScope(WidgetRef ref, {String? societyId}) {
  final sid = societyId?.trim() ??
      StorageService.getSocietyId()?.trim() ??
      StorageService.getPreferredLoginSocietyId()?.trim();
  ref.read(societyThemeScopeIdProvider.notifier).state =
      (sid == null || sid.isEmpty) ? null : sid;
  if (sid != null && sid.isNotEmpty) {
    applyCachedSocietyTheme(ref, sid);
  }
}

void syncSocietyThemeScopeFromRef(Ref ref, {String? societyId}) {
  final sid = societyId?.trim() ??
      StorageService.getSocietyId()?.trim() ??
      StorageService.getPreferredLoginSocietyId()?.trim();
  ref.read(societyThemeScopeIdProvider.notifier).state =
      (sid == null || sid.isEmpty) ? null : sid;
  if (sid != null && sid.isNotEmpty) {
    applyCachedSocietyThemeFromRef(ref, sid);
  }
}

final themeRepositoryProvider = Provider<ThemeRepository>((ref) {
  return ThemeRepository(ref.watch(dioClientProvider));
});

/// Fetch society appearance from the API and apply when still current.
/// Always paints disk cache before the first await.
Future<void> _fetchAndApplySocietyTheme(
  T Function<T>(ProviderListenable<T> provider) read, {
  String? societyId,
  int? generation,
}) async {
  final sid = (societyId?.trim() ??
          read(societyThemeScopeIdProvider)?.trim() ??
          SocietyThemeCache.activeSocietyId()?.trim() ??
          '')
      .trim();
  if (sid.isEmpty) return;

  final gen = generation ?? read(_themeFetchGenerationProvider);
  final palette = SocietyThemeCache.readPalette(sid);
  if (palette != null) {
    read(themeTokensProvider.notifier).set(light: palette);
  }

  bool stale() => read(_themeFetchGenerationProvider) != gen;

  final cachedJson = SocietyThemeCache.readThemeJson(sid);
  final repo = read(themeRepositoryProvider);

  SocietyAppearance appearance =
      await repo.fetchSocietyAppearanceById(sid);
  if (stale()) return;

  if (!appearance.ok) {
    appearance = await repo.fetchSocietyTheme();
  }
  if (stale()) return;

  if (!appearance.ok) {
    final cached = SocietyThemeCache.readPalette(sid);
    if (cached != null) {
      read(themeTokensProvider.notifier).set(light: cached);
    }
    return;
  }

  final splashUrl = appearance.splashUrl?.trim();
  if (splashUrl != null && splashUrl.isNotEmpty) {
    await SocietyThemeCache.ensureSplashFile(sid, splashUrl);
  } else {
    await SocietyThemeCache.clearSplashFile(sid);
  }
  if (stale()) return;

  final colors = appearance.themeColors;
  if (colors == null || colors.isEmpty) {
    await read(themeTokensProvider.notifier).clearSocietyTheme(sid);
    return;
  }

  if (SocietyThemeCache.themeJsonEquals(cachedJson, colors)) {
    final cached = SocietyThemeCache.readPalette(sid);
    if (cached != null) {
      read(themeTokensProvider.notifier).set(light: cached);
    }
    return;
  }

  await SocietyThemeCache.writeThemeJson(sid, colors);
  if (stale()) return;
  final newLight = AppColorPalette.fromApiJson(colors, AppColorPalette.light);
  read(themeTokensProvider.notifier).set(light: newLight);
}

void _bumpThemeFetchGeneration(
  T Function<T>(ProviderListenable<T> provider) read,
) {
  read(_themeFetchGenerationProvider.notifier).update((g) => g + 1);
}

int _currentThemeFetchGeneration(
  T Function<T>(ProviderListenable<T> provider) read,
) =>
    read(_themeFetchGenerationProvider);

/// Re-apply cached palette after logout (cache survives [StorageService.clearAll]).
void handleAuthLogoutTheme(WidgetRef ref) {
  _bumpThemeFetchGeneration(ref.read);
  syncSocietyThemeScope(ref);
  ref.read(themeTokensProvider.notifier).resetToCachedOrDefaults();
  refreshSocietyThemeFromServer(ref);
}

/// Sync cache, then refresh from server without invalidating providers
/// (avoids a green flash from stale/racing FutureProvider rebuilds).
void refreshSocietyThemeFromServer(WidgetRef ref, {String? societyId}) {
  syncSocietyThemeScope(ref, societyId: societyId);
  SocietyContextInterceptor.clearCache();
  _bumpThemeFetchGeneration(ref.read);
  final gen = _currentThemeFetchGeneration(ref.read);
  unawaited(
    _fetchAndApplySocietyTheme(ref.read, societyId: societyId, generation: gen),
  );
}

void refreshSocietyThemeFromServerRef(Ref ref, {String? societyId}) {
  syncSocietyThemeScopeFromRef(ref, societyId: societyId);
  SocietyContextInterceptor.clearCache();
  _bumpThemeFetchGeneration(ref.read);
  final gen = _currentThemeFetchGeneration(ref.read);
  unawaited(
    _fetchAndApplySocietyTheme(ref.read, societyId: societyId, generation: gen),
  );
}

/// Fetch + cache before navigating to login (after society pick).
Future<void> prefetchSocietyAppearance(WidgetRef ref, String societyId) async {
  syncSocietyThemeScope(ref, societyId: societyId);
  SocietyContextInterceptor.clearCache();
  _bumpThemeFetchGeneration(ref.read);
  final gen = _currentThemeFetchGeneration(ref.read);
  try {
    await _fetchAndApplySocietyTheme(ref.read, societyId: societyId, generation: gen);
  } catch (_) {
    applyCachedSocietyTheme(ref, societyId);
  }
}

/// One-shot boot refresh — never invalidated so palette is not reset mid-flight.
final applyRemoteThemeProvider = FutureProvider<void>((ref) async {
  syncSocietyThemeScopeFromRef(ref);
  final sid = (ref.read(societyThemeScopeIdProvider) ?? '').trim();
  if (sid.isEmpty) return;
  final gen = ref.read(_themeFetchGenerationProvider);
  await _fetchAndApplySocietyTheme(ref.read, societyId: sid, generation: gen);
});
