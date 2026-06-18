import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile: write to temp dir and share via system share sheet.
Future<void> sharePdfBytes(Uint8List data, {required String filename}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(data);
  await Share.shareXFiles([XFile(file.path)], text: 'Maintenance report');
}

Future<Directory> _invoiceDir() async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory('${base.path}/invoices');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

/// Returns the path of a previously cached PDF for [filename], or null if it
/// hasn't been generated yet.
Future<String?> cachedPdfPath(String filename) async {
  final dir = await _invoiceDir();
  final file = File('${dir.path}/$filename');
  return await file.exists() ? file.path : null;
}

/// Persist [data] under [filename] in the invoices cache and return its path.
Future<String> savePdfToCache(Uint8List data, String filename) async {
  final dir = await _invoiceDir();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(data);
  return file.path;
}

/// Open a saved PDF in the device's default viewer.
Future<void> openSavedPdf(String path) async {
  await OpenFilex.open(path, type: 'application/pdf');
}

/// Share an already-saved PDF file via the system share sheet.
Future<void> shareSavedPdf(String path,
    {String text = 'Maintenance invoice'}) async {
  await Share.shareXFiles([XFile(path)], text: text);
}
