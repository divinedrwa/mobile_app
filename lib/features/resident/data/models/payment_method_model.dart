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

  /// UPI VPA address (UPI_VPA type, or decoded from UPI_QR bank QR).
  String? get vpa {
    if (type == 'UPI_VPA') return config['vpa'] as String?;
    if (type == 'UPI_QR') return config['vpa'] as String?;
    return null;
  }

  /// Payee name decoded from bank UPI QR (UPI_QR type).
  String? get payeeName =>
      type == 'UPI_QR' ? config['payeeName'] as String? : null;

  /// Canonical upi://pay URI from bank QR (includes mc etc.) for UPI intent.
  String? get upiPayUri =>
      type == 'UPI_QR' ? config['upiPayUri'] as String? : null;

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

  /// Platform fee % on maintenance (RAZORPAY / optional PHONEPE config).
  double? get feePercent {
    if (type != 'RAZORPAY' && type != 'PHONEPE') return null;
    final v = config['feePercent'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  /// GST % applied to the platform fee (defaults to 18 when unset).
  double get feeGstPercent {
    final v = config['feeGstPercent'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 18;
  }

  /// Human-readable gateway surcharge label, e.g. `~2% platform fee + GST`.
  String get gatewayFeeSummaryLabel {
    final configured = feePercent;
    final pct = configured ?? 2;
    final pctText = pct % 1 == 0 ? '${pct.toInt()}' : pct.toStringAsFixed(1);
    final prefix = configured == null ? '~' : '';
    return '$prefix$pctText% platform fee + GST';
  }
}
