part of '../admin_dashboard_screen.dart';

extension _AdminDashboardHeroPart on _AdminDashboardScreenState {
  Widget _buildHeroCard(
    BuildContext ctx,
    String? name,
    String? society,
    int unreadNotifications,
  ) {
    final top = MediaQuery.of(ctx).padding.top;
    final firstName = name?.split(' ').first ?? 'Admin';
    final badgeText =
        unreadNotifications > 99 ? '99+' : '$unreadNotifications';

    return Container(
      padding: EdgeInsets.fromLTRB(14, top + 12, 8, 14),
      decoration: BoxDecoration(
        gradient: DesignColors.primaryGradient,
      ),
      child: Stack(
        children: [
          // Watermark illustration (right side)
          Positioned(
            right: -4,
            top: -6,
            bottom: -6,
            child: IgnorePointer(
              child: SizedBox(
                width: 130,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      right: 10,
                      top: 6,
                      child: Icon(
                        Icons.apartment_rounded,
                        size: 48,
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                    Positioned(
                      right: 52,
                      bottom: 2,
                      child: Icon(
                        Icons.shield_rounded,
                        size: 32,
                        color: Colors.white.withValues(alpha: 0.09),
                      ),
                    ),
                    Positioned(
                      right: 6,
                      bottom: 8,
                      child: Icon(
                        Icons.bar_chart_rounded,
                        size: 26,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${adminDashGreeting()}, $firstName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              letterSpacing: -0.35,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // "Admin" role pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Admin',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.96),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (society != null && society.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        society,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Date
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('d MMM').format(DateTime.now()),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    DateFormat('EEE').format(DateTime.now()),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 2),
              // Account / sign out — ensures villa-less admins (who have no
              // Profile tab) always have a reachable logout.
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _confirmAdminLogout(ctx),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.logout_rounded,
                      color: Colors.white.withValues(alpha: 0.92),
                      size: 21,
                    ),
                  ),
                ),
              ),
              // Notification bell
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    Navigator.of(ctx).push(
                      MaterialPageRoute<void>(
                        builder: (_) => residentNotificationsEntry,
                      ),
                    );
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          color: Colors.white.withValues(alpha: 0.92),
                          size: 23,
                        ),
                        if (unreadNotifications > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal:
                                    unreadNotifications > 9 ? 3 : 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: DesignColors.error,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: DesignColors.primaryDark, width: 1.25),
                              ),
                              constraints:
                                  const BoxConstraints(minHeight: 15),
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
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // BODY
  // ═══════════════════════════════════════════════════════════════════

  void _confirmAdminLogout(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to access your society dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: DesignColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref.read(authProvider.notifier).logout();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
