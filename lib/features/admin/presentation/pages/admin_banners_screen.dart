import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for managing home carousel banners and events.
class AdminBannersScreen extends ConsumerStatefulWidget {
  const AdminBannersScreen({super.key});

  @override
  ConsumerState<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends ConsumerState<AdminBannersScreen> {
  Future<void> _refresh() async {
    ref.invalidate(adminBannersProvider);
  }

  // Must match the backend BannerType enum exactly.
  static const _types = [
    'EVENT',
    'ANNOUNCEMENT',
    'FESTIVAL',
    'EMERGENCY',
    'MAINTENANCE',
    'OFFER',
    'COMMUNITY',
  ];

  static String _typeLabel(String t) {
    switch (t) {
      case 'EVENT':
        return 'Event';
      case 'ANNOUNCEMENT':
        return 'Announcement';
      case 'FESTIVAL':
        return 'Festival';
      case 'EMERGENCY':
        return 'Emergency';
      case 'MAINTENANCE':
        return 'Maintenance';
      case 'OFFER':
        return 'Offer';
      case 'COMMUNITY':
        return 'Community';
      default:
        return t.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(adminBannersProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Banners & Events',
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
        icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
        label: const Text('Add Banner', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: bannersAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: ShimmerWrap(
              child: Column(
                children: List.generate(
                  3,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: ShimmerBox(height: 88, borderRadius: DesignRadius.lg),
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
                  title: 'Failed to load banners',
                  subtitle: 'Pull down to refresh',
                  actionLabel: 'Retry',
                  onAction: _refresh,
                ),
              ),
            ],
          ),
          data: (banners) {
            if (banners.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: EmptyStateWidget(
                      icon: Icons.view_carousel_outlined,
                      title: 'No banners',
                      subtitle: 'Create banners shown on resident home screens.',
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: banners.length,
              itemBuilder: (context, i) {
                final b = banners[i];
                final id = b['id']?.toString() ?? '';
                final title = b['title']?.toString() ?? 'Banner';
                final type = b['type']?.toString() ?? 'ANNOUNCEMENT';
                final active = b['isActive'] as bool? ?? false;
                final desc = b['description']?.toString() ?? '';
                final imageUrl = b['imageUrl']?.toString() ?? '';

                return EnterprisePanel(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  onTap: () => _showEditSheet(b),
                  child: Row(
                    children: [
                      imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                imageUrl,
                                width: 42,
                                height: 42,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _bannerFallbackIcon(),
                              ),
                            )
                          : _bannerFallbackIcon(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: DesignTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                )),
                            Text(_typeLabel(type),
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
                      Switch.adaptive(
                        value: active,
                        activeColor: DesignColors.success,
                        onChanged: (v) => _toggleActive(id, v),
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

  Widget _bannerFallbackIcon() {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: DesignColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.campaign_outlined,
          color: DesignColors.warning, size: 22),
    );
  }

  Future<void> _toggleActive(String id, bool active) async {
    try {
      await ref
          .read(adminBannerRepositoryProvider)
          .updateBanner(id, isActive: active);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showCreateSheet() => _showForm();

  void _showEditSheet(Map<String, dynamic> b) => _showForm(existing: b);

  void _showForm({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final id = existing?['id']?.toString() ?? '';
    final titleCtl =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final descCtl =
        TextEditingController(text: existing?['description']?.toString() ?? '');
    final imageCtl =
        TextEditingController(text: existing?['imageUrl']?.toString() ?? '');
    var type = existing?['type']?.toString() ?? 'ANNOUNCEMENT';
    if (!_types.contains(type)) type = 'ANNOUNCEMENT';
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
                      Text(isEdit ? 'Edit Banner' : 'New Banner',
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
                        controller: descCtl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: imageCtl,
                        decoration: const InputDecoration(
                          labelText: 'Image URL (optional)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Paste a link to a hosted image (e.g. a public '
                        'Google Drive or website URL).',
                        style: DesignTypography.captionSmall.copyWith(
                          color: DesignColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: type,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(),
                        ),
                        items: _types
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(_typeLabel(t)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setLocal(() => type = v);
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
                                setLocal(() => submitting = true);
                                try {
                                  if (isEdit) {
                                    await ref
                                        .read(adminBannerRepositoryProvider)
                                        .updateBanner(
                                          id,
                                          title: titleCtl.text.trim(),
                                          description: descCtl.text.trim(),
                                          imageUrl: imageCtl.text.trim().isEmpty
                                              ? null
                                              : imageCtl.text.trim(),
                                          type: type,
                                        );
                                  } else {
                                    await ref
                                        .read(adminBannerRepositoryProvider)
                                        .createBanner(
                                          title: titleCtl.text.trim(),
                                          description: descCtl.text.trim(),
                                          imageUrl: imageCtl.text.trim().isEmpty
                                              ? null
                                              : imageCtl.text.trim(),
                                          type: type,
                                        );
                                  }
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
                            : Text(isEdit ? 'Save' : 'Create'),
                      ),
                      if (isEdit) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: ctx,
                              builder: (d) => AlertDialog(
                                title: const Text('Delete banner?'),
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
                              await ref
                                  .read(adminBannerRepositoryProvider)
                                  .deleteBanner(id);
                              if (ctx.mounted) Navigator.pop(ctx);
                              _refresh();
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                          icon: Icon(Icons.delete_outline,
                              color: DesignColors.error),
                          label: Text('Delete',
                              style: TextStyle(color: DesignColors.error)),
                        ),
                      ],
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
      descCtl.dispose();
      imageCtl.dispose();
    });
  }
}
