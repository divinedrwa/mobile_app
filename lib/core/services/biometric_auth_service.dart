import 'package:local_auth/local_auth.dart';

/// Local fingerprint / Face ID (and device PIN as fallback when [biometricOnly] is false).
class BiometricAuthService {
  BiometricAuthService() : _auth = LocalAuthentication();

  final LocalAuthentication _auth;

  /// Returns true if local authentication APIs are available (biometrics or device PIN).
  Future<bool> deviceCanUseBiometric() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({required String localizedReason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
