import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../security/certificate_pins.dart';

/// Mobile: wire up SPKI SHA-256 certificate pinning when enabled.
void configureCertPinning(Dio dio) {
  if (!CertificatePins.enabled || CertificatePins.sha256Pins.isEmpty) return;

  (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) {
      final digest = sha256.convert(cert.der);
      return CertificatePins.sha256Pins.any((pin) => pin == digest.toString());
    };
    return client;
  };
}
