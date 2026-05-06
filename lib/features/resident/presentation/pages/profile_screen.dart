import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../shared/models/user_model.dart';
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
      return Scaffold(
        backgroundColor: DesignColors.background,
        body: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
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
                      subtitle: '${user?.villaNumber ?? 'Registered'} vehicles',
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
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderXL),
        title: Text('Logout', style: DesignTypography.headingM),
        content: Text(
          'Are you sure you want to logout?',
          style: DesignTypography.bodySmall.copyWith(color: DesignColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: DesignTypography.label.copyWith(color: DesignColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.pop(context);
                context.go('/login');
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: DesignColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
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
        decoration: BoxDecoration(
          gradient: DesignColors.primaryGradient,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
          boxShadow: const [
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
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.55),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl != null
                        ? null
                        : Text(
                            _initialsFromName(user?.name),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: DesignColors.primary,
                              letterSpacing: -0.5,
                            ),
                          ),
                  ),
                ),
                SizedBox(width: DesignSpacing.lg),
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
                      SizedBox(height: DesignSpacing.sm),
                      Text(
                        _profileSubtitle(user),
                        style: DesignTypography.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (hasEmail) ...[
                        SizedBox(height: DesignSpacing.sm),
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
                            SizedBox(width: DesignSpacing.xs),
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
  final role = _roleLabel(user?.role);
  final unit = user?.villaNumber?.trim();
  final society = user?.societyName?.trim();
  if (unit != null && unit.isNotEmpty) {
    return '$role · Unit $unit';
  }
  if (society != null && society.isNotEmpty) {
    return '$role · $society';
  }
  return '$role · Your society';
}

String _roleLabel(UserRole? role) {
  switch (role) {
    case UserRole.superAdmin:
      return 'Platform admin';
    case UserRole.admin:
      return 'Administrator';
    case UserRole.guard:
      return 'Security staff';
    case UserRole.resident:
    case null:
      return 'Resident';
  }
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
        .fadeIn(delay: (delayMs).ms, duration: 320.ms)
        .slideY(begin: 0.05, end: 0, duration: 320.ms, curve: Curves.easeOutCubic);
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
                        fontWeight: FontWeight.w700,
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
                child: Icon(
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
