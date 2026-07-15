import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_spacing.dart';
import '../../../../../../core/theme/design_tokens.dart';
import '../../../../../../core/widgets/enterprise_ui.dart';

class AdminMaintenanceCollapsibleGroup extends StatefulWidget {
  const AdminMaintenanceCollapsibleGroup({
    required this.label,
    required this.count,
    required this.child,
  });

  final String label;
  final int count;
  final Widget child;

  @override
  State<AdminMaintenanceCollapsibleGroup> createState() => AdminMaintenanceCollapsibleGroupState();
}

class AdminMaintenanceCollapsibleGroupState extends State<AdminMaintenanceCollapsibleGroup> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return EnterprisePanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(DesignRadius.lg),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Text(
                    widget.label,
                    style: DesignTypography.bodyMedium.copyWith(
                      color: DesignColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: DesignColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${widget.count}',
                      style: DesignTypography.caption.copyWith(
                        color: DesignColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: Duration(milliseconds: 180),
                    child: Icon(Icons.keyboard_arrow_down, color: DesignColors.textTertiary),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: widget.child,
            ),
            crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

/// Unified payment actions sheet with 3 tabs: Record payment, Add credit, Deduct credit.
