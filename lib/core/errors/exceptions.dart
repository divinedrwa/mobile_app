/// Custom exceptions for the application
class AppException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  AppException({
    required this.message,
    this.statusCode,
    this.data,
  });

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException({super.message = 'No internet connection'})
      : super(statusCode: -1);
}

class UnauthorizedException extends AppException {
  UnauthorizedException({super.message = 'Unauthorized access'})
      : super(statusCode: 401);
}

class ForbiddenException extends AppException {
  ForbiddenException({super.message = 'Access forbidden'})
      : super(statusCode: 403);
}

class NotFoundException extends AppException {
  NotFoundException({super.message = 'Resource not found'})
      : super(statusCode: 404);
}

/// Rate limit exceeded (HTTP 429)
/// Thrown when too many requests are made in a short period
class RateLimitException extends AppException {
  final int retryAfter; // Seconds to wait before retrying

  RateLimitException({
    super.message = 'Too many requests. Please try again in a moment.',
    this.retryAfter = 60,
  }) : super(statusCode: 429);
}

class ServerException extends AppException {
  ServerException({
    super.message = 'Server error occurred',
    super.data,
    int? statusCode,
  }) : super(statusCode: statusCode ?? 500);
}

class ValidationException extends AppException {
  ValidationException({super.message = 'Validation failed', super.data})
      : super(statusCode: 400);
}

class CacheException implements Exception {
  final String message;
  CacheException({this.message = 'Cache error'});

  @override
  String toString() => message;
}
