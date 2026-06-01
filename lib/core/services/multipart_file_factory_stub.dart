import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

/// Web: read bytes from XFile (blob URL) and create MultipartFile from bytes.
Future<MultipartFile> createMultipartFile(XFile file) async {
  final bytes = await file.readAsBytes();
  return MultipartFile.fromBytes(bytes, filename: file.name);
}
