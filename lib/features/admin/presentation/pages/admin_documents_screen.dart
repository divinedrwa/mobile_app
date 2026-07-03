import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for uploading and managing society documents.
class AdminDocumentsScreen extends ConsumerStatefulWidget {
  const AdminDocumentsScreen({super.key});

  @override
  ConsumerState<AdminDocumentsScreen> createState() =>
      _AdminDocumentsScreenState();
}

class _AdminDocumentsScreenState extends ConsumerState<AdminDocumentsScreen> {
  Future<void> _refresh() async {
    ref.invalidate(adminDocumentsProvider);
  }

  // Must match the backend DocumentCategory enum exactly.
  static const _categories = [
    'BYLAW',
    'AGREEMENT',
    'NOC',
    'INVOICE',
    'REPORT',
    'OTHER',
  ];

  static String _categoryLabel(String c) {
    switch (c) {
      case 'BYLAW':
        return 'Bylaw';
      case 'AGREEMENT':
        return 'Agreement';
      case 'NOC':
        return 'NOC';
      case 'INVOICE':
        return 'Invoice';
      case 'REPORT':
        return 'Report';
      case 'OTHER':
        return 'Other';
      default:
        return c.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(adminDocumentsProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Documents',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        backgroundColor: DesignColors.primary,
        icon: const Icon(Icons.upload_file, color: Colors.white),
        label: const Text('Add Document', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: docsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: ShimmerWrap(
              child: Column(
                children: List.generate(
                  4,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: ShimmerBox(height: 72, borderRadius: DesignRadius.lg),
                  ),
                ),
              ),
            ),
          ),
          error: (_, __) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Failed to load documents',
                  subtitle: 'Pull down to refresh',
                  actionLabel: 'Retry',
                  onAction: _refresh,
                ),
              ),
            ],
          ),
          data: (docs) {
            if (docs.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: EmptyStateWidget(
                      icon: Icons.folder_open_outlined,
                      title: 'No documents',
                      subtitle: 'Upload society documents for residents.',
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final d = docs[i];
                final id = d['id']?.toString() ?? '';
                final title = d['title']?.toString() ?? 'Document';
                final category = d['category']?.toString() ?? 'OTHER';
                final desc = d['description']?.toString() ?? '';

                return EnterprisePanel(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: DesignColors.info.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.description_outlined,
                            color: DesignColors.info, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: DesignTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                )),
                            Text(_categoryLabel(category),
                                style: DesignTypography.captionSmall.copyWith(
                                  color: DesignColors.textSecondary,
                                )),
                            if (desc.isNotEmpty)
                              Text(desc,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: DesignTypography.captionSmall),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: Icon(Icons.delete_outline,
                            color: DesignColors.error),
                        onPressed: () => _delete(id, title),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _delete(String id, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('Remove "$title"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminDocumentRepositoryProvider).deleteDocument(id);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showCreateSheet() {
    final titleCtl = TextEditingController();
    final urlCtl = TextEditingController();
    final descCtl = TextEditingController();
    var category = 'OTHER';
    var submitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Add Document',
                          style: DesignTypography.headingM.copyWith(
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleCtl,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: urlCtl,
                        decoration: const InputDecoration(
                          labelText: 'File URL (https://…)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Paste a link to the hosted file (e.g. a shared '
                        'Google Drive or Dropbox link).',
                        style: DesignTypography.captionSmall.copyWith(
                          color: DesignColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtl,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: _categories
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(_categoryLabel(c)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setLocal(() => category = v);
                        },
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                if (titleCtl.text.trim().length < 3) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Title must be at least 3 chars')),
                                  );
                                  return;
                                }
                                if (!urlCtl.text.trim().startsWith('http')) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content: Text('Enter a valid file URL')),
                                  );
                                  return;
                                }
                                setLocal(() => submitting = true);
                                try {
                                  await ref
                                      .read(adminDocumentRepositoryProvider)
                                      .createDocument(
                                        title: titleCtl.text.trim(),
                                        fileUrl: urlCtl.text.trim(),
                                        category: category,
                                        description: descCtl.text.trim(),
                                      );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _refresh();
                                } catch (e) {
                                  if (ctx.mounted) {
                                    setLocal(() => submitting = false);
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                  }
                                }
                              },
                        child: submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Add'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      titleCtl.dispose();
      urlCtl.dispose();
      descCtl.dispose();
    });
  }
}
