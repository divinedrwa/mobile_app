import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/providers/directory_provider.dart';

class CommunityDirectoryScreen extends ConsumerStatefulWidget {
  const CommunityDirectoryScreen({super.key});

  @override
  ConsumerState<CommunityDirectoryScreen> createState() =>
      _CommunityDirectoryScreenState();
}

class _CommunityDirectoryScreenState
    extends ConsumerState<CommunityDirectoryScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(paginatedDirectoryProvider.notifier).loadMore();
    }
  }

  Future<void> _dialPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        ref.read(paginatedDirectoryProvider.notifier).search(value.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pState = ref.watch(paginatedDirectoryProvider);

    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(
        backgroundColor: context.surface.defaultSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.text.primary),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Community Directory',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: context.text.primary),
            ),
            Text(
              'Residents in your society',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.text.secondary, height: 1.2),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DesignSpacing.lg, DesignSpacing.sm, DesignSpacing.lg, 0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name, villa number or block...',
                hintStyle: DesignTypography.bodySmall.copyWith(
                  color: context.text.tertiary,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: context.text.tertiary,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            size: 18, color: context.text.tertiary),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(paginatedDirectoryProvider.notifier)
                              .search('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: context.surface.defaultSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignRadius.lg),
                  borderSide: BorderSide(color: context.surface.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignRadius.lg),
                  borderSide: BorderSide(color: context.surface.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignRadius.lg),
                  borderSide:
                      BorderSide(color: DesignColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: DesignSpacing.lg,
                  vertical: DesignSpacing.md,
                ),
              ),
              style: DesignTypography.body.copyWith(
                color: context.text.primary,
              ),
            ),
          ),
          const SizedBox(height: DesignSpacing.sm),
          Expanded(child: _buildList(context, pState)),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, dynamic pState) {
    if (pState.isInitialLoad) return _buildShimmer();

    if (pState.error != null && pState.items.isEmpty) {
      return _buildError(context);
    }

    final residents = pState.items;
    if (residents.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.people_outline_rounded,
        title: 'No residents found',
        subtitle: _searchController.text.isNotEmpty
            ? 'Try a different search term.'
            : 'Community directory will appear here.',
        actionLabel: 'Refresh',
        onAction: () =>
            ref.read(paginatedDirectoryProvider.notifier).refresh(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: DesignSpacing.lg),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: context.surface.defaultSurface,
              borderRadius:
                  BorderRadius.circular(DesignRadius.full),
              border: Border.all(color: context.surface.border),
            ),
            child: Text(
              '${pState.total} resident${pState.total != 1 ? "s" : ""}',
              style: DesignTypography.labelSmall.copyWith(
                color: context.text.secondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: DesignSpacing.sm),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await ref.read(paginatedDirectoryProvider.notifier).refresh();
            },
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                  horizontal: DesignSpacing.lg),
              itemCount: residents.length +
                  (pState.hasMore || pState.isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= residents.length) {
                  if (pState.isLoadingMore) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                          child:
                              CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: TextButton(
                        onPressed: () => ref
                            .read(paginatedDirectoryProvider.notifier)
                            .loadMore(),
                        child: const Text('Load more'),
                      ),
                    ),
                  );
                }

                final r = residents[index];
                return Padding(
                  padding:
                      const EdgeInsets.only(bottom: DesignSpacing.xs),
                  child: EnterprisePanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignSpacing.md,
                      vertical: DesignSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: _avatarColor(r.name),
                          child: Text(
                            _initials(r.name),
                            style:
                                DesignTypography.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: DesignSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.name,
                                style: DesignTypography.bodyMedium
                                    .copyWith(
                                  color: context.text.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (r.flatLabel.isNotEmpty)
                                Text(
                                  r.flatLabel,
                                  style: DesignTypography.caption
                                      .copyWith(
                                    color: context.text.secondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (r.phoneMasked != null) ...[
                          Text(
                            r.phoneMasked!,
                            style:
                                DesignTypography.caption.copyWith(
                              color: context.text.tertiary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _dialPhone(r.phoneMasked!),
                            child: Icon(
                              Icons.phone_rounded,
                              size: 20,
                              color: DesignColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
                    .animate(
                        delay: DesignAnimations.staggerFor(index))
                    .fadeIn(
                        duration:
                            DesignAnimations.durationEntrance);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmer() {
    return ShimmerWrap(
      child: Padding(
        padding: const EdgeInsets.all(DesignSpacing.lg),
        child: Column(
          children: List.generate(
            6,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: DesignSpacing.xs),
              child: ShimmerBox(height: 56),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DesignSpacing.lg),
      child: EnterpriseInfoBanner(
        icon: Icons.people_outline_rounded,
        title: 'Could not load directory',
        message: 'Check your connection and try again.',
        tone: EnterpriseTone.danger,
        actionLabel: 'Retry',
        onAction: () => ref.read(paginatedDirectoryProvider.notifier).refresh(),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
}

Color _avatarColor(String name) {
  final palette = [
    Color(0xFF004D40),
    DesignColors.info,
    DesignColors.primary,
    DesignColors.error,
    Color(0xFFF39C12),
    DesignColors.primary,
    DesignColors.primary,
    const Color(0xFFDB2777),
  ];
  final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
  return palette[hash % palette.length];
}
