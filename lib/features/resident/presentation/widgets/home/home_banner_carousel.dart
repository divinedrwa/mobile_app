import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/theme/design_animations.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/utils/media_url.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../data/models/banner_model.dart';
import '../../../data/providers/banner_provider.dart';
import 'home_shared.dart';

class HomeBannerCarousel extends ConsumerWidget {
  const HomeBannerCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(activeBannersProvider);
    return bannersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: ShimmerWrap(
          child: ShimmerBox(height: 148, borderRadius: DesignRadius.xl),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (banners) {
        if (banners.isEmpty) return const SizedBox.shrink();
        return _BannerCarouselWidget(banners: banners);
      },
    );
  }
}

class _BannerCarouselWidget extends StatefulWidget {
  const _BannerCarouselWidget({required this.banners});
  final List<BannerModel> banners;

  @override
  State<_BannerCarouselWidget> createState() => _BannerCarouselWidgetState();
}

class _BannerCarouselWidgetState extends State<_BannerCarouselWidget> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.banners.length > 1) {
      _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !_pageController.hasClients) return;
        final next = (_currentPage + 1) % widget.banners.length;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Color _bannerTypeColor(String type) {
    return switch (type.toUpperCase()) {
      'EMERGENCY' => DesignColors.error,
      'MAINTENANCE' => DesignColors.warning,
      'EVENT' || 'FESTIVAL' => const Color(0xFF7C3AED),
      'OFFER' => const Color(0xFF2563EB),
      'COMMUNITY' => DesignColors.primary,
      _ => DesignColors.info,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kHomeSectionGap),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.banners.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) {
                final banner = widget.banners[index];
                final typeColor = _bannerTypeColor(banner.type);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () {
                      if (banner.actionUrl != null &&
                          banner.actionUrl!.isNotEmpty) {
                        launchUrl(Uri.parse(banner.actionUrl!),
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(kHomeRadiusLg),
                        border: Border.all(
                          color: typeColor.withValues(alpha: 0.2),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (banner.imageUrl != null &&
                              banner.imageUrl!.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: resolveServerFileUrl(
                                      banner.imageUrl!) ??
                                  banner.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color:
                                    typeColor.withValues(alpha: 0.06),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color:
                                    typeColor.withValues(alpha: 0.06),
                              ),
                            ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black
                                      .withValues(alpha: 0.65),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: typeColor,
                                borderRadius: BorderRadius.circular(
                                    DesignRadius.full),
                              ),
                              child: Text(
                                banner.type,
                                style: DesignTypography.captionSmall
                                    .copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 14,
                            left: 14,
                            right: 14,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  banner.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: DesignTypography.headingM
                                      .copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (banner.description != null &&
                                    banner
                                        .description!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    banner.description!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: DesignTypography.bodySmall
                                        .copyWith(
                                      color: Colors.white
                                          .withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.banners.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children:
                  List.generate(widget.banners.length, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? DesignColors.primary
                        : DesignColors.primary
                            .withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(duration: DesignAnimations.durationEntrance)
        .slideY(begin: DesignAnimations.slideSubtle, end: 0);
  }
}
