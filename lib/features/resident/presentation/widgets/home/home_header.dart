import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/design_tokens.dart';
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

  String _occupantChipLabel() {
    if (role.isResidentLike) {
      final occ = user?.effectiveOccupantDisplay;
      if (occ != null && occ.isNotEmpty) return occ;
    }
    if (role.isAdminLike &&
        user?.villaId != null &&
        user!.villaId!.isNotEmpty) {
      return 'Admin · Resident';
    }
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.residentCumAdmin:
        return 'Admin · Resident';
      case UserRole.resident:
        return 'Resident';
      default:
        return 'Resident';
    }
  }

  String? _unitLocationChip() {
    final parts = <String>[];
    final prop = user?.effectivePropertyDisplay;
    final unit = user?.effectiveUnitDisplay;
    if (prop != null && prop.isNotEmpty) parts.add(prop);
    if (unit != null && unit.isNotEmpty) parts.add(unit);
    if (parts.isEmpty) {
      final n = user?.villaNumber?.trim();
      final b = user?.villaBlock?.trim();
      if (n != null && n.isNotEmpty) parts.add(n);
      if (b != null && b.isNotEmpty && (n == null || !parts.contains(b))) {
        parts.add(b);
      }
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final society = user?.societyName?.trim();
    final unitChip = _unitLocationChip();
    final badgeText =
        unreadNotifications > 99 ? '99+' : '$unreadNotifications';

    return Container(
      width: double.infinity,
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kHomePadH, 10, kHomePadH, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderAvatar(name: name, photoUrl: user?.photoUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_greeting()} 👋',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: context.text.secondary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: context.text.primary,
                                  letterSpacing: -0.4,
                                  height: 1.15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _ActivePill(),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _InfoChip(
                              label: _occupantChipLabel(),
                              icon: Icons.person_outline_rounded,
                              background: kHomePurpleLight,
                              foreground: kHomePurple,
                              border: kHomePurple.withValues(alpha: 0.15),
                            ),
                            if (unitChip != null)
                              _InfoChip(
                                label: unitChip,
                                icon: Icons.apartment_rounded,
                                background: const Color(0xFFECFDF5),
                                foreground: const Color(0xFF15803D),
                                border: const Color(0xFF86EFAC)
                                    .withValues(alpha: 0.45),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _NotificationButton(
                    unread: unreadNotifications,
                    badgeText: badgeText,
                  ),
                ],
              ),
              if (society != null && society.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SocietyCard(societyName: society),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF86EFAC).withValues(alpha: 0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GreenDot(),
          SizedBox(width: 4),
          Text(
            'Active',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF16A34A),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _GreenDot extends StatelessWidget {
  const _GreenDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: const BoxDecoration(
        color: Color(0xFF16A34A),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: foreground,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({
    required this.unread,
    required this.badgeText,
  });

  final int unread;
  final String badgeText;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surface.defaultSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.surface.border),
            boxShadow: homeCardShadow(0.04),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.notifications_outlined,
                color: context.text.primary,
                size: 20,
              ),
              if (unread > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: unread > 9 ? 4 : 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: DesignColors.error,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    constraints: const BoxConstraints(minHeight: 16),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocietyCard extends StatelessWidget {
  const _SocietyCard({required this.societyName});

  final String societyName;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/resident/overview'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            kHomePurple.withValues(alpha: 0.08),
            const Color(0xFFEEF2FF),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kHomePurple.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: 8,
            top: 8,
            bottom: 8,
            child: IgnorePointer(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(
                    Icons.park_rounded,
                    size: 28,
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.35),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.apartment_rounded,
                    size: 42,
                    color: kHomePurple.withValues(alpha: 0.18),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: kHomePurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.domain_rounded,
                        size: 16,
                        color: kHomePurple,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Society',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: context.text.secondary,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  societyName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: context.text.primary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: context.text.tertiary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 12,
                      color: kHomePurple.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Safe · Secure · Connected',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: kHomePurple.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kHomePurpleLight,
        border: Border.all(
          color: kHomePurple.withValues(alpha: 0.16),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? _initialFallback(initial)
          : CachedNetworkImage(
              key: ValueKey(url),
              imageUrl: url,
              cacheKey: url,
              fit: BoxFit.cover,
              width: 46,
              height: 46,
              fadeInDuration: const Duration(milliseconds: 180),
              placeholder: (_, _) => _initialFallback(initial),
              errorWidget: (_, _, _) => _initialFallback(initial),
            ),
    );
  }

  Widget _initialFallback(String initial) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: kHomePurple,
          letterSpacing: -0.35,
          height: 1,
        ),
      ),
    );
  }
}
