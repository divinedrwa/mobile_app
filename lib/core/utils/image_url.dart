/// Image URL helpers.
///
/// For Cloudinary delivery URLs, inject auto-format/auto-quality (+ optional
/// width) transformations so large uploads (e.g. a multi-MB splash PNG) are
/// served as a small, fast WebP. The transformed URL is stable per source
/// image (Cloudinary bumps the `v<version>` segment only when the image is
/// re-uploaded), so `CachedNetworkImage` keeps it on disk and re-downloads
/// only when the admin actually changes the image.
String optimizedCloudinaryUrl(String url, {int width = 1080}) {
  const marker = '/image/upload/';
  final i = url.indexOf(marker);
  if (i == -1) return url; // not a Cloudinary delivery URL — leave as-is
  final insertAt = i + marker.length;
  final rest = url.substring(insertAt);
  // Already transformed? don't double-insert.
  if (rest.startsWith('f_auto') ||
      rest.startsWith('q_auto') ||
      rest.startsWith('w_')) {
    return url;
  }
  return '${url.substring(0, insertAt)}f_auto,q_auto,w_$width/$rest';
}
