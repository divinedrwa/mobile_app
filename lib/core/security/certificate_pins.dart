/// SHA-256 certificate pins for the API server.
///
/// Each entry is the hex-encoded SHA-256 fingerprint of the DER-encoded
/// SubjectPublicKeyInfo (SPKI) of a certificate in the chain. At least
/// one pin must match for the connection to succeed.
///
/// **Rotation procedure:**
/// 1. Generate the new certificate and compute its SPKI SHA-256.
/// 2. Add the new pin to this list **before** deploying the new cert.
/// 3. Ship an app update with both pins.
/// 4. Deploy the new cert on the server.
/// 5. After all clients have updated, remove the old pin.
///
/// To compute the pin from a PEM certificate:
/// ```bash
/// openssl x509 -in cert.pem -pubkey -noout \
///   | openssl pkey -pubin -outform der \
///   | openssl dgst -sha256 -hex
/// ```
class CertificatePins {
  CertificatePins._();

  /// Set to `true` once production pins are configured.
  /// While `false`, pinning is disabled (all certificates accepted).
  static const bool enabled = false;

  /// SPKI SHA-256 pins (hex-encoded, lowercase, no colons).
  /// Add your production server's certificate pin(s) here.
  static const List<String> sha256Pins = [
    // Example (replace with real pins):
    // 'a]f6b3b1c5d2e4f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0',
  ];
}
