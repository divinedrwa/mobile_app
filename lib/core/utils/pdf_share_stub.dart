import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web: trigger browser download via Blob + AnchorElement.
Future<void> sharePdfBytes(Uint8List data, {required String filename}) async {
  final blob = web.Blob(
    <JSUint8Array>[data.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

// Web has no persistent file cache; callers always (re)generate and download.
Future<String?> cachedPdfPath(String filename) async => null;

Future<String> savePdfToCache(Uint8List data, String filename) async {
  await sharePdfBytes(data, filename: filename);
  return '';
}

Future<void> openSavedPdf(String path) async {}

Future<void> shareSavedPdf(String path,
    {String text = 'Maintenance invoice'}) async {}

Future<void> clearInvoicePdfCache() async {}

