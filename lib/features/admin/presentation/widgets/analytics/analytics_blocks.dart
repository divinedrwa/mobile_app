import 'package:flutter/material.dart';

import '../../../../../core/theme/design_tokens.dart';

/// Shared building blocks for the admin analytics tabs (Gate, Complaints, Water),
/// matching the web dashboard: section cards, "needs attention" and share bars.

int analyticsInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

double analyticsDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

/// 95 → "1 h 35 min".
String analyticsMinutes(num? minutes) {
  if (minutes == null) return '—';
  final m = minutes.round();
  if (m < 60) return '$m min';
  final h = m ~/ 60;
  if (h >= 48) return '${(h / 24).round()} days';
  final rest = m % 60;
  return rest == 0 ? '$h h' : '$h h $rest min';
}

/// 'good' | 'watch' | 'critical' from a percentage.
String analyticsTone(num? pct, num good, num watch, {bool lowerIsBetter = false}) {
  if (pct == null) return 'neutral';
  if (lowerIsBetter) return pct <= good ? 'good' : (pct <= watch ? 'watch' : 'critical');
  return pct >= good ? 'good' : (pct >= watch ? 'watch' : 'critical');
}

Color analyticsToneColor(String tone) {
  switch (tone) {
    case 'good':
      return DesignColors.success;
    case 'critical':
      return DesignColors.error;
    case 'watch':
      return DesignColors.warning;
    default:
      return DesignColors.textSecondary;
  }
}

class AnalyticsSectionTitle extends StatelessWidget {
  const AnalyticsSectionTitle(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DesignTypography.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DesignColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: DesignTypography.captionSmall.copyWith(color: DesignColors.textSecondary),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class AnalyticsCard extends StatelessWidget {
  const AnalyticsCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        border: Border.all(color: DesignColors.borderLight),
      ),
      child: child,
    );
  }
}

class AnalyticsAttentionItem {
  const AnalyticsAttentionItem({required this.title, this.detail, this.tone = 'watch', this.action});

  final String title;
  final String? detail;
  final String tone;
  final Widget? action;
}

/// "Needs attention" list — what the admin should act on first.
class AnalyticsAttentionList extends StatelessWidget {
  const AnalyticsAttentionList({super.key, required this.items, required this.emptyText});

  final List<AnalyticsAttentionItem> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DesignColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(DesignRadius.md),
          border: Border.all(color: DesignColors.success.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: DesignColors.success, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                emptyText,
                style: DesignTypography.bodySmall.copyWith(
                  color: DesignColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return AnalyticsCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: DesignColors.borderLight),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      color: analyticsToneColor(items[i].tone),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].title,
                          style: DesignTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: DesignColors.textPrimary,
                          ),
                        ),
                        if (items[i].detail != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            items[i].detail!,
                            style: DesignTypography.captionSmall.copyWith(
                              color: DesignColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ?items[i].action,
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AnalyticsShare {
  const AnalyticsShare(this.label, this.value, this.color, {this.meta});

  final String label;
  final int value;
  final Color color;
  final String? meta;
}

/// Horizontal share bars (e.g. visitors by type, request outcomes).
class AnalyticsShareBars extends StatelessWidget {
  const AnalyticsShareBars({super.key, required this.items, required this.emptyText});

  final List<AnalyticsShare> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final shown = items.where((i) => i.value > 0).toList();
    final total = shown.fold<int>(0, (s, i) => s + i.value);
    return AnalyticsCard(
      child: total == 0
          ? Text(emptyText, style: DesignTypography.bodySmall.copyWith(color: DesignColors.textTertiary))
          : Column(
              children: [
                for (final item in shown)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.label,
                                style: DesignTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: DesignColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '${item.value} · ${(item.value * 100 / total).round()}%',
                              style: DesignTypography.captionSmall.copyWith(
                                color: DesignColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: item.value / total,
                            minHeight: 7,
                            backgroundColor: DesignColors.borderLight,
                            color: item.color,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Small pill, e.g. "3 inside".
class AnalyticsPill extends StatelessWidget {
  const AnalyticsPill(this.text, {super.key, this.tone = 'neutral'});

  final String text;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final c = analyticsToneColor(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}
