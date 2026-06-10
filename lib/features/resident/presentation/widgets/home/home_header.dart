import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/theme/design_animations.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/utils/media_url.dart';
import '../../../../../shared/models/user_model.dart';
import '../../../../../theme/context_extensions.dart';
import '../../pages/notifications_center_screen.dart';
import 'home_shared.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.name,
    required this.role,
    required this.user,
    required this.unreadNotifications,
  });

  final String name;
  final UserRole role;
  final UserModel? user;
  final int unreadNotifications;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Late Night';
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    if (h < 21) return 'Good Evening';
    return 'Good Night';
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Platform';
      case UserRole.admin:
        return 'Admin';
      case UserRole.guard:
        return 'Guard';
      case UserRole.resident:
        return 'Resident';
      case UserRole.residentCumAdmin:
        return 'Admin · Resident';
    }
  }

  String _headerOccupantOrRoleBadge(UserRole role, UserModel? user) {
    if (role.isResidentLike) {
      final occ = user?.effectiveOccupantDisplay;
      if (occ != null && occ.isNotEmpty) return occ;
    }
    if (role.isAdminLike &&
        user?.villaId != null &&
        user!.villaId!.isNotEmpty) {
      return 'Admin · Resident';
    }
    return _roleLabel(role);
  }

  @override
  Widget build(BuildContext context) {
    final society = user?.societyName?.trim();

    final unitBlockLabel = <String>[];
    final propLine = user?.effectivePropertyDisplay;
    final unitLine = user?.effectiveUnitDisplay;
    if (propLine != null && propLine.isNotEmpty) unitBlockLabel.add(propLine);
    if (unitLine != null && unitLine.isNotEmpty) unitBlockLabel.add(unitLine);
    if (unitBlockLabel.isEmpty) {
      final unitNo = user?.villaNumber?.trim();
      if (unitNo != null && unitNo.isNotEmpty) {
        unitBlockLabel.add('Unit $unitNo');
      }
      final block = user?.villaBlock?.trim();
      if (block != null && block.isNotEmpty) unitBlockLabel.add('Block $block');
    }
    final unitBlockText = unitBlockLabel.join(' · ');

    final badgeText =
        unreadNotifications > 99 ? '99+' : '$unreadNotifications';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.surface.defaultSurface,
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(14)),
        border: Border(
          bottom: BorderSide(color: context.surface.border),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          _buildHeaderIllustration(),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(kHomePadH, 4, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _HeaderAvatar(name: name, photoUrl: user?.photoUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _greeting(),
                          style: TextStyle(
                            fontSize: 11,
                            color: context.text.secondary,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                            letterSpacing: 0.02,
                          ),
                        ),
                        const SizedBox(height: 2),
                        LayoutBuilder(
                          builder: (context, c) {
                            const gap = 6.0;
                            const pillReserve = 76.0;
                            final nameW = (c.maxWidth - pillReserve - gap)
                                .clamp(48.0, double.infinity);
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: nameW,
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: context.text.primary,
                                      height: 1.18,
                                      letterSpacing: -0.4,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: gap),
                                _buildHeaderActivePill(),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: context.brand.primary
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.badge_outlined,
                                      size: 12,
                                      color: context.brand.primary),
                                  const SizedBox(width: 3),
                                  Text(
                                    _headerOccupantOrRoleBadge(role, user),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: context.brand.primary,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (unitBlockText.isNotEmpty)
                              Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: context.surface.background,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: context.surface.border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.apartment_rounded,
                                      size: 12,
                                      color: DesignColors.primary,
                                    ),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        unitBlockText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: context.text.primary,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (society != null && society.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          KeyedSubtree(
                            key: ValueKey<String>(society),
                            child: GestureDetector(
                              onTap: () {
                                // Route TBD — society detail / switch
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: context.surface.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: context.surface.border,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: context.brand.primary
                                            .withValues(alpha: 0.08),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.domain_rounded,
                                        size: 14,
                                        color: context.brand.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Society',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.4,
                                              color: context.text.secondary,
                                              height: 1,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            society,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: context.text.primary,
                                              height: 1.28,
                                              letterSpacing: -0.15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color: context.text.tertiary,
                                    ),
                                  ],
                                ),
                              ),
                            )
                                .animate()
                                .fadeIn(
                                    duration: 380.ms,
                                    curve: Curves.easeOut)
                                .slideY(
                                  begin:
                                      DesignAnimations.slideNormal,
                                  end: 0,
                                  duration: 380.ms,
                                  curve: Curves.easeOutCubic,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Material(
                    color: context.surface.defaultSurface,
                    elevation: 0,
                    shape: const CircleBorder(),
                    shadowColor: Colors.transparent,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => residentNotificationsEntry,
                          ),
                        );
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: context.surface.border),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none_rounded,
                              color: context.text.primary,
                              size: 20,
                            ),
                            if (unreadNotifications > 0)
                              Positioned(
                                right: 5,
                                top: 5,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal:
                                        unreadNotifications > 9 ? 3 : 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: DesignColors.error,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.white,
                                        width: 1.25),
                                  ),
                                  constraints: const BoxConstraints(
                                      minHeight: 15),
                                  child: Text(
                                    badgeText,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      height: 1.05,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActivePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kHomeGreen.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: kHomeGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'Active',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: kHomeGreen,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIllustration() {
    return Positioned(
      right: 8,
      top: 34,
      child: IgnorePointer(
        child: SizedBox(
          width: 88,
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: 2,
                top: 14,
                child: Icon(
                  Icons.grass_rounded,
                  size: 22,
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                ),
              ),
              Positioned(
                right: 24,
                top: 6,
                child: Icon(
                  Icons.park_rounded,
                  size: 26,
                  color: const Color(0xFF66BB6A).withValues(alpha: 0.16),
                ),
              ),
              Positioned(
                right: 28,
                top: 22,
                child: Icon(
                  Icons.holiday_village_rounded,
                  size: 34,
                  color: DesignColors.primary.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({required this.name, required this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = resolveServerFileUrl(photoUrl);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'R';

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.brand.primary.withValues(alpha: 0.12),
        border: Border.all(
          color: context.brand.primary.withValues(alpha: 0.16),
          width: 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? _initialFallback(context, initial)
          : CachedNetworkImage(
              key: ValueKey(url),
              imageUrl: url,
              cacheKey: url,
              fit: BoxFit.cover,
              width: 44,
              height: 44,
              fadeInDuration: const Duration(milliseconds: 180),
              placeholder: (_, _) => _initialFallback(context, initial),
              errorWidget: (_, _, _) => _initialFallback(context, initial),
            ),
    );
  }

  Widget _initialFallback(BuildContext context, String initial) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: context.brand.primary,
          letterSpacing: -0.35,
          height: 1,
        ),
      ),
    );
  }
}
