import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/models/document_model.dart';
import '../../data/providers/content_provider.dart';
import '../widgets/community/community_ui.dart';
import 'document_preview_screen.dart';

final documentCategoryFilterProvider = StateProvider<DocumentCategory?>(
  (ref) => null,
);

final documentSearchQueryProvider = StateProvider<String>((ref) => '');

class DocumentsListScreen extends ConsumerWidget {
  const DocumentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(documentCategoryFilterProvider);
    final searchQuery = ref.watch(documentSearchQueryProvider);
    final documentsState = ref.watch(documentsProvider);

    final filterLabels = [
      'All',
      ...DocumentCategory.values.map(humanizeDocumentCategory),
    ];
    final selectedIndex = selectedCategory == null
        ? 0
        : DocumentCategory.values.indexOf(selectedCategory) + 1;

    return ColoredBox(
      color: context.surface.background,
      child: Column(
        children: [
          CommunitySearchField(
            hint: 'Search documents…',
            query: searchQuery,
            onChanged: (v) =>
                ref.read(documentSearchQueryProvider.notifier).state = v,
          ),
          CommunityFilterChipRow(
            labels: filterLabels,
            selectedIndex: selectedIndex,
            onSelected: (i) {
              ref.read(documentCategoryFilterProvider.notifier).state =
                  i == 0 ? null : DocumentCategory.values[i - 1];
            },
          ),
          Expanded(
            child: CommunityListBody<List<DocumentModel>>(
              asyncValue: documentsState,
              onRetry: () => ref.invalidate(documentsProvider),
              emptyIcon: Icons.folder_open_outlined,
              emptyTitle: 'No documents shared yet',
              emptySubtitle:
                  'Your admin will upload society documents here when available.',
              errorTitle: 'Could not load documents',
              dataBuilder: (documents) {
                var filtered = selectedCategory == null
                    ? documents
                    : documents
                        .where((d) => d.category == selectedCategory)
                        .toList();

                if (searchQuery.trim().isNotEmpty) {
                  filtered = filtered
                      .where(
                        (d) => communityMatchesQuery(
                          searchQuery,
                          [
                            d.title,
                            humanizeDocumentCategory(d.category),
                            d.fileType,
                          ],
                        ),
                      )
                      .toList();
                }

                if (filtered.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 48),
                      EmptyStateWidget(
                        icon: Icons.folder_open_outlined,
                        title: 'No documents match',
                        subtitle: 'Try a different search or filter.',
                      ),
                    ],
                  );
                }

                final grouped = <DocumentCategory, List<DocumentModel>>{};
                for (final doc in filtered) {
                  grouped.putIfAbsent(doc.category, () => []).add(doc);
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(documentsProvider),
                  child: ListView(
                    padding: EdgeInsets.all(context.spacing.s16),
                    children: [
                      ...grouped.entries.map((entry) {
                        final count = entry.value.length;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _categoryHeader(context, entry.key, count),
                            SizedBox(height: context.spacing.s12),
                            Container(
                              decoration: BoxDecoration(
                                color: context.surface.defaultSurface,
                                borderRadius: DesignRadius.borderXL,
                                border: Border.all(color: context.surface.border),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  for (int i = 0; i < entry.value.length; i++) ...[
                                    if (i > 0)
                                      Divider(
                                        height: 1,
                                        color: context.surface.border
                                            .withValues(alpha: 0.7),
                                        indent: 16,
                                        endIndent: 16,
                                      ),
                                    _documentRow(context, entry.value[i]),
                                  ],
                                ],
                              ),
                            ),
                            SizedBox(height: context.spacing.s16),
                          ],
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryHeader(
    BuildContext context,
    DocumentCategory category,
    int count,
  ) {
    final info = _categoryInfo(category);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (info['color'] as Color).withValues(alpha: 0.12),
            borderRadius: DesignRadius.borderMD,
          ),
          child: Icon(
            info['icon'] as IconData,
            size: 18,
            color: info['color'] as Color,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          humanizeDocumentCategory(category),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.text.primary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: context.surface.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.surface.border),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.text.secondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _documentRow(BuildContext context, DocumentModel document) {
    final fileInfo = _fileTypeInfo(document.fileType);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDocument(context, document),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (fileInfo['color'] as Color).withValues(alpha: 0.12),
                  borderRadius: DesignRadius.borderLG,
                ),
                child: Icon(
                  fileInfo['icon'] as IconData,
                  size: 22,
                  color: fileInfo['color'] as Color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.text.primary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${document.fileType.toUpperCase()} · ${_formatFileSize(document.fileSize)} · ${_relativeDate(document.uploadedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.text.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Open externally',
                onPressed: () => _launchExternal(context, document.fileUrl),
                icon: Icon(
                  Icons.open_in_new_rounded,
                  color: context.brand.primary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDocument(BuildContext context, DocumentModel document) async {
    final url = document.fileUrl;
    if (url.isEmpty) {
      _showError(context, 'Document URL is not available');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentPreviewScreen(
          title: document.title,
          url: url,
        ),
      ),
    );
  }

  Future<void> _launchExternal(BuildContext context, String fileUrl) async {
    if (fileUrl.isEmpty) {
      _showError(context, 'Document URL is not available');
      return;
    }
    final uri = Uri.parse(fileUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      _showError(context, 'Could not open document');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.state.denied.solid,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Map<String, dynamic> _categoryInfo(DocumentCategory category) {
    switch (category) {
      case DocumentCategory.general:
        return {'icon': Icons.folder_outlined, 'color': const Color(0xFF607D8B)};
      case DocumentCategory.bylaws:
        return {'icon': Icons.gavel_outlined, 'color': const Color(0xFF1565C0)};
      case DocumentCategory.minutes:
        return {'icon': Icons.event_note_outlined, 'color': const Color(0xFFE65100)};
      case DocumentCategory.financial:
        return {'icon': Icons.account_balance_outlined, 'color': const Color(0xFF2E7D32)};
      case DocumentCategory.policy:
        return {'icon': Icons.policy_outlined, 'color': const Color(0xFF6A1B9A)};
      case DocumentCategory.form:
        return {'icon': Icons.description_outlined, 'color': const Color(0xFF00838F)};
    }
  }

  Map<String, dynamic> _fileTypeInfo(String fileType) {
    final type = fileType.toLowerCase();
    if (type == 'pdf') {
      return {'icon': Icons.picture_as_pdf, 'color': const Color(0xFFC62828)};
    }
    if (type == 'doc' || type == 'docx') {
      return {'icon': Icons.description, 'color': const Color(0xFF1565C0)};
    }
    if (type == 'xls' || type == 'xlsx') {
      return {'icon': Icons.table_chart, 'color': const Color(0xFF2E7D32)};
    }
    if (type == 'jpg' || type == 'jpeg' || type == 'png') {
      return {'icon': Icons.image_outlined, 'color': const Color(0xFF6A1B9A)};
    }
    return {'icon': Icons.insert_drive_file_outlined, 'color': const Color(0xFF78909C)};
  }

  String _formatFileSize(double bytes) {
    if (bytes < 1024) return '${bytes.toInt()} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _relativeDate(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w ago';
    return DateFormat('MMM d').format(date);
  }
}
