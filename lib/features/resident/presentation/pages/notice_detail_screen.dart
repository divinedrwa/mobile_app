import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/models/notice_model.dart';

/// Modern Professional Notice Detail Screen
class NoticeDetailScreen extends ConsumerWidget {
  final NoticeModel notice;

  const NoticeDetailScreen({super.key, required this.notice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: DesignColors.textPrimary),
        ),
        title: const Text(
          'Notice Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: DesignColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Notice shared!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.share, color: DesignColors.textPrimary),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DesignSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badges
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (notice.isUrgent)
                  _buildBadge(
                    'URGENT',
                    Colors.red.shade700,
                    Colors.red.shade50,
                    Icons.warning_rounded,
                  ),
                if (notice.isNew)
                  _buildBadge(
                    'NEW',
                    Colors.green.shade700,
                    Colors.green.shade50,
                    Icons.fiber_new_rounded,
                  ),
                _buildBadge(
                  notice.category.value.toUpperCase(),
                  DesignColors.primary,
                  DesignColors.primary.withValues(alpha: 0.1),
                  Icons.label_rounded,
                ),
                _buildBadge(
                  notice.priority.value.toUpperCase(),
                  Colors.orange.shade700,
                  Colors.orange.shade50,
                  Icons.priority_high_rounded,
                ),
                if (notice.audienceScope == 'SELECTED')
                  _buildBadge(
                    'FOR YOU',
                    Colors.indigo.shade800,
                    Colors.indigo.shade50,
                    Icons.person_pin_rounded,
                  ),
              ],
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              notice.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: DesignColors.textPrimary,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 16),

            // Meta Info
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: DesignColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMM d, y • h:mm a').format(notice.publishedAt),
                  style: TextStyle(
                    fontSize: 14,
                    color: DesignColors.textSecondary,
                  ),
                ),
                if (notice.publishedBy != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.person, size: 16, color: DesignColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      notice.publishedBy!,
                      style: TextStyle(
                        fontSize: 14,
                        color: DesignColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // Divider
            Container(
              height: 1,
              color: DesignColors.borderLight,
            ),

            const SizedBox(height: 24),

            // Content
            Text(
              notice.content,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[800],
                height: 1.6,
              ),
            ),

            // Attachment
            if (notice.attachmentUrl != null) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(DesignSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: DesignColors.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(DesignSpacing.md),
                      decoration: BoxDecoration(
                        color: DesignColors.primary.withValues(alpha: 0.1),
                        borderRadius: DesignRadius.borderLG,
                      ),
                      child: Icon(
                        Icons.attach_file,
                        color: DesignColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Attachment',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: DesignColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to view or download',
                            style: TextStyle(
                              fontSize: 13,
                              color: DesignColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color textColor, Color bgColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: DesignRadius.borderMD,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
