import '../constants/api_endpoints.dart';
import '../network/dio_client.dart';

/// Result of a society appearance fetch. [ok] is false only on transport/API errors.
class SocietyAppearance {
  const SocietyAppearance({
    required this.ok,
    this.themeColors,
    this.splashUrl,
  });

  final bool ok;
  final Map<String, dynamic>? themeColors;
  final String? splashUrl;
}

/// Fetches the society's custom theme colors + splash image from the API.
class ThemeRepository {
  const ThemeRepository(this._dioClient);

  final DioClient _dioClient;

  /// By society id, no auth required — used at startup (pre-login).
  Future<SocietyAppearance> fetchSocietyAppearanceById(String societyId) async {
    if (societyId.trim().isEmpty) {
      return const SocietyAppearance(ok: false);
    }
    try {
      final res = await _dioClient
          .get(ApiEndpoints.societyAppearance(societyId.trim()));
      final parsed = _parseAppearance(res.data);
      return SocietyAppearance(
        ok: true,
        themeColors: parsed.themeColors,
        splashUrl: parsed.splashUrl,
      );
    } catch (_) {
      return const SocietyAppearance(ok: false);
    }
  }

  /// Authenticated tenant society theme (JWT + X-Society-Id).
  Future<SocietyAppearance> fetchSocietyTheme() async {
    try {
      final res = await _dioClient.get(ApiEndpoints.societyTheme);
      final parsed = _parseAppearance(res.data);
      return SocietyAppearance(
        ok: true,
        themeColors: parsed.themeColors,
        splashUrl: parsed.splashUrl,
      );
    } catch (_) {
      return const SocietyAppearance(ok: false);
    }
  }

  ({Map<String, dynamic>? themeColors, String? splashUrl}) _parseAppearance(
    dynamic body,
  ) {
    if (body is! Map) return (themeColors: null, splashUrl: null);
    final map = body is Map<String, dynamic>
        ? body
        : Map<String, dynamic>.from(body);
    final rawColors = map['themeColors'];
    Map<String, dynamic>? themeColors;
    if (rawColors is Map<String, dynamic>) {
      themeColors = rawColors;
    } else if (rawColors is Map) {
      themeColors = Map<String, dynamic>.from(rawColors);
    }
    final rawSplash = map['splashUrl'];
    final splashUrl = rawSplash is String && rawSplash.trim().isNotEmpty
        ? rawSplash.trim()
        : null;
    return (themeColors: themeColors, splashUrl: splashUrl);
  }
}
