import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/dio_client.dart';
import '../network/dio_client_provider.dart';
import 'multipart_file_factory.dart';

/// Image Upload Service
/// Sends multipart image to backend API
/// Backend handles Cloudinary upload
class ImageUploadService {
  final DioClient _dioClient;

  ImageUploadService(this._dioClient);

  /// Upload single image to backend
  /// Backend will handle Cloudinary upload
  Future<String?> uploadImage(XFile imageFile, {String? endpoint}) async {
    try {
      // Prepare multipart form data
      FormData formData = FormData.fromMap({
        'image': await createMultipartFile(imageFile),
      });

      // Send to backend API
      final response = await _dioClient.post(
        endpoint ?? '/upload/image',
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Backend returns the uploaded image URL
        return response.data['url'] as String? ?? response.data['imageUrl'] as String?;
      } else {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Image upload error: $e');
      return null;
    }
  }

  /// Upload multiple images to backend
  Future<List<String>> uploadMultipleImages(
    List<XFile> imageFiles, {
    String? endpoint,
  }) async {
    List<String> uploadedUrls = [];
    
    for (var imageFile in imageFiles) {
      final url = await uploadImage(imageFile, endpoint: endpoint);
      if (url != null) {
        uploadedUrls.add(url);
      }
    }
    
    return uploadedUrls;
  }

  /// Upload image with additional fields
  Future<String?> uploadImageWithData(
    XFile imageFile,
    Map<String, dynamic> additionalData, {
    String? endpoint,
  }) async {
    try {
      // Prepare multipart form data with additional fields
      Map<String, dynamic> formDataMap = {
        'image': await createMultipartFile(imageFile),
        ...additionalData,
      };

      FormData formData = FormData.fromMap(formDataMap);

      // Send to backend API
      final response = await _dioClient.post(
        endpoint ?? '/upload/image',
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['url'] as String? ?? response.data['imageUrl'] as String?;
      } else {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Image upload error: $e');
      return null;
    }
  }

  /// Delete image (backend handles Cloudinary deletion)
  Future<bool> deleteImage(String imageId, {String? endpoint}) async {
    try {
      final response = await _dioClient.delete(
        endpoint ?? '/upload/image/$imageId',
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Delete error: $e');
      return false;
    }
  }
}

/// Image Upload Service Provider
final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  final dioClient = ref.read(dioClientProvider);
  return ImageUploadService(dioClient);
});
