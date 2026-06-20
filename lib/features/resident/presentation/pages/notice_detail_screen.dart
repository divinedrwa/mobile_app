import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/models/notice_model.dart';
import '../widgets/community/community_ui.dart';

/// Modern Professional Notice Detail Screen
class NoticeDetailScreen extends ConsumerWidget {
  final NoticeModel notice;

  const NoticeDetailScreen({super.key, required this.notice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(
        backgroundColor: context.surface.defaultSurface,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back, color: context.text.primary),
        ),
        title: Text(
          'Notice Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.text.primary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Share',
            onPressed: () {
              final buffer = StringBuffer()
                ..writeln(notice.title)
                ..writeln()
                ..writeln(notice.content);
              if (notice.attachmentUrl != null) {
                buffer
                  ..writeln()
                  ..writeln('Attachment: ${notice.attachmentUrl}');
              }
              Share.share(buffer.toString(), subject: notice.title);
            },
            icon: Icon(Icons.share, color: context.text.primary),
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
                  humanizeNoticeCategory(notice.category).toUpperCase(),
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
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: context.text.primary,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 16),

            // Meta Info
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: DesignColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMM d, y • h:mm a').format(notice.publishedAt),
                  style: TextStyle(
                    fontSize: 14,
                    color: context.text.secondary,
                  ),
                ),
                if (notice.publishedBy != null) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.person, size: 16, color: DesignColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      notice.publishedBy!,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.text.secondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24),

            EnterprisePanel(
              child: Text(
                notice.content,
                style: TextStyle(
                  fontSize: 16,
                  color: context.text.primary,
                  height: 1.6,
                ),
              ),
            ),

            // Attachment
            if (notice.attachmentUrl != null) ...[
              const SizedBox(height: 32),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openAttachment(context, notice.attachmentUrl!),
                  borderRadius: DesignRadius.borderXL,
                  child: EnterprisePanel(
                    tone: EnterpriseTone.info,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(DesignSpacing.md),
                          decoration: BoxDecoration(
                            color: DesignColors.primary.withValues(alpha: 0.1),
                            borderRadius: DesignRadius.borderLG,
                          ),
                          child: const Icon(
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
                              Text(
                                'Attachment',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: context.text.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to view or download',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.text.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: context.text.tertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _openAttachment(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid attachment URL'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open attachment'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
