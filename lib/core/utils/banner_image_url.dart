import 'image_url.dart';
import 'media_url.dart';

/// Resolves banner/notice image paths for [CachedNetworkImage].
String? resolveBannerImageUrl(String? raw, {int width = 1200}) {
  if (raw == null || raw.trim().isEmpty) return null;
  final resolved = resolveServerFileUrl(raw.trim()) ?? raw.trim();
  if (resolved.contains('res.cloudinary.com')) {
    return optimizedCloudinaryUrl(resolved, width: width);
  }
  return resolved;
}

bool isLikelyImageUrl(String? url) {
  if (url == null || url.trim().isEmpty) return false;
  final lower = url.toLowerCase();
  if (lower.contains('res.cloudinary.com') && lower.contains('/image/')) {
    return true;
  }
  return RegExp(r'\.(png|jpe?g|gif|webp|bmp|svg)(\?|$)', caseSensitive: false)
      .hasMatch(lower);
}
