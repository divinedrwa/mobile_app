import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/guard_models.dart';
import '../../../../core/widgets/screen_skeletons.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_command_providers.dart';
import '../providers/guard_providers.dart';
import '../widgets/guard_flat_picker.dart';
import '../widgets/guard_screen_section_header.dart';

/// Premium delivery entry — brand grid, searchable flat, sticky actions.
class GuardDeliveryQuickPage extends ConsumerStatefulWidget {
  const GuardDeliveryQuickPage({super.key});

  @override
  ConsumerState<GuardDeliveryQuickPage> createState() =>
      _GuardDeliveryQuickPageState();
}

class _GuardDeliveryQuickPageState
    extends ConsumerState<GuardDeliveryQuickPage> {
  static const _brands = <({String label, String api})>[
    (label: 'Zomato', api: 'Zomato'),
    (label: 'Swiggy', api: 'Swiggy'),
    (label: 'Amazon', api: 'Amazon'),
    (label: 'Flipkart', api: 'Flipkart'),
    (label: 'Blinkit', api: 'Blinkit'),
    (label: 'Other', api: 'Other'),
  ];

  final _tracking = TextEditingController();
  final _sender = TextEditingController();
  final _description = TextEditingController();

  String _brand = 'Zomato';
  // A parcel goes to a single flat — grid single-select (same picker as
  // "Add visitor", but one flat at a time).
  String? _villaId;
  String? _flatLabel;
  Set<String> _selectedUserIds = {};
  bool _submitting = false;

  @override
  void dispose() {
    _tracking.dispose();
    _sender.dispose();
    _description.dispose();
    super.dispose();
  }

  void _onFlatTapped(GuardFlatSelection flat) {
    if (_submitting) return;
    setState(() {
      if (_villaId == flat.villaId) {
        _villaId = null;
        _flatLabel = null;
        _selectedUserIds = {};
      } else {
        _villaId = flat.villaId;
        _flatLabel = flat.label;
        _selectedUserIds = flat.userIds.toSet();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final residentsAsync = ref.watch(guardResidentsPickerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GuardThemeScope(
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            icon: Icon(Icons.close_rounded),
            onPressed: _submitting ? null : () => context.pop(),
          ),
          title: Text(
            'Delivery entry',
            style: GuardTokens.headingStyle(context),
          ),
          centerTitle: false,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  GuardTokens.padScreen,
                  GuardTokens.g2,
                  GuardTokens.padScreen,
                  GuardTokens.g3,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const GuardScreenSectionHeader(
                      icon: Icons.inventory_2_rounded,
                      title: 'Courier / delivery app',
                      subtitle: 'Tap the brand handing over the parcel',
                    ),
                    const SizedBox(height: GuardTokens.g1 + 2),
                    // Compact 3-column brand grid. Previously this was a
                    // 2-column 108px-tall hero grid which used ~340px of
                    // vertical real estate just to pick a brand. Same six
                    // brands, smaller tiles — ~64px each, ~200px saved.
                    LayoutBuilder(
                      builder: (context, c) {
                        const spacing = 8.0;
                        final cellW = (c.maxWidth - spacing * 2) / 3;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: _brands.map((b) {
                            final sel = _brand == b.api;
                            return Semantics(
                              label: '${b.label} courier${sel ? ', selected' : ''}',
                              button: true,
                              selected: sel,
                              child: SizedBox(
                              width: cellW,
                              child: Material(
                                color: sel
                                    ? GuardTokens.guardAccent
                                        .withValues(alpha: 0.10)
                                    : (isDark
                                        ? GuardTokens.darkCard
                                        : GuardTokens.surfaceCard),
                                borderRadius: BorderRadius.circular(
                                  GuardTokens.radiusButton,
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(
                                    GuardTokens.radiusButton,
                                  ),
                                  onTap: _submitting
                                      ? null
                                      : () => setState(() => _brand = b.api),
                                  child: Container(
                                    height: 64,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        GuardTokens.radiusButton,
                                      ),
                                      border: Border.all(
                                        width: sel ? 1.5 : 1,
                                        color: sel
                                            ? GuardTokens.guardAccent
                                            : (isDark
                                                  ? GuardTokens.darkBorder
                                                  : GuardTokens.borderSubtle),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.storefront_rounded,
                                          color: sel
                                              ? GuardTokens.guardAccentDeep
                                              : GuardTokens.guardAccent,
                                          size: 18,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          b.label,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: sel
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            fontSize: 12.5,
                                            height: 1.1,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: GuardTokens.sectionGap),
                    const GuardScreenSectionHeader(
                      icon: Icons.people_rounded,
                      title: 'Deliver to flat',
                      subtitle: 'Search or pick a block, then tap the flat',
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    residentsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: GuardTokens.g2),
                        child: PickerSkeleton(),
                      ),
                      error: (e, _) => Container(
                        padding: const EdgeInsets.all(GuardTokens.g2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            GuardTokens.radiusCard,
                          ),
                          color: GuardTokens.warningMuted,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: GuardTokens.warning,
                            ),
                            const SizedBox(width: GuardTokens.g2),
                            Expanded(child: Text(guardCommandErrorMessage(e))),
                            TextButton(
                              onPressed: () =>
                                  ref.invalidate(guardVillasProvider),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                      data: (residents) {
                        if (residents.isEmpty) {
                          return Text(
                            'No residents found.',
                            style: GuardTokens.bodyStyle(context),
                          );
                        }
                        return GuardFlatPicker(
                          residents: residents,
                          selectedUserIds: _selectedUserIds,
                          onToggleFlat: _onFlatTapped,
                        );
                      },
                    ),
                    if (_flatLabel != null) ...[
                      const SizedBox(height: GuardTokens.g2),
                      _SelectedFlatBanner(label: _flatLabel!),
                    ],
                    const SizedBox(height: GuardTokens.sectionGap),
                    const GuardScreenSectionHeader(
                      icon: Icons.receipt_long_rounded,
                      title: 'Parcel details',
                      subtitle: 'Optional fields help later identification',
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    TextField(
                      controller: _tracking,
                      enabled: !_submitting,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Tracking number (optional)',
                        filled: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    TextField(
                      controller: _sender,
                      enabled: !_submitting,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Sender / rider name (optional)',
                        filled: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    TextField(
                      controller: _description,
                      enabled: !_submitting,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        hintText: 'Food, medicine, fragile box, left at gate…',
                        filled: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: GuardTokens.sectionGap),
                  ],
                ),
              ),
            ),
            Material(
              elevation: 10,
              color: theme.colorScheme.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    GuardTokens.padScreen,
                    GuardTokens.g2,
                    GuardTokens.padScreen,
                    GuardTokens.g2,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: GuardTokens.btnPrimaryH + 2,
                        child: FilledButton(
                          style: GuardTokens.primaryFilled(context),
                          onPressed: _busy(residentsAsync)
                              ? null
                              : () => _submit(false),
                          child: _submitting
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Mark delivered',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                      const SizedBox(height: GuardTokens.g2),
                      SizedBox(
                        height: GuardTokens.btnPrimaryH,
                        child: OutlinedButton(
                          onPressed: _busy(residentsAsync)
                              ? null
                              : () => _submit(true),
                          child: const Text(
                            'Keep at gate',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: GuardTokens.warning,
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
      ),
    );
  }

  bool _busy(AsyncValue<List<ResidentPickerItem>> async) {
    return _submitting ||
        !async.maybeWhen(data: (v) => v.isNotEmpty, orElse: () => false);
  }

  Future<void> _submit(bool leftAtGate) async {
    final villaId = _villaId;
    if (villaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Select a flat before submitting'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final noteParts = <String>[
        if (leftAtGate) 'Left at gate',
        if (_description.text.trim().isNotEmpty) _description.text.trim(),
      ];
      await ref.read(guardDeliverySubmitProvider)(
        GuardDeliverySubmitParams(
          villaId: villaId,
          deliveryService: _brand,
          trackingNumber: _tracking.text.trim().isEmpty
              ? null
              : _tracking.text.trim(),
          senderName: _sender.text.trim().isEmpty ? null : _sender.text.trim(),
          description: noteParts.isEmpty ? null : noteParts.join(' | '),
        ),
      );
      ref.invalidate(guardPendingParcelsProvider);
      ref.invalidate(guardTodayParcelsProvider);
      ref.invalidate(guardDashboardProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              leftAtGate
                  ? 'Parcel logged · left at gate'
                  : 'Parcel logged · delivered',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(guardCommandErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

/// Confirmation of the flat chosen in the grid — the tapped tile can scroll out
/// of view once the list is long or filtered, so restate it near the actions.
class _SelectedFlatBanner extends StatelessWidget {
  const _SelectedFlatBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GuardTokens.g2,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GuardTokens.radiusButton),
        color: GuardTokens.guardAccent.withValues(alpha: 0.10),
        border: Border.all(color: GuardTokens.guardAccent),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded,
              size: 18, color: GuardTokens.guardAccentDeep),
          const SizedBox(width: GuardTokens.g2),
          Text(
            'Delivering to ',
            style: GuardTokens.bodyStyle(context),
          ),
          Text(
            label,
            style: GuardTokens.bodyStyle(context)
                .copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
