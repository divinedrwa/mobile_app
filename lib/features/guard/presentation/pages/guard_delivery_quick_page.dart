import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_command_providers.dart';
import '../providers/guard_providers.dart';
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

  final _flatQuery = TextEditingController();
  final _tracking = TextEditingController();
  final _sender = TextEditingController();
  final _description = TextEditingController();

  String _brand = 'Zomato';
  ResidentPickerItem? _resident;
  bool _submitting = false;

  @override
  void dispose() {
    _flatQuery.dispose();
    _tracking.dispose();
    _sender.dispose();
    _description.dispose();
    super.dispose();
  }

  List<ResidentPickerItem> _filter(List<ResidentPickerItem> all) {
    final q = _flatQuery.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((r) {
      final block = (r.block ?? '').toLowerCase();
      final num = r.villaNumber.toLowerCase();
      final name = r.name.toLowerCase();
      return block.contains(q) ||
          num.contains(q) ||
          '$block $num'.contains(q) ||
          name.contains(q);
    }).toList();
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
            icon: const Icon(Icons.close_rounded),
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
                    const SizedBox(height: GuardTokens.g2),
                    LayoutBuilder(
                      builder: (context, c) {
                        final cellW = (c.maxWidth - GuardTokens.g2) / 2;
                        return Wrap(
                          spacing: GuardTokens.g2,
                          runSpacing: GuardTokens.g2,
                          children: _brands.map((b) {
                            final sel = _brand == b.api;
                            return SizedBox(
                              width: cellW.clamp(120, 200),
                              child: Material(
                                color: isDark
                                    ? GuardTokens.darkCard
                                    : GuardTokens.surfaceCard,
                                borderRadius: BorderRadius.circular(
                                  GuardTokens.radiusLg,
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(
                                    GuardTokens.radiusLg,
                                  ),
                                  onTap: _submitting
                                      ? null
                                      : () => setState(() => _brand = b.api),
                                  child: Container(
                                    height:
                                        GuardTokens.heroQuickActionMinHeight,
                                    padding: const EdgeInsets.all(
                                      GuardTokens.g2,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        GuardTokens.radiusLg,
                                      ),
                                      border: Border.all(
                                        width: sel ? 2 : 1,
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
                                      children: [
                                        const Icon(
                                          Icons.storefront_rounded,
                                          color: GuardTokens.guardAccent,
                                          size: 28,
                                        ),
                                        const SizedBox(height: GuardTokens.g2),
                                        Text(
                                          b.label,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: GuardTokens.body,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
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
                      title: 'Deliver to resident',
                      subtitle: 'Search by name or flat — tap to select',
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    TextField(
                      controller: _flatQuery,
                      onChanged: (_) => setState(() {}),
                      enabled: !_submitting,
                      decoration: InputDecoration(
                        hintText: 'Block, flat, or name…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            GuardTokens.radiusButton,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    residentsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(GuardTokens.g3),
                        child: Center(child: CircularProgressIndicator()),
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
                            const Icon(
                              Icons.error_outline_rounded,
                              color: GuardTokens.warning,
                            ),
                            const SizedBox(width: GuardTokens.g2),
                            Expanded(child: Text(userFacingMessage(e))),
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
                        final filtered = _filter(residents);
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              GuardTokens.radiusCard,
                            ),
                            border: Border.all(
                              color: isDark
                                  ? GuardTokens.darkBorder
                                  : GuardTokens.borderSubtle,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              GuardTokens.radiusCard,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 280),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) => Divider(
                                  height: 1,
                                  indent: GuardTokens.g2,
                                  endIndent: GuardTokens.g2,
                                  color: GuardTokens.borderSubtle
                                      .withValues(alpha: 0.7),
                                ),
                                itemBuilder: (_, i) {
                                  final r = filtered[i];
                                  final sel = _resident?.userId == r.userId;
                                  return Material(
                                    color: sel
                                        ? GuardTokens.success
                                            .withValues(alpha: 0.08)
                                        : Colors.transparent,
                                    child: InkWell(
                                      onTap: _submitting
                                          ? null
                                          : () =>
                                              setState(() => _resident = r),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: GuardTokens.g2,
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              sel
                                                  ? Icons
                                                      .radio_button_checked_rounded
                                                  : Icons
                                                      .radio_button_off_rounded,
                                              size: 22,
                                              color: sel
                                                  ? GuardTokens.success
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.4),
                                            ),
                                            const SizedBox(
                                              width: GuardTokens.g2,
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    r.name,
                                                    style: TextStyle(
                                                      fontWeight: sel
                                                          ? FontWeight.w700
                                                          : FontWeight.w500,
                                                      fontSize:
                                                          GuardTokens.body,
                                                    ),
                                                  ),
                                                  Text(
                                                    r.tag.isNotEmpty
                                                        ? '${r.flatLabel} · ${r.tag}'
                                                        : r.flatLabel,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: theme
                                                          .colorScheme
                                                          .onSurface
                                                          .withValues(
                                                            alpha: 0.6,
                                                          ),
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (sel)
                                              const Icon(
                                                Icons.done_rounded,
                                                size: 20,
                                                color: GuardTokens.success,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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
                                  'Marked delivered',
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
    final residentsList =
        await ref.read(guardResidentsPickerProvider.future);
    if (residentsList.isEmpty) return;
    final selected = _resident ?? residentsList.first;

    setState(() => _submitting = true);
    try {
      final noteParts = <String>[
        if (leftAtGate) 'Left at gate',
        if (_description.text.trim().isNotEmpty) _description.text.trim(),
      ];
      await ref.read(guardDeliverySubmitProvider)(
        GuardDeliverySubmitParams(
          villaId: selected.villaId,
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
        ).showSnackBar(SnackBar(content: Text(userFacingMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
