/// Input validation utilities
class Validators {
  // Email validation
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email';
    }
    return null;
  }
  
  // Password validation
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    return null;
  }
  
  // Phone number validation (10 digits)
  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      return 'Enter a valid 10-digit phone number';
    }
    return null;
  }

  /// Phone validation that allows empty (optional fields).
  static String? phoneOptional(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      return 'Enter a valid 10-digit phone number';
    }
    return null;
  }

  /// Vehicle registration number — at least 4 alphanumeric characters.
  static String? vehicleNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter vehicle number';
    }
    final cleaned = value.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.length < 4) {
      return 'Enter a valid vehicle number (e.g. MH12AB1234)';
    }
    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(cleaned)) {
      return 'Only letters and numbers allowed';
    }
    return null;
  }
  
  // Required field validation
  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }
  
  // Minimum length validation
  static String? minLength(String? value, int minLength, [String fieldName = 'This field']) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    if (value.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    return null;
  }
  
  // Maximum length validation
  static String? maxLength(String? value, int maxLength, [String fieldName = 'This field']) {
    if (value != null && value.length > maxLength) {
      return '$fieldName must not exceed $maxLength characters';
    }
    return null;
  }
  
  // Number validation
  static String? number(String? value, [String fieldName = 'This field']) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    if (double.tryParse(value) == null) {
      return '$fieldName must be a valid number';
    }
    return null;
  }
  
  // Username validation (alphanumeric, underscore, hyphen)
  static String? username(String? value) {
    if (value == null || value.isEmpty) {
      return 'Username is required';
    }
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_-]{3,20}$');
    if (!usernameRegex.hasMatch(value)) {
      return 'Username must be 3-20 characters (letters, numbers, _, -)';
    }
    return null;
  }
  
  // Confirm password validation
  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }
}
