import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/design_haptics.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/models/early_cycle_expenses_preview.dart';
import '../../../data/models/expense_billing_cycle_group.dart';

/// Home teaser for approved expenses on a draft or upcoming billing cycle.
/// Tapping opens Society Expenses filtered to that cycle.
class HomeEarlyCycleExpensesTeaser extends StatelessWidget {
  const HomeEarlyCycleExpensesTeaser({
    super.key,
    required this.preview,
  });

  final EarlyCycleExpensesPreview preview;

  @override
  Widget build(BuildContext context) {
    if (!preview.hasExpenses) return const SizedBox.shrink();

    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20B9',
      decimalDigits: 0,
    );
    final palette = _TeaserPalette.forPhase(preview.phase);
    final opensLabel = _paymentOpensLabel(preview);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          DesignHaptics.selection();
          context.push(
            '/resident/expenses?month=${preview.month}&year=${preview.year}&highlight=1',
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.gradientStart,
                palette.gradientEnd,
              ],
            ),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: palette.accent.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    size: 20,
                    color: palette.accent,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              preview.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: DesignColors.textPrimary,
                                letterSpacing: -0.25,
                                height: 1.15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _PhaseBadge(
                            label: preview.phaseLabel,
                            accent: palette.accent,
                            background: palette.badgeBg,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preview.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: context.text.secondary,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _MetricChip(
                            label: inr.format(preview.totalAmount),
                            icon: Icons.payments_outlined,
                            color: palette.accent,
                          ),
                          const SizedBox(width: 8),
                          _MetricChip(
                            label: preview.itemLabel,
                            icon: Icons.format_list_bulleted_rounded,
                            color: context.text.secondary,
                          ),
                        ],
                      ),
                      if (opensLabel != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          opensLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: palette.accent.withValues(alpha: 0.9),
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: palette.accent.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _paymentOpensLabel(EarlyCycleExpensesPreview preview) {
    if (preview.paymentStartDate == null) return null;
    if (!preview.isDraft && !preview.isUpcoming) return null;
    final fmt = DateFormat('d MMM yyyy');
    return 'Payment window opens ${fmt.format(preview.paymentStartDate!.toLocal())}';
  }
}

class _PhaseBadge extends StatelessWidget {
  const _PhaseBadge({
    required this.label,
    required this.accent,
    required this.background,
  });

  final String label;
  final Color accent;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.35,
          color: accent,
          height: 1,
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DesignColors.borderLight.withValues(alpha: 0.9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeaserPalette {
  const _TeaserPalette({
    required this.accent,
    required this.gradientStart,
    required this.gradientEnd,
    required this.border,
    required this.badgeBg,
  });

  final Color accent;
  final Color gradientStart;
  final Color gradientEnd;
  final Color border;
  final Color badgeBg;

  factory _TeaserPalette.forPhase(ExpenseCyclePhase phase) {
    switch (phase) {
      case ExpenseCyclePhase.draft:
      case ExpenseCyclePhase.upcoming:
        return _TeaserPalette(
          accent: DesignColors.info,
          gradientStart: const Color(0xFFEFF6FF),
          gradientEnd: const Color(0xFFF0F9FF),
          border: const Color(0xFFBFDBFE),
          badgeBg: const Color(0x260EA5E9),
        );
      default:
        return _TeaserPalette(
          accent: DesignColors.primary,
          gradientStart: DesignColors.primaryLight.withValues(alpha: 0.35),
          gradientEnd: Colors.white,
          border: DesignColors.borderLight,
          badgeBg: DesignColors.primaryLight.withValues(alpha: 0.5),
        );
    }
  }
}
