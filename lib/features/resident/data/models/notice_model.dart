import '../../../../core/constants/app_constants.dart';

/// Notice model
class NoticeModel {
  final String id;
  final String title;
  final String content;
  final NoticeCategory category;
  final NoticePriority priority;
  final DateTime publishedAt;
  final DateTime? expiresAt;
  final String? attachmentUrl;
  final bool isUrgent;
  final bool isPinned;
  final String? publishedBy;
  /// `SOCIETY` = everyone; `SELECTED` = only chosen residents (you are one of them).
  final String audienceScope;

  NoticeModel({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    this.priority = NoticePriority.normal,
    required this.publishedAt,
    this.expiresAt,
    this.attachmentUrl,
    this.isUrgent = false,
    this.isPinned = false,
    this.publishedBy,
    this.audienceScope = 'SOCIETY',
  });

  factory NoticeModel.fromJson(Map<String, dynamic> json) {
    return NoticeModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      // Backend may not have category field, default to general
      category: json['category'] != null
          ? NoticeCategory.values.firstWhere(
              (e) => e.value == json['category'],
              orElse: () => NoticeCategory.general,
            )
          : NoticeCategory.general,
      // Backend may not have priority field, default to normal
      priority: json['priority'] != null
          ? NoticePriority.values.firstWhere(
              (e) => e.value == json['priority'],
              orElse: () => NoticePriority.normal,
            )
          : NoticePriority.normal,
      // Backend uses 'createdAt', mobile expects 'publishedAt'
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'] as String) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
              : DateTime.now()),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      // Backend uses 'fileUrl', mobile expects 'attachmentUrl'
      attachmentUrl: json['attachmentUrl'] as String? ?? json['fileUrl'] as String?,
      isUrgent: json['isUrgent'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
      publishedBy: json['publishedBy'] as String? ?? json['uploadedBy'] as String?,
      audienceScope: json['audienceScope'] as String? ?? 'SOCIETY',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category.value,
      'priority': priority.value,
      'publishedAt': publishedAt.toIso8601String(),
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      'isUrgent': isUrgent,
      'isPinned': isPinned,
      if (publishedBy != null) 'publishedBy': publishedBy,
      'audienceScope': audienceScope,
    };
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isNew {
    final difference = DateTime.now().difference(publishedAt);
    return difference.inDays < 3;
  }
}
