import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for managing amenities.
class AdminAmenitiesScreen extends ConsumerStatefulWidget {
  const AdminAmenitiesScreen({super.key});

  @override
  ConsumerState<AdminAmenitiesScreen> createState() =>
      _AdminAmenitiesScreenState();
}

class _AdminAmenitiesScreenState extends ConsumerState<AdminAmenitiesScreen> {
  Future<void> _refresh() async {
    ref.invalidate(adminAmenitiesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final amenitiesAsync = ref.watch(adminAmenitiesProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Amenities',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        backgroundColor: const Color(0xFFF59E0B),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Amenity', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: amenitiesAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ShimmerWrap(
              child: Column(
                children: List.generate(
                  5,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child:
                        ShimmerBox(height: 72, borderRadius: DesignRadius.lg),
                  ),
                ),
              ),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(top: 80),
            child: EmptyStateWidget(
              icon: Icons.error_outline_rounded,
              title: 'Failed to load amenities',
              subtitle: 'Something went wrong. Please try again.',
              iconColor: DesignColors.error,
              actionLabel: 'Retry',
              onAction: _refresh,
            ),
          ),
          data: (amenities) {
            if (amenities.isEmpty) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: EmptyStateWidget(
                      icon: Icons.fitness_center_outlined,
                      title: 'No amenities yet',
                      subtitle: 'Tap + to add your first amenity.',
                      iconColor: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              );
            }
            return _buildList(amenities);
          },
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> amenities) {
    final inr = NumberFormat.currency(
        locale: 'en_IN', symbol: '\u20b9', decimalDigits: 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: amenities.map((a) {
        final name = a['name']?.toString() ?? '';
        final capacity = a['capacity'];
        final price = _toDouble(a['pricePerHour']);
        final isActive = a['isActive'] != false;
        final desc = a['description']?.toString() ?? '';

        return EnterprisePanel(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          onTap: () => _showForm(existing: a),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fitness_center_outlined,
                    color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: DesignTypography.label
                                .copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Tooltip(
                          message: isActive ? 'Active' : 'Inactive',
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? DesignColors.primary
                                  : DesignColors.textTertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (capacity != null) 'Cap: $capacity',
                        if (price > 0) '${inr.format(price)}/hr',
                        if (desc.isNotEmpty) desc,
                      ].join(' \u00b7 '),
                      style: DesignTypography.captionSmall
                          .copyWith(color: DesignColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showForm({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description']?.toString() ?? '');
    final capCtrl =
        TextEditingController(text: existing?['capacity']?.toString() ?? '');
    final priceCtrl = TextEditingController(
        text: existing?['pricePerHour']?.toString() ?? '');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: BorderRadius.circular(DesignRadius.xl),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: DesignColors.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(isEdit ? 'Edit Amenity' : 'Add Amenity',
                      style: DesignTypography.headingM),
                  const SizedBox(height: 16),
                  _field('Name *', nameCtrl, required: true),
                  _field('Description', descCtrl),
                  _field('Capacity', capCtrl,
                      keyboardType: TextInputType.number),
                  _field('Price per Hour', priceCtrl,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        Navigator.pop(ctx);
                        if (isEdit) {
                          _handleUpdate(
                              existing['id']?.toString() ?? '',
                              nameCtrl.text,
                              descCtrl.text,
                              capCtrl.text,
                              priceCtrl.text);
                        } else {
                          _handleCreate(nameCtrl.text, descCtrl.text,
                              capCtrl.text, priceCtrl.text);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                      ),
                      child: Text(isEdit ? 'Update' : 'Create'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboardType, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DesignRadius.md),
          ),
          isDense: true,
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Future<void> _handleCreate(
      String name, String desc, String cap, String price) async {
    try {
      await ref.read(adminAmenityRepositoryProvider).createAmenity(
            name: name.trim(),
            description: desc.trim().isNotEmpty ? desc.trim() : null,
            capacity: int.tryParse(cap),
            pricePerHour: double.tryParse(price),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Amenity created')),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    }
  }

  Future<void> _handleUpdate(
      String id, String name, String desc, String cap, String price) async {
    try {
      await ref.read(adminAmenityRepositoryProvider).updateAmenity(
            id,
            name: name.trim().isNotEmpty ? name.trim() : null,
            description: desc.trim(),
            capacity: int.tryParse(cap),
            pricePerHour: double.tryParse(price),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Amenity updated')),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    }
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}
