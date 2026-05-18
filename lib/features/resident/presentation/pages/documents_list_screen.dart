import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/models/document_model.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../data/providers/content_provider.dart';

/// Provider for selected document category filter
final documentCategoryFilterProvider = StateProvider<DocumentCategory?>(
  (ref) => null,
);

/// Modern Professional Documents List Screen
class DocumentsListScreen extends ConsumerWidget {
  const DocumentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(documentCategoryFilterProvider);
    final documentsState = ref.watch(documentsProvider);

    return Container(
      color: const Color(0xFFF8F9FB),
      child: Column(
        children: [
          // Modern Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF0F3F6))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    context,
                    ref,
                    label: 'All',
                    category: null,
                    isSelected: selectedCategory == null,
                  ),
                  const SizedBox(width: 8),
                  ...DocumentCategory.values.map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFilterChip(
                        context,
                        ref,
                        label: category.value,
                        category: category,
                        isSelected: selectedCategory == category,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Documents List
          Expanded(
            child: documentsState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 56,
                      color: DesignColors.error,
                    ),
                    const SizedBox(height: 12),
                    Text(error.toString(), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(documentsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (documents) {
                final filteredDocuments = selectedCategory == null
                    ? documents
                    : documents
                          .where((d) => d.category == selectedCategory)
                          .toList();
                final Map<DocumentCategory, List<DocumentModel>> groupedDocs =
                    {};
                for (final doc in filteredDocuments) {
                  groupedDocs.putIfAbsent(doc.category, () => []).add(doc);
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(documentsProvider),
                  child: filteredDocuments.isEmpty
                      ? _buildEmptyState()
                      : ListView(
                          padding: const EdgeInsets.all(DesignSpacing.lg),
                          children: [
                            ...groupedDocs.entries.map((entry) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCategoryHeader(entry.key),
                                  const SizedBox(height: 12),
                                  ...entry.value.map(
                                    (doc) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _buildModernDocumentCard(
                                        context,
                                        doc,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              );
                            }),
                            const SizedBox(height: 8),
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

  Widget _buildFilterChip(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required DocumentCategory? category,
    required bool isSelected,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? Colors.white : DesignColors.textSecondary,
        ),
      ),
      selected: isSelected,
      onSelected: (_) {
        ref.read(documentCategoryFilterProvider.notifier).state = category;
      },
      backgroundColor: DesignColors.surfaceSoft,
      selectedColor: DesignColors.primary,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: DesignRadius.borderXL,
        side: BorderSide(
          color: isSelected ? DesignColors.primary : Colors.grey[300]!,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildCategoryHeader(DocumentCategory category) {
    final categoryInfo = _getCategoryInfo(category);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(DesignSpacing.sm),
          decoration: BoxDecoration(
            color: (categoryInfo['color'] as Color).withValues(alpha: 0.1),
            borderRadius: DesignRadius.borderMD,
          ),
          child: Icon(
            categoryInfo['icon'],
            size: 20,
            color: categoryInfo['color'],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          category.value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: DesignColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildModernDocumentCard(
    BuildContext context,
    DocumentModel document,
  ) {
    final fileInfo = _getFileTypeInfo(document.fileType);

    return InkWell(
      onTap: () {
        _openDocument(context, document.fileUrl);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(DesignSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: DesignColors.borderLight, width: 1),
        ),
        child: Row(
          children: [
            // File Type Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (fileInfo['color'] as Color).withValues(alpha: 0.1),
                borderRadius: DesignRadius.borderLG,
              ),
              child: Icon(fileInfo['icon'], size: 24, color: fileInfo['color']),
            ),

            const SizedBox(width: 14),

            // Document Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: DesignColors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        document.fileType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: fileInfo['color'],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatFileSize(document.fileSize),
                        style: const TextStyle(
                          fontSize: 12,
                          color: DesignColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _getRelativeDate(document.uploadedAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: DesignColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Download Button
            Container(
              decoration: BoxDecoration(
                color: DesignColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                tooltip: 'Download',
                onPressed: () {
                  _openDocument(context, document.fileUrl);
                },
                icon: const Icon(
                  Icons.download_rounded,
                  color: DesignColors.primary,
                  size: 22,
                ),
                padding: const EdgeInsets.all(DesignSpacing.sm),
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 50.ms).slideX(begin: -0.1, end: 0);
  }

  Widget _buildEmptyState() {
    return const EmptyStateWidget(
      icon: Icons.folder_open_outlined,
      title: 'No documents shared yet',
      subtitle: 'Your admin will upload society documents here when available.',
    );
  }

  Map<String, dynamic> _getCategoryInfo(DocumentCategory category) {
    switch (category) {
      case DocumentCategory.general:
        return {'icon': Icons.folder, 'color': Colors.grey};
      case DocumentCategory.bylaws:
        return {'icon': Icons.gavel, 'color': Colors.blue};
      case DocumentCategory.minutes:
        return {'icon': Icons.event_note, 'color': Colors.orange};
      case DocumentCategory.financial:
        return {'icon': Icons.account_balance, 'color': Colors.green};
      case DocumentCategory.policy:
        return {'icon': Icons.policy, 'color': Colors.purple};
      case DocumentCategory.form:
        return {'icon': Icons.description, 'color': Colors.teal};
    }
  }

  Map<String, dynamic> _getFileTypeInfo(String fileType) {
    final type = fileType.toLowerCase();
    if (type == 'pdf') {
      return {'icon': Icons.picture_as_pdf, 'color': Colors.red};
    } else if (type == 'doc' || type == 'docx') {
      return {'icon': Icons.description, 'color': Colors.blue};
    } else if (type == 'xls' || type == 'xlsx') {
      return {'icon': Icons.table_chart, 'color': Colors.green};
    } else if (type == 'jpg' || type == 'jpeg' || type == 'png') {
      return {'icon': Icons.image, 'color': Colors.purple};
    } else {
      return {'icon': Icons.insert_drive_file, 'color': Colors.grey};
    }
  }

  String _formatFileSize(double bytes) {
    if (bytes < 1024) return '${bytes.toInt()} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _getRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  Future<void> _openDocument(BuildContext context, String? fileUrl) async {
    if (fileUrl == null || fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document URL is not available'),
          backgroundColor: DesignColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final uri = Uri.parse(fileUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open document'),
          backgroundColor: DesignColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
