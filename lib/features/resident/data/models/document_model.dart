import '../../../../core/constants/app_constants.dart';

/// Document model
class DocumentModel {
  final String id;
  final String title;
  final String? description;
  final DocumentCategory category;
  final String fileUrl;
  final String fileType;
  final double fileSize;
  final DateTime uploadedAt;
  final String? uploadedBy;

  DocumentModel({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    required this.uploadedAt,
    this.uploadedBy,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      category: DocumentCategory.values.firstWhere(
        (e) => e.value == json['category'],
        orElse: () => DocumentCategory.general,
      ),
      fileUrl: json['fileUrl'] as String? ?? '',
      // Backend may not have fileType, extract from fileUrl or default
      fileType: json['fileType'] as String? ?? _extractFileType(json['fileUrl'] as String?),
      // Backend may not have fileSize, default to 0
      fileSize: json['fileSize'] != null ? (json['fileSize'] as num).toDouble() : 0.0,
      // Backend uses 'createdAt', mobile expects 'uploadedAt'
      uploadedAt: json['uploadedAt'] != null
          ? DateTime.tryParse(json['uploadedAt'] as String) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
              : DateTime.now()),
      uploadedBy: json['uploadedBy'] as String?,
    );
  }

  static String _extractFileType(String? fileUrl) {
    if (fileUrl == null || fileUrl.isEmpty) return 'unknown';
    final ext = fileUrl.split('.').last.toLowerCase();
    return ext.length <= 5 ? ext : 'unknown';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      'category': category.value,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'fileSize': fileSize,
      'uploadedAt': uploadedAt.toIso8601String(),
      if (uploadedBy != null) 'uploadedBy': uploadedBy,
    };
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '${fileSize.toStringAsFixed(0)} B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String get fileIcon {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return '📄';
      case 'doc':
      case 'docx':
        return '📝';
      case 'xls':
      case 'xlsx':
        return '📊';
      case 'jpg':
      case 'jpeg':
      case 'png':
        return '🖼️';
      default:
        return '📎';
    }
  }
}
