import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

/// Mobile: create MultipartFile from file path on disk.
Future<MultipartFile> createMultipartFile(XFile file) async {
  return MultipartFile.fromFile(file.path, filename: file.name);
}
