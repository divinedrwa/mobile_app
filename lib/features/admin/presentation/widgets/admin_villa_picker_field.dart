import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/admin_search_field.dart';

/// Searchable villa selector for admin forms (replaces long dropdown lists).
class AdminVillaPickerField extends StatelessWidget {
  const AdminVillaPickerField({
    super.key,
    required this.villas,
    required this.selectedVillaId,
    required this.onSelected,
    this.label = 'Villa',
    this.required = false,
    this.allowClear = false,
    this.enabled = true,
    this.errorText,
  });

  final List<Map<String, dynamic>> villas;
  final String? selectedVillaId;
  final ValueChanged<String?> onSelected;
  final String label;
  final bool required;
  final bool allowClear;
  final bool enabled;
  final String? errorText;

  String _labelFor(String? id) {
    if (id == null || id.isEmpty) return '';
    for (final v in villas) {
      if (v['id']?.toString() == id) return _formatVilla(v);
    }
    return '';
  }

  static String _formatVilla(Map<String, dynamic> v) {
    final num = v['villaNumber']?.toString().trim() ?? '';
    final block = v['block']?.toString().trim() ?? '';
    final owner = v['ownerName']?.toString().trim() ?? '';
    final base = block.isNotEmpty && num.isNotEmpty ? '$block · $num' : num;
    if (base.isEmpty) return v['id']?.toString() ?? 'Villa';
    if (owner.isNotEmpty) return '$base · $owner';
    return base;
  }

  Future<void> _openPicker(BuildContext context) async {
    if (!enabled) return;
    final searchCtl = TextEditingController();
    var query = '';

    final picked = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final q = query.trim().toLowerCase();
            final filtered = villas.where((v) {
              if (q.isEmpty) return true;
              final hay = [
                v['villaNumber'],
                v['block'],
                v['ownerName'],
              ].map((e) => e?.toString().toLowerCase() ?? '').join(' ');
              return hay.contains(q);
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.75,
                ),
                decoration: BoxDecoration(
                  color: DesignColors.surface,
                  borderRadius: BorderRadius.circular(DesignRadius.xl),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: DesignColors.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Select $label',
                              style: DesignTypography.headingM.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AdminSearchField(
                        controller: searchCtl,
                        hint: 'Search villa, block, owner…',
                        onChanged: (v) => setSheetState(() => query = v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                        itemCount:
                            filtered.length + (allowClear && q.isEmpty ? 1 : 0),
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          if (allowClear && q.isEmpty && i == 0) {
                            return ListTile(
                              leading: Icon(Icons.block,
                                  color: DesignColors.textTertiary),
                              title: const Text('No villa linked'),
                              onTap: () => Navigator.pop(ctx, null),
                            );
                          }
                          final index =
                              allowClear && q.isEmpty ? i - 1 : i;
                          final v = filtered[index];
                          final id = v['id']?.toString() ?? '';
                          final selected = id == selectedVillaId;
                          return ListTile(
                            leading: Icon(
                              Icons.home_work_outlined,
                              color: selected
                                  ? DesignColors.primary
                                  : DesignColors.textSecondary,
                            ),
                            title: Text(
                              _formatVilla(v),
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            trailing: selected
                                ? Icon(Icons.check_circle,
                                    color: DesignColors.primary)
                                : null,
                            onTap: () => Navigator.pop(ctx, id),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    searchCtl.dispose();
    if (picked != selectedVillaId) onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabel = _labelFor(selectedVillaId);
    final hasValue = selectedLabel.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: enabled ? () => _openPicker(context) : null,
          borderRadius: BorderRadius.circular(DesignRadius.lg),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: required ? '$label *' : label,
              filled: true,
              fillColor: DesignColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DesignRadius.lg),
              ),
              errorText: errorText,
              suffixIcon: Icon(
                Icons.unfold_more_rounded,
                color: DesignColors.textTertiary,
              ),
            ),
            child: Text(
              hasValue
                  ? selectedLabel
                  : (allowClear
                      ? 'Tap to link a villa (optional)'
                      : 'Tap to select villa'),
              style: DesignTypography.body.copyWith(
                color: hasValue
                    ? DesignColors.textPrimary
                    : DesignColors.textTertiary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
