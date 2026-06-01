import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile: write to temp dir and share via system share sheet.
Future<void> sharePdfBytes(Uint8List data, {required String filename}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(data);
  await Share.shareXFiles([XFile(file.path)], text: 'Maintenance report');
}
