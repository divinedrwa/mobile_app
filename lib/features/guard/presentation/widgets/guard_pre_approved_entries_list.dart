import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';

/// Pre-approved visitor cards — [onEntryTap] opens confirmation (e.g. arrival screen).
/// Optional [showVisitorArrivedButton] adds an explicit CTA (e.g. Active entries tab).
class GuardPreApprovedEntriesListContent extends StatefulWidget {
  const GuardPreApprovedEntriesListContent({
    super.key,
    required this.rows,
    this.focusId,
    this.scrollController,
    required this.onEntryTap,
    this.bottomPadding = 32,
    this.showVisitorArrivedButton = false,
  });

  final List<GuardPreApprovedEntry> rows;
  final String? focusId;
  final ScrollController? scrollController;
  final void Function(GuardPreApprovedEntry entry) onEntryTap;
  final double bottomPadding;

  /// When true, each row shows a primary **Visitor arrived** control (in addition to row tap).
  final bool showVisitorArrivedButton;

  @override
  State<GuardPreApprovedEntriesListContent> createState() =>
      _GuardPreApprovedEntriesListContentState();
}

class _GuardPreApprovedEntriesListContentState
    extends State<GuardPreApprovedEntriesListContent> {
  final Map<String, GlobalKey> _rowKeys = {};
  bool _handledFocusScroll = false;

  GlobalKey _keyFor(String id) => _rowKeys.putIfAbsent(id, GlobalKey.new);

  @override
  void didUpdateWidget(covariant GuardPreApprovedEntriesListContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusId != widget.focusId) {
      _handledFocusScroll = false;
    }
  }

  void _maybeScrollToFocus(String? focusId, List<GuardPreApprovedEntry> rows) {
    if (_handledFocusScroll || focusId == null || focusId.isEmpty) return;
    if (rows.isEmpty) return;
    final idx = rows.indexWhere((e) => e.id == focusId);
    _handledFocusScroll = true;
    if (idx < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _rowKeys[focusId]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 0.15,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = widget.rows;
    final focusId = widget.focusId;
    _maybeScrollToFocus(focusId, rows);
    final dateFmt = DateFormat('MMM d · h:mm a');

    if (rows.isEmpty) {
      return ListView(
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(GuardTokens.padScreen),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.12),
          Icon(
            Icons.event_available_outlined,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: GuardTokens.g2),
          Text(
            'No pre-approved visitors',
            style: GuardTokens.headingStyle(context).copyWith(
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: GuardTokens.g2),
          Text(
            'When residents add expected guests, they appear here. '
            'Tap a row to record arrival at the gate.',
            style: GuardTokens.captionStyle(context),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView.builder(
      controller: widget.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        GuardTokens.padScreen,
        GuardTokens.g2,
        GuardTokens.padScreen,
        GuardTokens.sectionGap + widget.bottomPadding,
      ),
      itemCount: rows.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: GuardTokens.g2),
            child: Material(
              color: GuardTokens.guardAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.notifications_active_rounded,
                      color: GuardTokens.guardAccentDeep,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${rows.length} expected '
                        '${rows.length == 1 ? 'visitor' : 'visitors'} '
                        '— pending until you confirm arrival.',
                        style: GuardTokens.captionStyle(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final e = rows[i - 1];
        final until = e.validUntil;
        final isHighlight = focusId != null && focusId == e.id;
        final initial =
            e.name.isNotEmpty ? e.name.trim()[0].toUpperCase() : '?';

        return Padding(
          key: _keyFor(e.id),
          padding: const EdgeInsets.only(bottom: GuardTokens.g2),
          child: Material(
            color: isHighlight
                ? GuardTokens.guardAccent.withValues(alpha: 0.06)
                : null,
            borderRadius: BorderRadius.circular(GuardTokens.radiusCard + 2),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  GuardTokens.radiusCard + 2,
                ),
                border: Border.all(
                  color: isHighlight
                      ? GuardTokens.guardAccent.withValues(alpha: 0.55)
                      : theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  GuardTokens.radiusCard + 2,
                ),
                child: Material(
                  color: theme.colorScheme.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => widget.onEntryTap(e),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          GuardTokens.guardAccent,
                                          GuardTokens.guardAccentDeep,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                e.name,
                                                style: GuardTokens.headingStyle(
                                                  context,
                                                ).copyWith(
                                                  fontSize: GuardTokens.body,
                                                ),
                                              ),
                                            ),
                                            _PreApprovedPendingPill(),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          e.phone,
                                          style: GuardTokens.captionStyle(
                                            context,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              GuardPreApprovedMetaRow(
                                icon: Icons.apartment_rounded,
                                text: e.flatLabel,
                                emphasized: true,
                              ),
                              if (until != null) ...[
                                const SizedBox(height: 6),
                                GuardPreApprovedMetaRow(
                                  icon: Icons.schedule_rounded,
                                  text:
                                      'Until ${dateFmt.format(until.toLocal())}',
                                  emphasized: false,
                                ),
                              ],
                              if (e.purpose != null &&
                                  e.purpose!.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                GuardPreApprovedMetaRow(
                                  icon: Icons.task_alt_rounded,
                                  text: e.purpose!.trim(),
                                  emphasized: false,
                                  maxLines: 2,
                                ),
                              ],
                              if (e.approvedByName != null &&
                                  e.approvedByName!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                GuardPreApprovedMetaRow(
                                  icon: Icons.verified_user_outlined,
                                  text: 'By ${e.approvedByName}',
                                  emphasized: false,
                                ),
                              ],
                              if (!widget.showVisitorArrivedButton) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.touch_app_rounded,
                                      size: 16,
                                      color: GuardTokens.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Tap to confirm arrival',
                                      style: GuardTokens.captionStyle(context)
                                          .copyWith(
                                        color: GuardTokens.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (widget.showVisitorArrivedButton)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                          child: FilledButton.icon(
                            onPressed: () => widget.onEntryTap(e),
                            style: GuardTokens.primaryFilled(context).copyWith(
                              minimumSize: WidgetStateProperty.all(
                                const Size(
                                  double.infinity,
                                  GuardTokens.btnPrimaryH,
                                ),
                              ),
                              shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    GuardTokens.radiusButton,
                                  ),
                                ),
                              ),
                            ),
                            icon: Icon(Icons.verified_user_outlined, size: 22),
                            label: const Text(
                              'Visitor arrived',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PreApprovedPendingPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: GuardTokens.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Pending',
        style: GuardTokens.captionStyle(context).copyWith(
          color: GuardTokens.warning,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class GuardPreApprovedMetaRow extends StatelessWidget {
  const GuardPreApprovedMetaRow({
    super.key,
    required this.icon,
    required this.text,
    this.emphasized = false,
    this.maxLines = 3,
  });

  final IconData icon;
  final String text;
  final bool emphasized;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: emphasized
              ? GuardTokens.guardAccentDeep
              : GuardTokens.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: (emphasized
                    ? GuardTokens.bodyStyle(context)
                    : GuardTokens.captionStyle(context))
                .copyWith(
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
              fontSize: emphasized ? 13.5 : null,
            ),
          ),
        ),
      ],
    );
  }
}
