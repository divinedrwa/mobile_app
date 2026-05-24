/// A single payment method configured for the society.
class PaymentMethodModel {
  final String id;
  final String type;
  final String displayName;
  final int sortOrder;
  final Map<String, dynamic> config;

  const PaymentMethodModel({
    required this.id,
    required this.type,
    required this.displayName,
    required this.sortOrder,
    required this.config,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      sortOrder: json['sortOrder'] as int? ?? 0,
      config: json['config'] as Map<String, dynamic>? ?? {},
    );
  }

  /// UPI VPA address, if this is a UPI_VPA type.
  String? get vpa => type == 'UPI_VPA' ? config['vpa'] as String? : null;

  /// QR code image URL, if this is a UPI_QR type.
  String? get qrCodeUrl => type == 'UPI_QR' ? config['qrCodeUrl'] as String? : null;

  /// Masked bank account number (last 4 digits), if BANK_TRANSFER.
  String? get maskedAccountNumber =>
      type == 'BANK_TRANSFER' ? config['accountNumber'] as String? : null;

  /// Bank name, if BANK_TRANSFER.
  String? get bankName => type == 'BANK_TRANSFER' ? config['bankName'] as String? : null;

  /// IFSC code, if BANK_TRANSFER.
  String? get ifscCode => type == 'BANK_TRANSFER' ? config['ifscCode'] as String? : null;

  /// Account holder name, if BANK_TRANSFER.
  String? get accountHolderName =>
      type == 'BANK_TRANSFER' ? config['accountHolderName'] as String? : null;

  /// Account type, if BANK_TRANSFER.
  String? get accountType => type == 'BANK_TRANSFER' ? config['accountType'] as String? : null;
}
