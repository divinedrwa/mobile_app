import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../../core/telemetry/telemetry_safe.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/enterprise_ui.dart';

/// Enterprise "who uses the app" breakdown by role.
///
/// Metric meanings (must stay consistent with backend role-adoption API):
/// - **Accounts** (`registered`): active accounts in the User table for this role
/// - **Using app** (`active`): opened / used the app in the selected period
/// - **Dormant** (`dormant`): used the app before, but not in this period
/// - **Never used** (`neverUsed`): no analytics, push, or login signal ever
/// - **Active rate**: using app ÷ accounts
/// - **Ever used rate**: (using + dormant) ÷ accounts
class AnalyticsRoleAdoptionPanel extends StatefulWidget {
  const AnalyticsRoleAdoptionPanel({super.key, required this.adoption});

  final Map<String, dynamic> adoption;

  @override
  State<AnalyticsRoleAdoptionPanel> createState() =>
      _AnalyticsRoleAdoptionPanelState();
}

class _AnalyticsRoleAdoptionPanelState extends State<AnalyticsRoleAdoptionPanel> {
  String? _expandedRole;
  final Set<String> _showAllBuckets = {};

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final roles = telemetrySafeMapList(widget.adoption['roles'])
        .where((r) => _toInt(r['registered']) > 0 || _toInt(r['totalInSociety']) > 0)
        .toList();
    if (roles.isEmpty) {
      return EnterprisePanel(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No user accounts in this society yet. Add residents, guards, or admins to see adoption metrics.',
          style: DesignTypography.bodySmall.copyWith(
            color: DesignColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final periodDays = _toInt(widget.adoption['period']?['days']);
    final daysLabel = periodDays > 0 ? periodDays : 30;
    final totals = telemetrySafeMap(widget.adoption['totals']);
    final totalAccounts = _toInt(
      widget.adoption['meta']?['totalUsersInDatabase'] ??
          totals['totalUsersInDatabase'],
    );
    final usingApp = _toInt(totals['activeInPeriod']);
    final neverUsed = _toInt(totals['neverUsedApp']);
    final dormant = _toInt(totals['inactiveInPeriod']);
    final needAttention = neverUsed + dormant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Who uses the app',
          style: DesignTypography.headingM.copyWith(
            fontWeight: FontWeight.w800,
            color: DesignColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Last $daysLabel days · $totalAccounts accounts in this society',
          style: DesignTypography.captionSmall.copyWith(
            color: DesignColors.textSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        _societySummary(
          usingApp: usingApp,
          needAttention: needAttention,
          neverUsed: neverUsed,
          dormant: dormant,
          totalAccounts: totalAccounts,
        ),
        const SizedBox(height: 10),
        _legend(),
        const SizedBox(height: 14),
        ...roles.map((role) {
          final key = role['role']?.toString() ?? role['label']?.toString() ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RoleCard(
              role: role,
              periodDays: daysLabel,
              expanded: _expandedRole == key,
              showAllNever: _showAllBuckets.contains('$key-never'),
              showAllDormant: _showAllBuckets.contains('$key-dormant'),
              onToggle: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _expandedRole = _expandedRole == key ? null : key;
                });
              },
              onShowAllNever: () {
                setState(() => _showAllBuckets.add('$key-never'));
              },
              onShowAllDormant: () {
                setState(() => _showAllBuckets.add('$key-dormant'));
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _societySummary({
    required int usingApp,
    required int needAttention,
    required int neverUsed,
    required int dormant,
    required int totalAccounts,
  }) {
    final usingPct = totalAccounts > 0
        ? ((usingApp / totalAccounts) * 100).round()
        : 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.xl),
        border: Border.all(color: DesignColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryMetric(
              label: 'Using app',
              value: '$usingApp',
              hint: '$usingPct% of accounts',
              color: DesignColors.success,
            ),
          ),
          Container(width: 1, height: 42, color: DesignColors.borderLight),
          Expanded(
            child: _summaryMetric(
              label: 'Need attention',
              value: '$needAttention',
              hint: '$neverUsed never · $dormant dormant',
              color: needAttention > 0 ? DesignColors.warning : DesignColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric({
    required String label,
    required String value,
    required String hint,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: DesignTypography.captionSmall.copyWith(
              color: DesignColors.textTertiary,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: DesignTypography.captionSmall.copyWith(
              color: DesignColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend() {
    return const Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _LegendDot(color: Color(0xFF16A34A), label: 'Using now'),
        _LegendDot(color: Color(0xFFD97706), label: 'Dormant'),
        _LegendDot(color: Color(0xFFDC2626), label: 'Never used'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: DesignTypography.captionSmall.copyWith(
            color: DesignColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.periodDays,
    required this.expanded,
    required this.showAllNever,
    required this.showAllDormant,
    required this.onToggle,
    required this.onShowAllNever,
    required this.onShowAllDormant,
  });

  final Map<String, dynamic> role;
  final int periodDays;
  final bool expanded;
  final bool showAllNever;
  final bool showAllDormant;
  final VoidCallback onToggle;
  final VoidCallback onShowAllNever;
  final VoidCallback onShowAllDormant;

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  Color get _accent {
    switch (role['role']?.toString()) {
      case 'GUARD':
        return const Color(0xFF0E7490);
      case 'ADMIN':
      case 'RESIDENT_CUM_ADMIN':
        return const Color(0xFF6366F1);
      default:
        return DesignColors.primary;
    }
  }

  IconData get _icon {
    switch (role['role']?.toString()) {
      case 'GUARD':
        return Icons.shield_outlined;
      case 'ADMIN':
      case 'RESIDENT_CUM_ADMIN':
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.home_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = role['label']?.toString() ?? role['role']?.toString() ?? '';
    final accounts = _toInt(role['registered']);
    final using = _toInt(role['active']);
    final dormant = _toInt(role['dormant']);
    final neverUsed = _toInt(role['neverUsed']);
    final deactivated = _toInt(role['deactivated']);
    final activeRate = _toInt(role['activeRatePct']);
    final everUsedRate = _toInt(role['activationRatePct']);
    final attention = dormant + neverUsed;

    final listCounts = telemetrySafeMap(role['listCounts']);
    final neverCount = () {
      final fromLists = _toInt(listCounts['neverUsed']);
      return fromLists > 0 ? fromLists : neverUsed;
    }();
    final dormantCount = () {
      final fromLists = _toInt(listCounts['dormant']);
      return fromLists > 0 ? fromLists : dormant;
    }();

    final notUsingUsers = telemetrySafeMap(role['notUsingAppUsers']);
    final neverList = telemetrySafeMapList(notUsingUsers['neverUsed']);
    final dormantList = telemetrySafeMapList(notUsingUsers['dormant']);

    return Material(
      color: DesignColors.surface,
      borderRadius: BorderRadius.circular(DesignRadius.xl),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(DesignRadius.xl),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignRadius.xl),
            border: Border.all(
              color: expanded
                  ? _accent.withValues(alpha: 0.35)
                  : DesignColors.borderLight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_icon, size: 18, color: _accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: DesignTypography.body.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            accounts == 0
                                ? 'No accounts'
                                : '$using of $accounts using the app · last $periodDays days',
                            style: DesignTypography.captionSmall.copyWith(
                              color: DesignColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$activeRate%',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: _accent,
                            letterSpacing: -0.4,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'in period',
                          style: DesignTypography.captionSmall.copyWith(
                            color: DesignColors.textTertiary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: DesignColors.textTertiary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SegmentedBar(
                  using: using,
                  dormant: dormant,
                  neverUsed: neverUsed,
                  deactivated: deactivated,
                  total: accounts > 0
                      ? accounts
                      : (using + dormant + neverUsed + deactivated),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Using',
                        value: '$using',
                        color: DesignColors.success,
                        subtitle: 'this period',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricTile(
                        label: 'Dormant',
                        value: '$dormant',
                        color: DesignColors.warning,
                        subtitle: 'used before',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricTile(
                        label: 'Never',
                        value: '$neverUsed',
                        color: DesignColors.error,
                        subtitle: 'no signals',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Ever used: $everUsedRate%'
                  '${attention > 0 ? '  ·  $attention need follow-up' : '  ·  All accounts engaged'}',
                  style: DesignTypography.captionSmall.copyWith(
                    color: DesignColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (expanded) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  if (neverCount == 0 && dormantCount == 0)
                    Text(
                      'Everyone in this role has used the app recently.',
                      style: DesignTypography.bodySmall.copyWith(
                        color: DesignColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else ...[
                    if (neverCount > 0) ...[
                      _BucketHeader(
                        title: 'Never opened the app',
                        count: neverCount,
                        color: DesignColors.error,
                        hint: 'No login, push device, or analytics signal',
                      ),
                      const SizedBox(height: 8),
                      _UserBucketList(
                        users: neverList,
                        totalCount: neverCount,
                        showAll: showAllNever,
                        showLastSeen: false,
                        onShowAll: onShowAllNever,
                      ),
                    ],
                    if (dormantCount > 0) ...[
                      if (neverCount > 0) const SizedBox(height: 14),
                      _BucketHeader(
                        title: 'Dormant',
                        count: dormantCount,
                        color: DesignColors.warning,
                        hint: 'Used before · not active in last $periodDays days',
                      ),
                      const SizedBox(height: 8),
                      _UserBucketList(
                        users: dormantList,
                        totalCount: dormantCount,
                        showAll: showAllDormant,
                        showLastSeen: true,
                        onShowAll: onShowAllDormant,
                      ),
                    ],
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
    required this.subtitle,
  });

  final String label;
  final String value;
  final Color color;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(DesignRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: DesignTypography.captionSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: DesignColors.textPrimary,
              fontSize: 11,
            ),
          ),
          Text(
            subtitle,
            style: DesignTypography.captionSmall.copyWith(
              color: DesignColors.textTertiary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({
    required this.using,
    required this.dormant,
    required this.neverUsed,
    required this.deactivated,
    required this.total,
  });

  final int using;
  final int dormant;
  final int neverUsed;
  final int deactivated;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = total <= 0 ? 1 : total;
    Widget seg(int n, Color c) {
      if (n <= 0) return const SizedBox.shrink();
      return Expanded(
        flex: n,
        child: Container(color: c),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                seg(using, DesignColors.success),
                seg(dormant, DesignColors.warning),
                seg(neverUsed, DesignColors.error),
                seg(deactivated, DesignColors.textTertiary),
                if (using + dormant + neverUsed + deactivated == 0)
                  Expanded(child: Container(color: DesignColors.borderLight)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '${((using / t) * 100).round()}% using',
              style: DesignTypography.captionSmall.copyWith(
                color: DesignColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
            const Spacer(),
            Text(
              '${(((dormant + neverUsed) / t) * 100).round()}% not using',
              style: DesignTypography.captionSmall.copyWith(
                color: DesignColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BucketHeader extends StatelessWidget {
  const _BucketHeader({
    required this.title,
    required this.count,
    required this.color,
    required this.hint,
  });

  final String title;
  final int count;
  final Color color;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: DesignTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          hint,
          style: DesignTypography.captionSmall.copyWith(
            color: DesignColors.textTertiary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _UserBucketList extends StatelessWidget {
  const _UserBucketList({
    required this.users,
    required this.totalCount,
    required this.showAll,
    required this.showLastSeen,
    required this.onShowAll,
  });

  final List<Map<String, dynamic>> users;
  final int totalCount;
  final bool showAll;
  final bool showLastSeen;
  final VoidCallback onShowAll;

  static const _preview = 5;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Text(
        'Names unavailable for this bucket.',
        style: DesignTypography.captionSmall.copyWith(
          color: DesignColors.textSecondary,
        ),
      );
    }

    final visible = showAll ? users : users.take(_preview).toList();
    final remaining = (totalCount > users.length ? totalCount : users.length) -
        visible.length;

    return Column(
      children: [
        ...visible.map(
          (u) => _UserTile(user: u, showLastSeen: showLastSeen),
        ),
        if (!showAll && remaining > 0)
          TextButton(
            onPressed: onShowAll,
            child: Text(
              'Show all $totalCount',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: DesignColors.primary,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.showLastSeen});

  final Map<String, dynamic> user;
  final bool showLastSeen;

  String get _name =>
      user['name']?.toString() ?? user['username']?.toString() ?? 'User';

  String get _meta {
    final villa = user['villaNumber']?.toString().trim();
    if (villa != null && villa.isNotEmpty) return 'Villa $villa';
    final username = user['username']?.toString().trim();
    if (username != null && username.isNotEmpty) return '@$username';
    return '';
  }

  String? get _contact {
    final phone = user['phone']?.toString().trim();
    if (phone != null && phone.isNotEmpty) return phone;
    final email = user['email']?.toString().trim();
    if (email != null && email.isNotEmpty) return email;
    return null;
  }

  String? get _lastSeenLabel {
    final raw = user['lastSeenAt']?.toString();
    if (raw == null || raw.isEmpty) return null;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw.split('T').first;
    final local = dt.toLocal();
    final now = DateTime.now();
    final days = now.difference(local).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 30) return '${days}d ago';
    return DateFormat('dd MMM yyyy').format(local);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: DesignColors.primary.withValues(alpha: 0.1),
            child: Text(
              telemetrySafeInitial(_name),
              style: TextStyle(
                color: DesignColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name,
                  style: DesignTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_meta.isNotEmpty || _contact != null)
                  Text(
                    [
                      if (_meta.isNotEmpty) _meta,
                      ?_contact,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DesignTypography.captionSmall.copyWith(
                      color: DesignColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (showLastSeen && _lastSeenLabel != null)
            Text(
              _lastSeenLabel!,
              style: DesignTypography.captionSmall.copyWith(
                color: DesignColors.textTertiary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}
