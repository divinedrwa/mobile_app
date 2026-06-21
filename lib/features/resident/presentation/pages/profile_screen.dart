import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/screen_skeletons.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/utils/resident_capabilities.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'family_members_screen.dart';
import 'vehicles_screen.dart';
import 'emergency_contacts_screen.dart';
import 'payment_history_screen.dart';
import 'my_complaints_screen.dart';
import 'amenity_booking_history_screen.dart';
import 'settings_screen.dart';
import 'edit_profile_screen.dart';
import 'vendors_staff_screen.dart';

/// Profile — same destinations as before; layout uses shared design tokens.

/// Professional profile screen (options unchanged).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isLoading = authState.isLoading;

    // Only block the screen during login/sign-in when there is no user yet.
    if (isLoading && user == null) {
      return const Scaffold(
        backgroundColor: DesignColors.background,
        body: DetailSkeleton(heroHeight: 120),
      );
    }

    final topInset = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: DesignColors.background,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _ProfileHeroHeader(
            topInset: topInset,
            user: user,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DesignSpacing.lg,
              DesignSpacing.lg,
              DesignSpacing.lg,
              DesignSpacing.xxxl,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ProfileSection(
                  title: 'Personal Information',
                  delayMs: 0,
                  children: [
                    _ProfileTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Edit Profile',
                      subtitle: 'Update your details',
                      iconColor: DesignColors.primary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const EditProfileScreen()),
                      ),
                    ),
                    _divider,
                    _ProfileTile(
                      icon: Icons.family_restroom_outlined,
                      title: 'Family Members',
                      subtitle: 'Manage your family',
                      iconColor: const Color(0xFF7C3AED),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const FamilyMembersScreen()),
                      ),
                    ),
                    _divider,
                    _ProfileTile(
                      icon: Icons.emergency_outlined,
                      title: 'Emergency Contacts',
                      subtitle: 'Quick access contacts',
                      iconColor: DesignColors.error,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const EmergencyContactsScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignSpacing.xl),
                _ProfileSection(
                  title: 'My Assets',
                  delayMs: 40,
                  children: [
                    _ProfileTile(
                      icon: Icons.directions_car_outlined,
                      title: 'Vehicles',
                      subtitle: 'View and manage your vehicles',
                      iconColor: const Color(0xFFEA580C),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const VehiclesScreen()),
                      ),
                    ),
                    _divider,
                    _ProfileTile(
                      icon: Icons.people_outline_rounded,
                      title: 'Vendors',
                      subtitle: 'Manage domestic staff',
                      iconColor: const Color(0xFF0D9488),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const VendorsStaffScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignSpacing.xl),
                _ProfileSection(
                  title: 'Payments & History',
                  delayMs: 80,
                  children: [
                    if (!(user?.isBillingExcluded ?? false)) ...[
                      _ProfileTile(
                        icon: Icons.receipt_long_outlined,
                        title: 'Payment History',
                        subtitle: 'View all transactions',
                        iconColor: const Color(0xFF16A34A),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(builder: (_) => const PaymentHistoryScreen()),
                        ),
                      ),
                      _divider,
                    ],
                    _ProfileTile(
                      icon: Icons.report_problem_outlined,
                      title: 'My Complaints',
                      subtitle: 'Track your submitted tickets',
                      iconColor: const Color(0xFFCA8A04),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const MyComplaintsScreen()),
                      ),
                    ),
                    _divider,
                    _ProfileTile(
                      icon: Icons.event_available_outlined,
                      title: 'Amenity bookings',
                      subtitle: 'Upcoming and past bookings',
                      iconColor: const Color(0xFF0284C7),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const AmenityBookingHistoryScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignSpacing.xl),
                _ProfileSection(
                  title: 'App Settings',
                  delayMs: 120,
                  children: [
                    _ProfileTile(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      subtitle: 'App preferences',
                      iconColor: DesignColors.secondary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                    _divider,
                    _ProfileTile(
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      subtitle: 'Sign out of your account',
                      iconColor: DesignColors.error,
                      onTap: () => _handleLogout(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: DesignSpacing.xxl),
                Center(
                  child: Text(
                    '${AppConstants.appName} v${AppConstants.appVersion}',
                    style: DesignTypography.caption,
                  ),
                ),
                SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static const _divider = Divider(
    height: 1,
    thickness: 1,
    color: DesignColors.divider,
    indent: 76,
    endIndent: DesignSpacing.lg,
  );

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: DesignSpacing.lg),
                decoration: BoxDecoration(
                  color: DesignColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: DesignColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: DesignColors.error,
                  size: 28,
                ),
              ),
              const SizedBox(height: DesignSpacing.lg),
              Text('Sign out?', style: DesignTypography.headingM),
              const SizedBox(height: DesignSpacing.sm),
              Text(
                'You will need to sign in again to access your society dashboard.',
                textAlign: TextAlign.center,
                style: DesignTypography.bodySmall.copyWith(
                  color: DesignColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: DesignSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: DesignRadius.borderLG,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: DesignSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        // logout() calls restartApp() — full relaunch.
                        await ref.read(authProvider.notifier).logout();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: DesignColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: DesignRadius.borderLG,
                        ),
                      ),
                      child: const Text('Sign out'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeroHeader extends StatelessWidget {
  const _ProfileHeroHeader({
    required this.topInset,
    required this.user,
  });

  final double topInset;
  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = resolveServerFileUrl(user?.photoUrl);
    final email = user?.email.trim();
    final hasEmail = email != null && email.isNotEmpty;

    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          DesignSpacing.screenPaddingH,
          topInset + DesignSpacing.md,
          DesignSpacing.screenPaddingH,
          DesignSpacing.xl,
        ),
        decoration: const BoxDecoration(
          gradient: DesignColors.primaryGradient,
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A2563EB),
              blurRadius: 20,
              offset: Offset(0, 10),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                  },
                  borderRadius: DesignRadius.borderMD,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignSpacing.xs,
                      vertical: DesignSpacing.xs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Edit profile',
                          style: DesignTypography.labelSmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileAvatar(
                  avatarUrl: avatarUrl,
                  initials: _initialsFromName(user?.name),
                  completionFraction: _profileCompletion(user),
                ),
                const SizedBox(width: DesignSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'User',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DesignTypography.headingL.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          letterSpacing: -0.35,
                        ),
                      ),
                      const SizedBox(height: DesignSpacing.sm),
                      Text(
                        _profileSubtitle(user),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: DesignTypography.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (hasEmail) ...[
                        const SizedBox(height: DesignSpacing.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.alternate_email_rounded,
                                size: 15,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                            const SizedBox(width: DesignSpacing.xs),
                            Expanded(
                              child: Text(
                                email,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: DesignTypography.caption.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 380.ms).slideY(
            begin: -0.03,
            end: 0,
            curve: Curves.easeOutCubic,
          ),
    );
  }
}

String _profileSubtitle(UserModel? user) {
  if (user == null) {
    return '${_roleLabel(null)} · Your society';
  }

  if (!userShowsResidentPropertyProfile(user)) {
    final role = _roleLabel(user.role);
    final society = user.societyName?.trim();
    if (society != null && society.isNotEmpty) {
      return '$role · $society';
    }
    return role;
  }

  final chunks = <String>[];
  final prop = user.effectivePropertyDisplay;
  if (prop != null && prop.isNotEmpty) chunks.add(prop);

  final unit = user.effectiveUnitDisplay;
  if (unit != null && unit.isNotEmpty) chunks.add(unit);

  final occ = user.effectiveOccupantDisplay;
  if (occ != null && occ.isNotEmpty) chunks.add(occ);

  if (chunks.isNotEmpty) {
    final society = user.societyName?.trim();
    if (society != null && society.isNotEmpty) chunks.add(society);
    return chunks.join(' · ');
  }

  final society = user.societyName?.trim();
  if (society != null && society.isNotEmpty) {
    return '${_roleLabel(user.role)} · $society';
  }
  return '${_roleLabel(user.role)} · Your society';
}

String _roleLabel(UserRole? role) {
  switch (role) {
    case UserRole.superAdmin:
      return 'Platform admin';
    case UserRole.admin:
      return 'Administrator';
    case UserRole.residentCumAdmin:
      return 'Admin · Resident';
    case UserRole.guard:
      return 'Security staff';
    case UserRole.resident:
    case null:
      return 'Resident';
  }
}

double _profileCompletion(UserModel? user) {
  if (user == null) return 0.0;
  int filled = 0;
  const total = 6;
  if (user.name.trim().isNotEmpty) filled++;
  if (user.email.trim().isNotEmpty) filled++;
  if (user.phone != null && user.phone!.trim().isNotEmpty) filled++;
  if (user.photoUrl != null && user.photoUrl!.trim().isNotEmpty) filled++;
  if (user.effectivePropertyDisplay != null) filled++;
  if (user.effectiveUnitDisplay != null) filled++;
  return filled / total;
}

String _initialsFromName(String? name) {
  final parts = name
      ?.trim()
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .toList() ??
      [];
  if (parts.isEmpty) return 'U';
  if (parts.length == 1) {
    final s = parts.first;
    return s.length >= 2 ? s.substring(0, 2).toUpperCase() : s.toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.children,
    this.delayMs = 0,
  });

  final String title;
  final List<Widget> children;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: DesignSpacing.sm + 2),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: DesignColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: DesignTypography.headingM.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: DesignComponents.cardDecoration(
            borderColor: DesignColors.borderLight,
            boxShadow: DesignElevation.sm,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: DesignAnimations.staggerFor(delayMs ~/ 40), duration: 320.ms)
        .slideY(begin: DesignAnimations.slideSubtle, end: 0, duration: 320.ms, curve: Curves.easeOutCubic);
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        splashColor: iconColor.withValues(alpha: 0.08),
        highlightColor: iconColor.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSpacing.lg,
            vertical: DesignSpacing.md + 2,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: DesignSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: DesignTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                        color: DesignColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: DesignTypography.bodySmall.copyWith(
                        color: DesignColors.textSecondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: DesignColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: DesignColors.textTertiary,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar with an animated completion ring around it.
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.avatarUrl,
    required this.initials,
    required this.completionFraction,
  });

  final String? avatarUrl;
  final String initials;
  final double completionFraction;

  @override
  Widget build(BuildContext context) {
    const radius = 40.0;
    const ringWidth = 3.0;
    const outerSize = (radius + ringWidth) * 2;

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Completion ring
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: completionFraction),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return SizedBox(
                width: outerSize,
                height: outerSize,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: value,
                    ringWidth: ringWidth,
                    activeColor: Colors.white,
                    trackColor: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              );
            },
          ),
          // Avatar — cached so an uploaded photo persists across screens and
          // automatically refreshes when `edit_profile_screen` evicts the
          // previous URL from the image cache after a successful upload.
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: avatarUrl == null
                ? Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: DesignColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  )
                : CachedNetworkImage(
                    key: ValueKey(avatarUrl),
                    imageUrl: avatarUrl!,
                    cacheKey: avatarUrl,
                    fit: BoxFit.cover,
                    width: radius * 2,
                    height: radius * 2,
                    fadeInDuration: const Duration(milliseconds: 180),
                    placeholder: (_, _) => Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: DesignColors.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    errorWidget: (_, _, _) => Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: DesignColors.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.ringWidth,
    required this.activeColor,
    required this.trackColor,
  });

  final double progress;
  final double ringWidth;
  final Color activeColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = (size.width - ringWidth) / 2;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round;
    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, r, trackPaint);
    const startAngle = -1.5708; // -π/2  (12 o'clock)
    final sweep = 2 * 3.14159265 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      startAngle,
      sweep,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.activeColor != activeColor;
}
