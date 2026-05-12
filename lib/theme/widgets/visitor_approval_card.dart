import 'package:flutter/material.dart';

import '../context_extensions.dart';
import '../theme_extensions.dart';

/// Semantic status the card surfaces. Maps 1:1 to [StateColors].
enum VisitorApprovalStatus { approved, pending, denied, info }

/// Production-ready sample showing every token in use. Zero hardcoded
/// `Color(0xFF…)`, zero `EdgeInsets.all(16)` magic numbers, zero
/// conditional `isDark` branches — the card looks correct in both themes
/// because every value comes from the active [Theme].
class VisitorApprovalCard extends StatelessWidget {
  const VisitorApprovalCard({
    super.key,
    required this.visitorName,
    required this.unit,
    required this.arrival,
    required this.status,
    this.onAllowEntry,
    this.onBlockVisitor,
    this.onDetails,
  });

  final String visitorName;
  final String unit;
  final String arrival;
  final VisitorApprovalStatus status;
  final VoidCallback? onAllowEntry;
  final VoidCallback? onBlockVisitor;
  final VoidCallback? onDetails;

  StateColorTriplet _triplet(BuildContext c) {
    switch (status) {
      case VisitorApprovalStatus.approved:
        return c.state.approved;
      case VisitorApprovalStatus.pending:
        return c.state.pending;
      case VisitorApprovalStatus.denied:
        return c.state.denied;
      case VisitorApprovalStatus.info:
        return c.state.info;
    }
  }

  String _label() {
    switch (status) {
      case VisitorApprovalStatus.approved:
        return 'APPROVED';
      case VisitorApprovalStatus.pending:
        return 'PENDING';
      case VisitorApprovalStatus.denied:
        return 'DENIED';
      case VisitorApprovalStatus.info:
        return 'INFO';
    }
  }

  @override
  Widget build(BuildContext context) {
    final triplet = _triplet(context);
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.all(context.spacing.s16),
      decoration: BoxDecoration(
        color: context.surface.defaultSurface,
        border: Border.all(color: context.surface.border),
        borderRadius: BorderRadius.circular(context.radius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Visitor: $visitorName',
                  style: tt.titleMedium?.copyWith(color: context.text.primary),
                ),
              ),
              _StatusBadge(label: _label(), triplet: triplet),
            ],
          ),
          SizedBox(height: context.spacing.s8),
          Text(
            '$unit · Arriving $arrival',
            style: tt.bodyMedium?.copyWith(color: context.text.secondary),
          ),
          SizedBox(height: context.spacing.s16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onAllowEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.brand.accent,
                    foregroundColor: context.text.inverse,
                  ),
                  child: const Text('Allow entry'),
                ),
              ),
              SizedBox(width: context.spacing.s8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onDetails,
                  child: const Text('Details'),
                ),
              ),
            ],
          ),
          if (onBlockVisitor != null) ...[
            SizedBox(height: context.spacing.s8),
            TextButton(
              onPressed: onBlockVisitor,
              style: TextButton.styleFrom(foregroundColor: context.brand.danger),
              child: const Text('Block visitor'),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.triplet});

  final String label;
  final StateColorTriplet triplet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.s12,
        vertical: context.spacing.s4,
      ),
      decoration: BoxDecoration(
        color: triplet.bg,
        borderRadius: BorderRadius.circular(context.radius.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: triplet.fg,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}
