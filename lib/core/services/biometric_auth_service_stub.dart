/// Web stub — biometric auth is not available on web.
class BiometricAuthService {
  Future<bool> deviceCanUseBiometric() async => false;

  Future<bool> authenticate({required String localizedReason}) async => false;
}
