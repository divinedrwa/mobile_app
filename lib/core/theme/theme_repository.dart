import '../constants/api_endpoints.dart';
import '../network/dio_client.dart';

/// Fetches the society's custom theme colors from the API.
///
/// Returns the raw `themeColors` map on success, or `null` on any error
/// (network failure, unauthenticated, server error) so callers can degrade
/// gracefully to the default palette.
class ThemeRepository {
  const ThemeRepository(this._dioClient);

  final DioClient _dioClient;

  Future<Map<String, dynamic>?> fetchThemeColors() async {
    try {
      final res = await _dioClient.get(ApiEndpoints.societyTheme);
      final body = res.data;
      if (body is! Map<String, dynamic>) return null;
      final colors = body['themeColors'];
      if (colors is Map<String, dynamic>) return colors;
      return null;
    } catch (_) {
      return null;
    }
  }
}
