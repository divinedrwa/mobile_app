import 'expense_attachment_model.dart';
import 'expense_category_model.dart';

class ExpenseModel {
  final String id;
  final String title;
  final String? description;
  final double amount;
  final double netAmount;
  final double? gstAmount;
  final double? tdsAmount;
  final DateTime paymentDate;
  final String paymentMode;
  final String? paymentRef;
  final String paidTo;
  final String? paidToContact;
  final int? month;
  final int? year;
  final String? notes;
  final List<String> tags;
  final String status;
  final ExpenseCategoryModel? category;
  final List<ExpenseAttachmentModel> attachments;
  final int attachmentCount;
  final DateTime createdAt;

  const ExpenseModel({
    required this.id,
    required this.title,
    this.description,
    required this.amount,
    required this.netAmount,
    this.gstAmount,
    this.tdsAmount,
    required this.paymentDate,
    required this.paymentMode,
    this.paymentRef,
    required this.paidTo,
    this.paidToContact,
    this.month,
    this.year,
    this.notes,
    this.tags = const [],
    required this.status,
    this.category,
    this.attachments = const [],
    this.attachmentCount = 0,
    required this.createdAt,
  });

  /// Parse a value that may arrive as num or String (Prisma Decimal).
  static double _toDouble(dynamic v, [double fallback = 0]) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  static double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    final rawAttachments = json['attachments'] as List<dynamic>?;
    final attachments = rawAttachments
            ?.map((e) => ExpenseAttachmentModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList() ??
        const [];

    final rawTags = json['tags'] as List<dynamic>?;
    final tags =
        rawTags?.map((e) => e.toString()).toList() ?? const <String>[];

    final catJson = json['category'];
    final category = catJson is Map
        ? ExpenseCategoryModel.fromJson(Map<String, dynamic>.from(catJson))
        : null;

    return ExpenseModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      amount: _toDouble(json['amount']),
      netAmount: _toDouble(json['netAmount']),
      gstAmount: _toDoubleOrNull(json['gstAmount']),
      tdsAmount: _toDoubleOrNull(json['tdsAmount']),
      paymentDate: DateTime.tryParse(
            (json['paymentDate'] ?? '') as String,
          ) ??
          DateTime.now(),
      paymentMode: json['paymentMode'] as String? ?? '',
      paymentRef: json['paymentRef'] as String?,
      paidTo: json['paidTo'] as String? ?? '',
      paidToContact: json['paidToContact'] as String?,
      month: json['month'] as int?,
      year: json['year'] as int?,
      notes: json['notes'] as String?,
      tags: tags,
      status: json['status'] as String? ?? '',
      category: category,
      attachments: attachments,
      attachmentCount:
          json['attachmentCount'] as int? ?? attachments.length,
      createdAt: DateTime.tryParse(
            (json['createdAt'] ?? '') as String,
          ) ??
          DateTime.now(),
    );
  }

  String get paymentModeLabel {
    switch (paymentMode) {
      case 'CASH':
        return 'Cash';
      case 'UPI':
        return 'UPI';
      case 'BANK_TRANSFER':
        return 'Bank Transfer';
      case 'CHEQUE':
        return 'Cheque';
      case 'CARD':
        return 'Card';
      case 'ONLINE':
        return 'Online';
      default:
        return paymentMode;
    }
  }
}
