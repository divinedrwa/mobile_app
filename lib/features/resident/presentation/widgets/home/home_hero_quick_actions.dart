import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/design_haptics.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../data/models/quick_action_model.dart';
import '../../providers/visitor_provider.dart';
import 'home_quick_action_navigation.dart';
import 'home_shared.dart';

/// Quick Actions — Visitor Entry (50%) + SOS + Complaint in one row.
class HomeHeroQuickActions extends ConsumerStatefulWidget {
  const HomeHeroQuickActions({super.key});

  @override
  ConsumerState<HomeHeroQuickActions> createState() =>
      _HomeHeroQuickActionsState();
}

class _HomeHeroQuickActionsState extends ConsumerState<HomeHeroQuickActions> {
  bool _moreExpanded = false;

  void _toggleMore() {
    DesignHaptics.selection();
    setState(() => _moreExpanded = !_moreExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(visitorApprovalRequestsProvider('pending'));
    final pendingCount = pendingAsync.valueOrNull?.length ?? 0;
    final primarySecondary = residentHomeSecondaryActionsGrid
        .where((a) => a.id != 'more')
        .toList();
    final overflowActions = residentQuickActionsMoreSheet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: DesignColors.textPrimary,
                letterSpacing: -0.3,
                height: 1.2,
              ),
            ),
            SizedBox(width: 6),
            Text(
              '· Most used features',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: DesignColors.textSecondary,
                height: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: kHomeHeroRowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: _VisitorEntryCard(
                  pendingCount: pendingCount,
                  onTap: () {
                    DesignHaptics.selection();
                    HomeQuickActionNavigation.open(
                      context,
                      ref,
                      residentHomeVisitorEntryAction,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactHeroCard(
                  background: const Color(0xFFFFF8F8),
                  borderColor: const Color(0xFFFECACA),
                  iconBg: const Color(0xFFFEE2E2),
                  iconColor: DesignColors.error,
                  icon: Icons.phone_in_talk_rounded,
                  title: 'SOS',
                  subtitle: 'Emergency assistance',
                  arrowColor: DesignColors.error,
                  onTap: () {
                    DesignHaptics.selection();
                    HomeQuickActionNavigation.open(
                      context,
                      ref,
                      const QuickAction(
                        id: 'sos',
                        label: 'SOS',
                        icon: Icons.emergency,
                        color: Color(0xFFE53935),
                        route: '/resident/sos',
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactHeroCard(
                  background: const Color(0xFFFFFBF5),
                  borderColor: const Color(0xFFFED7AA),
                  iconBg: const Color(0xFFFFEDD5),
                  iconColor: DesignColors.warning,
                  icon: Icons.warning_amber_rounded,
                  title: 'Complaint',
                  subtitle: 'Raise a complaint instantly',
                  arrowColor: DesignColors.warning,
                  onTap: () {
                    DesignHaptics.selection();
                    HomeQuickActionNavigation.open(
                      context,
                      ref,
                      const QuickAction(
                        id: 'complaint',
                        label: 'Complaint',
                        icon: Icons.report_problem_outlined,
                        color: Color(0xFFFF9800),
                        route: '/resident/complaint',
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < primarySecondary.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: _SecondaryIconTile(
                  action: primarySecondary[i],
                  onTap: () {
                    DesignHaptics.selection();
                    HomeQuickActionNavigation.open(
                      context,
                      ref,
                      primarySecondary[i],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(width: 4),
            Expanded(
              child: _MoreExpandTile(
                expanded: _moreExpanded,
                onTap: _toggleMore,
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _moreExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      for (var i = 0; i < overflowActions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        Expanded(
                          child: _SecondaryIconTile(
                            action: overflowActions[i],
                            onTap: () {
                              DesignHaptics.selection();
                              HomeQuickActionNavigation.open(
                                context,
                                ref,
                                overflowActions[i],
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _VisitorEntryCard extends StatelessWidget {
  const _VisitorEntryCard({
    required this.pendingCount,
    required this.onTap,
  });

  final int pendingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                DesignColors.secondary,
                DesignColors.primary,
                DesignColors.primaryDark,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: DesignColors.primary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Decorative dot grid — right side, vertically centered
              Positioned(
                top: 10,
                right: 10,
                child: _DotGrid(
                  rows: 4,
                  cols: 3,
                  spacing: 6,
                  dotSize: 2.2,
                  color: Colors.white.withValues(alpha: 0.20),
                ),
              ),
              // Main content
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 46, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon + badge row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.person_add_alt_1_rounded,
                            color: DesignColors.primary,
                            size: 17,
                          ),
                        ),
                        if (pendingCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.45),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '$pendingCount pending',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),
                    // Title
                    const Text(
                      'GatePass+',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Subtitle
                    Text(
                      'Visitor Management',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.82),
                        letterSpacing: -0.1,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow chevron — vertically centered on right edge
              Positioned(
                right: 10,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: Colors.white,
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

/// Paints a grid of small dots used as a decorative overlay on the card.
class _DotGrid extends StatelessWidget {
  const _DotGrid({
    required this.rows,
    required this.cols,
    required this.spacing,
    required this.dotSize,
    required this.color,
  });

  final int rows;
  final int cols;
  final double spacing;
  final double dotSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (cols - 1) * spacing + dotSize,
      height: (rows - 1) * spacing + dotSize,
      child: CustomPaint(
        painter: _DotGridPainter(
          rows: rows,
          cols: cols,
          spacing: spacing,
          dotSize: dotSize,
          color: color,
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({
    required this.rows,
    required this.cols,
    required this.spacing,
    required this.dotSize,
    required this.color,
  });

  final int rows;
  final int cols;
  final double spacing;
  final double dotSize;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final r = dotSize / 2;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        canvas.drawCircle(
          Offset(col * spacing + r, row * spacing + r),
          r,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => false;
}

class _CompactHeroCard extends StatelessWidget {
  const _CompactHeroCard({
    required this.background,
    required this.borderColor,
    required this.iconBg,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.arrowColor,
    required this.onTap,
  });

  final Color background;
  final Color borderColor;
  final Color iconBg;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color arrowColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: iconColor, size: 13),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: DesignColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: DesignColors.textSecondary.withValues(alpha: 0.85),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: borderColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 12,
                  color: arrowColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreExpandTile extends StatelessWidget {
  const _MoreExpandTile({
    required this.expanded,
    required this.onTap,
  });

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: moreQuickAction.color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: expanded
                        ? kHomePurple.withValues(alpha: 0.35)
                        : moreQuickAction.color.withValues(alpha: 0.12),
                  ),
                ),
                child: AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: expanded ? kHomePurple : moreQuickAction.color,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'More',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: expanded ? kHomePurple : DesignColors.textPrimary,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryIconTile extends StatelessWidget {
  const _SecondaryIconTile({
    required this.action,
    required this.onTap,
  });

  final QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: action.color.withValues(alpha: 0.12),
                  ),
                ),
                child: Icon(action.icon, color: action.color, size: 19),
              ),
              const SizedBox(height: 5),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: DesignColors.textPrimary,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
