class ExpenseAttachmentModel {
  final String id;
  final String fileName;
  final String fileUrl;
  final String fileType;
  final int fileSize;
  final DateTime uploadedAt;

  const ExpenseAttachmentModel({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    required this.uploadedAt,
  });

  factory ExpenseAttachmentModel.fromJson(Map<String, dynamic> json) {
    return ExpenseAttachmentModel(
      id: json['id'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      fileUrl: json['fileUrl'] as String? ?? '',
      fileType: json['fileType'] as String? ?? '',
      fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
      uploadedAt: DateTime.tryParse(
            (json['uploadedAt'] ?? json['createdAt'] ?? '') as String,
          ) ??
          DateTime.now(),
    );
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool get isImage {
    final lower = fileType.toLowerCase();
    return lower.contains('image') ||
        lower == 'jpg' ||
        lower == 'jpeg' ||
        lower == 'png' ||
        lower == 'gif' ||
        lower == 'webp';
  }

  bool get isPdf {
    final lower = fileType.toLowerCase();
    return lower.contains('pdf');
  }

  String get extensionLabel {
    if (isPdf) return 'PDF';
    if (isImage) return 'Image';
    final ext = fileName.split('.').last.toUpperCase();
    return ext.length <= 5 ? ext : 'File';
  }
}
