import 'dart:async';
import 'package:flutter/material.dart';
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
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final directoryAsync = ref.watch(directorySearchProvider(_query));

    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(title: const Text('Community Directory')),
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
                          setState(() => _query = '');
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
                      const BorderSide(color: DesignColors.primary, width: 1.5),
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
          Expanded(
            child: directoryAsync.when(
              loading: () => _buildShimmer(),
              error: (err, _) => _buildError(context),
              data: (residents) {
                if (residents.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.people_outline_rounded,
                    title: 'No residents found',
                    subtitle: _query.isNotEmpty
                        ? 'Try a different search term.'
                        : 'Community directory will appear here.',
                    actionLabel: 'Refresh',
                    onAction: () =>
                        ref.invalidate(directorySearchProvider(_query)),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: DesignSpacing.lg),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: context.surface.defaultSurface,
                          borderRadius:
                              BorderRadius.circular(DesignRadius.full),
                          border:
                              Border.all(color: context.surface.border),
                        ),
                        child: Text(
                          '${residents.length} resident${residents.length != 1 ? "s" : ""}',
                          style: DesignTypography.labelSmall.copyWith(
                            color: context.text.secondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: DesignSpacing.sm),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: DesignSpacing.lg),
                        itemCount: residents.length,
                        itemBuilder: (context, index) {
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
                                    backgroundColor:
                                        _avatarColor(r.name),
                                    child: Text(
                                      _initials(r.name),
                                      style: DesignTypography.labelSmall
                                          .copyWith(
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
                                  if (r.phoneMasked != null)
                                    Text(
                                      r.phoneMasked!,
                                      style:
                                          DesignTypography.caption.copyWith(
                                        color: context.text.tertiary,
                                      ),
                                    ),
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
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return ShimmerWrap(
      child: Padding(
        padding: const EdgeInsets.all(DesignSpacing.lg),
        child: Column(
          children: List.generate(
            6,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: DesignSpacing.xs),
              child: const ShimmerBox(height: 56),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: DesignColors.error, size: 48),
          const SizedBox(height: DesignSpacing.sm),
          Text(
            'Failed to load directory',
            style:
                DesignTypography.body.copyWith(color: context.text.secondary),
          ),
          const SizedBox(height: DesignSpacing.sm),
          TextButton(
            onPressed: () =>
                ref.invalidate(directorySearchProvider(_query)),
            child: const Text('Retry'),
          ),
        ],
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
  const palette = [
    Color(0xFF3D8361),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFE53935),
    Color(0xFFF39C12),
    Color(0xFF00897B),
    Color(0xFF8B5CF6),
    Color(0xFFDB2777),
  ];
  final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
  return palette[hash % palette.length];
}
