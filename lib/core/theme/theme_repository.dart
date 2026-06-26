import '../constants/api_endpoints.dart';
import '../network/dio_client.dart';

/// Fetches the society's custom theme colors + splash image from the API.
///
/// Returns `(colors, splashUrl)` — either may be null. On any error (network,
/// unauthenticated, server error) both are null so callers degrade gracefully.
class ThemeRepository {
  const ThemeRepository(this._dioClient);

  final DioClient _dioClient;

  /// By society id, no auth required — used at startup (pre-login) so the
  /// selected theme + uploaded splash appear before the user signs in.
  Future<({Map<String, dynamic>? colors, String? splashUrl})>
      fetchSocietyAppearanceById(String societyId) async {
    if (societyId.trim().isEmpty) return (colors: null, splashUrl: null);
    try {
      final res = await _dioClient
          .get(ApiEndpoints.societyAppearance(societyId.trim()));
      return _parseAppearance(res.data);
    } catch (_) {
      return (colors: null, splashUrl: null);
    }
  }

  ({Map<String, dynamic>? colors, String? splashUrl}) _parseAppearance(
      dynamic body) {
    if (body is! Map<String, dynamic>) return (colors: null, splashUrl: null);
    final rawColors = body['themeColors'];
    final colors = rawColors is Map<String, dynamic> ? rawColors : null;
    final rawSplash = body['splashUrl'];
    final splashUrl =
        rawSplash is String && rawSplash.trim().isNotEmpty ? rawSplash.trim() : null;
    return (colors: colors, splashUrl: splashUrl);
  }

  Future<({Map<String, dynamic>? colors, String? splashUrl})>
      fetchSocietyTheme() async {
    try {
      final res = await _dioClient.get(ApiEndpoints.societyTheme);
      final body = res.data;
      if (body is! Map<String, dynamic>) return (colors: null, splashUrl: null);
      final rawColors = body['themeColors'];
      final colors = rawColors is Map<String, dynamic> ? rawColors : null;
      final rawSplash = body['splashUrl'];
      final splashUrl = rawSplash is String && rawSplash.trim().isNotEmpty
          ? rawSplash.trim()
          : null;
      return (colors: colors, splashUrl: splashUrl);
    } catch (_) {
      return (colors: null, splashUrl: null);
    }
  }
}
