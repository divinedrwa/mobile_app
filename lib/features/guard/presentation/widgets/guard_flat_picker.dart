import 'package:flutter/material.dart';

import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';

/// A flat (villa) the guard tapped in [GuardFlatPicker].
///
/// Carries the flat identity so single-flat flows (delivery, vehicle) can read
/// [villaId], and the full [userIds] set so multi-resident flows (add visitor)
/// can notify everyone living there.
class GuardFlatSelection {
  const GuardFlatSelection({
    required this.villaId,
    required this.label,
    required this.userIds,
  });

  final String villaId;
  final String label;
  final List<String> userIds;
}

/// One flat (villa) grouped from the resident directory.
class _Flat {
  _Flat({
    required this.villaId,
    required this.block,
    required this.villaNumber,
    required this.userIds,
    required this.residentNames,
  });

  final String villaId;
  final String? block;
  final String villaNumber;
  final List<String> userIds;
  final List<String> residentNames;

  String get label {
    final b = block?.trim();
    return (b != null && b.isNotEmpty) ? '$b-$villaNumber' : villaNumber;
  }

  GuardFlatSelection toSelection() =>
      GuardFlatSelection(villaId: villaId, label: label, userIds: userIds);
}

/// Block-first, select-by-flat picker for guard flows (add visitor / delivery /
/// vehicle). Search on top, block chips, then a grid of flat tiles. Tapping a
/// flat hands the whole flat (villaId + all its resident user ids) back to the
/// parent, which owns the selection state — so the same grid serves both
/// multi-select (add visitor notifies every resident) and single-select
/// (delivery/vehicle target one flat).
class GuardFlatPicker extends StatefulWidget {
  const GuardFlatPicker({
    super.key,
    required this.residents,
    required this.selectedUserIds,
    required this.onToggleFlat,
    this.singleSelect = false,
  });

  final List<ResidentPickerItem> residents;
  final Set<String> selectedUserIds;

  /// When true, highlight a flat if any occupant is selected (visitor approval).
  final bool singleSelect;

  /// Toggle a whole flat — receives the flat identity + every resident user id.
  final void Function(GuardFlatSelection flat) onToggleFlat;

  @override
  State<GuardFlatPicker> createState() => _GuardFlatPickerState();
}

class _GuardFlatPickerState extends State<GuardFlatPicker> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _block; // null = "All"

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_Flat> _flats() {
    final byVilla = <String, _Flat>{};
    for (final r in widget.residents) {
      final vid = r.villaId;
      if (vid.isEmpty) continue;
      final flat = byVilla.putIfAbsent(
        vid,
        () => _Flat(
          villaId: vid,
          block: r.block,
          villaNumber: r.villaNumber,
          userIds: [],
          residentNames: [],
        ),
      );
      flat.userIds.add(r.userId);
      if (r.name.trim().isNotEmpty) flat.residentNames.add(r.name.trim());
    }
    final list = byVilla.values.toList();
    list.sort((a, b) {
      final bc = (a.block ?? '').compareTo(b.block ?? '');
      if (bc != 0) return bc;
      // Numeric-aware where possible, else lexical.
      final an = int.tryParse(a.villaNumber);
      final bn = int.tryParse(b.villaNumber);
      if (an != null && bn != null) return an.compareTo(bn);
      return a.villaNumber.compareTo(b.villaNumber);
    });
    return list;
  }

  List<String> _blocks(List<_Flat> flats) {
    final set = <String>{};
    for (final f in flats) {
      final b = f.block?.trim();
      if (b != null && b.isNotEmpty) set.add(b);
    }
    final list = set.toList()..sort();
    return list;
  }

  bool _isSelected(_Flat f) {
    if (widget.singleSelect) {
      return f.userIds.any(widget.selectedUserIds.contains);
    }
    return f.userIds.isNotEmpty && f.userIds.every(widget.selectedUserIds.contains);
  }

  @override
  Widget build(BuildContext context) {
    final flats = _flats();
    final blocks = _blocks(flats);
    final q = _query.trim().toLowerCase();

    final visible = flats.where((f) {
      if (q.isNotEmpty) {
        final inLabel = f.label.toLowerCase().contains(q);
        final inName =
            f.residentNames.any((n) => n.toLowerCase().contains(q));
        return inLabel || inName;
      }
      if (_block == null) return true;
      return (f.block ?? '') == _block;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _query = v),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search name, flat or block',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        // Block chips — hidden while searching (search spans all blocks).
        if (q.isEmpty && blocks.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _BlockChip(
                  label: 'All',
                  selected: _block == null,
                  onTap: () => setState(() => _block = null),
                ),
                for (final b in blocks)
                  _BlockChip(
                    label: b,
                    selected: _block == b,
                    onTap: () => setState(() => _block = b),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                q.isNotEmpty ? 'No flats match "$_query".' : 'No flats found.',
                style: GuardTokens.captionStyle(context)
                    .copyWith(color: GuardTokens.textSecondary),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 130,
              mainAxisExtent: 52,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: visible.length,
            itemBuilder: (context, i) {
              final f = visible[i];
              final selected = _isSelected(f);
              return GuardFlatGridTile(
                label: f.label,
                selected: selected,
                onTap: () => widget.onToggleFlat(f.toSelection()),
              );
            },
          ),
      ],
    );
  }
}

class _BlockChip extends StatelessWidget {
  const _BlockChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : GuardTokens.textPrimary,
          fontSize: 13,
        ),
        selectedColor: GuardTokens.guardAccentDeep,
        showCheckmark: false,
      ),
    );
  }
}

/// Flat tile used in [GuardFlatPicker] and residents directory grid.
class GuardFlatGridTile extends StatelessWidget {
  const GuardFlatGridTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const tone = GuardTokens.guardAccentDeep;
    return Material(
      color: selected ? tone.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? tone
                  : GuardTokens.textSecondary.withValues(alpha: 0.25),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected) ...[
                    Icon(Icons.check_circle_rounded, size: 16, color: tone),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: selected ? tone : GuardTokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: GuardTokens.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Restates the flats chosen in [GuardFlatPicker] as labelled chips near the
/// submit actions — the tapped tiles can scroll out of view once the grid is
/// long or filtered. Used by delivery / vehicle multi-select flows.
class GuardSelectedFlatsBanner extends StatelessWidget {
  const GuardSelectedFlatsBanner({
    super.key,
    required this.verb,
    required this.labels,
  });

  final String verb;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: GuardTokens.guardAccent.withValues(alpha: 0.10),
        border: Border.all(color: GuardTokens.guardAccent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 18, color: GuardTokens.guardAccentDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$verb ${labels.length == 1 ? '1 flat' : '${labels.length} flats'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: GuardTokens.guardAccentDeep,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final l in labels)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: GuardTokens.guardAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          l,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: GuardTokens.guardAccentDeep,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
