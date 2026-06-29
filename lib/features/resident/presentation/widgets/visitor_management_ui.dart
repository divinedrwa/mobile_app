import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../theme/context_extensions.dart';

/// Shared status semantics for resident visitor flows (history, approvals, etc.).
class VisitorMgmtStatusStyle {
  const VisitorMgmtStatusStyle({
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
    required this.icon,
  });

  final String label;
  final Color foreground;
  final Color background;
  final Color border;
  final IconData icon;
}

abstract final class VisitorMgmtStatus {
  static String normalize(String raw) =>
      raw.trim().toUpperCase().replaceAll('-', '_');

  static VisitorMgmtStatusStyle style(String raw) {
    switch (normalize(raw)) {
      case 'APPROVED':
        return VisitorMgmtStatusStyle(
          label: 'Approved',
          foreground: DesignColors.success,
          background: DesignColors.successLight,
          border: DesignColors.accent.withValues(alpha: 0.45),
          icon: Icons.verified_rounded,
        );
      case 'CHECKED_IN':
        return VisitorMgmtStatusStyle(
          label: 'Checked in',
          foreground: DesignColors.info,
          background: DesignColors.infoLight,
          border: DesignColors.info.withValues(alpha: 0.35),
          icon: Icons.home_work_rounded,
        );
      case 'CHECKED_OUT':
        return VisitorMgmtStatusStyle(
          label: 'Checked out',
          foreground: DesignColors.textSecondary,
          background: Color(0xFFF1F5F9),
          border: Color(0xFFCBD5E1),
          icon: Icons.logout_rounded,
        );
      case 'REJECTED':
      case 'DENIED':
        return VisitorMgmtStatusStyle(
          label: 'Declined',
          foreground: DesignColors.error,
          background: DesignColors.errorLight,
          border: DesignColors.error.withValues(alpha: 0.35),
          icon: Icons.cancel_rounded,
        );
      case 'PENDING':
      case 'PENDING_APPROVAL':
        return VisitorMgmtStatusStyle(
          label: 'Awaiting approval',
          foreground: DesignColors.warning,
          background: DesignColors.warningLight,
          border: DesignColors.warning.withValues(alpha: 0.4),
          icon: Icons.pending_actions_rounded,
        );
      default:
        return VisitorMgmtStatusStyle(
          label: label(raw),
          foreground: DesignColors.textSecondary,
          background: DesignColors.surfaceSoft,
          border: DesignColors.borderLight,
          icon: Icons.info_outline_rounded,
        );
    }
  }

  static String label(String raw) {
    final key = normalize(raw);
    const map = <String, String>{
      'CHECKED_IN': 'Checked in',
      'CHECKED_OUT': 'Checked out',
      'PENDING': 'Pending',
      'PENDING_APPROVAL': 'Awaiting approval',
      'APPROVED': 'Approved',
      'REJECTED': 'Declined',
      'DENIED': 'Declined',
      'CANCELLED': 'Cancelled',
    };
    if (map.containsKey(key)) return map[key]!;
    if (key.isEmpty) return 'Unknown';
    return key
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  /// Per-villa resident decision row (approvalStatus on VisitorVilla).
  static VisitorMgmtStatusStyle styleForVillaDecision(String raw) {
    switch (normalize(raw)) {
      case 'APPROVED':
        return style('APPROVED');
      case 'REJECTED':
        return style('DENIED');
      default:
        return style('PENDING_APPROVAL');
    }
  }

  static String labelForVillaDecision(String raw) {
    switch (normalize(raw)) {
      case 'APPROVED':
        return 'You approved';
      case 'REJECTED':
        return 'You declined';
      default:
        return 'Awaiting your answer';
    }
  }
}

/// Scrollable period/filter tabs — prevents clipping on narrow screens.
class VisitorMgmtTabBar extends StatelessWidget {
  const VisitorMgmtTabBar({
    super.key,
    required this.controller,
    required this.tabs,
  });

  final TabController controller;
  final List<Widget> tabs;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      labelPadding: const EdgeInsets.symmetric(horizontal: 14),
      splashFactory: NoSplash.splashFactory,
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.15,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      labelColor: DesignColors.primary,
      unselectedLabelColor: DesignColors.textTertiary,
      indicatorSize: TabBarIndicatorSize.label,
      indicatorColor: DesignColors.primary,
      indicatorWeight: 2.5,
      dividerColor: DesignColors.borderLight,
      tabs: tabs,
    );
  }
}

class VisitorMgmtCompactSearch extends StatelessWidget {
  const VisitorMgmtCompactSearch({
    super.key,
    required this.hintText,
    required this.onChanged,
  });

  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: context.text.primary),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: context.text.tertiary, fontSize: 14),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: context.text.tertiary,
          ),
          isDense: true,
          filled: true,
          fillColor: context.surface.background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.surface.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.surface.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: DesignColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class VisitorMgmtAvatar extends StatelessWidget {
  const VisitorMgmtAvatar({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: DesignColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: DesignColors.primary,
        ),
      ),
    );
  }
}

class VisitorMgmtStatusChip extends StatelessWidget {
  const VisitorMgmtStatusChip({super.key, required this.statusRaw});

  final String statusRaw;

  @override
  Widget build(BuildContext context) {
    final ui = VisitorMgmtStatus.style(statusRaw);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: ui.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ui.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ui.icon, size: 14, color: ui.foreground),
          const SizedBox(width: 5),
          Text(
            ui.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ui.foreground,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class VisitorMgmtMetaChip extends StatelessWidget {
  const VisitorMgmtMetaChip({
    super.key,
    required this.icon,
    required this.label,
    this.maxWidth = 220,
  });

  final IconData icon;
  final String label;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: DesignColors.surfaceSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: DesignColors.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: DesignColors.textTertiary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: DesignColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VisitorMgmtSectionHeader extends StatelessWidget {
  const VisitorMgmtSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: DesignColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: DesignColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
