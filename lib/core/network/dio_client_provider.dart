import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dio_client.dart';

/// Dio Client Provider
final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient();
});
