import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/utils/storage_service.dart';

/// Amber late-fee warning with a stateful "Set reminder" toggle. The toggle
/// persists a per-cycle preference; delivery rides the backend's existing
/// due-reminder push notifications.
class LateFeeReminderCard extends StatefulWidget {
  const LateFeeReminderCard({
    super.key,
    required this.feeText,
    required this.byDate,
    required this.dateFmt,
    required this.cycleId,
  });

  final String feeText;
  final DateTime byDate;
  final DateFormat dateFmt;
  final String cycleId;

  @override
  State<LateFeeReminderCard> createState() => _LateFeeReminderCardState();
}

class _LateFeeReminderCardState extends State<LateFeeReminderCard> {
  static const _prefix = 'maint_reminder_';
  late bool _reminderOn;

  String get _key => '$_prefix${widget.cycleId}';

  @override
  void initState() {
    super.initState();
    _reminderOn = widget.cycleId.isNotEmpty &&
        (StorageService.prefs.getBool(_key) ?? false);
  }

  Future<void> _toggleReminder() async {
    final next = !_reminderOn;
    if (widget.cycleId.isNotEmpty) {
      await StorageService.prefs.setBool(_key, next);
    }
    if (!mounted) return;
    setState(() => _reminderOn = next);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(next
            ? 'Reminder set — we\'ll notify you before ${widget.dateFmt.format(widget.byDate)}.'
            : 'Reminder turned off.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        border: Border.all(color: DesignColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: DesignColors.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.notifications_active_outlined,
                size: 18, color: DesignColors.warning),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pay before ${widget.dateFmt.format(widget.byDate)}',
                  style: DesignTypography.bodySmall.copyWith(
                    color: const Color(0xFF92400E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'A late fee of ${widget.feeText} applies after this date.',
                  style: DesignTypography.caption.copyWith(
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _toggleReminder,
            icon: Icon(
              _reminderOn
                  ? Icons.check_circle_outline
                  : Icons.calendar_today_outlined,
              size: 15,
            ),
            label: Text(_reminderOn ? 'Reminder on' : 'Set reminder'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB45309),
              side:
                  BorderSide(color: DesignColors.warning.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
