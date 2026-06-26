import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/admin_search_field.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for managing villas / properties.
class AdminVillasScreen extends ConsumerStatefulWidget {
  const AdminVillasScreen({super.key});

  @override
  ConsumerState<AdminVillasScreen> createState() => _AdminVillasScreenState();
}

class _AdminVillasScreenState extends ConsumerState<AdminVillasScreen> {
  final _searchCtl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(adminVillasProvider);
  }

  @override
  Widget build(BuildContext context) {
    final villasAsync = ref.watch(adminVillasProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Properties',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showVillaForm(),
        backgroundColor: DesignColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Villa', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: villasAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ShimmerWrap(
              child: Column(
                children: List.generate(
                  6,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child:
                        ShimmerBox(height: 80, borderRadius: DesignRadius.lg),
                  ),
                ),
              ),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(top: 80),
            child: EmptyStateWidget(
              icon: Icons.error_outline_rounded,
              title: 'Failed to load properties',
              subtitle: 'Something went wrong. Please try again.',
              iconColor: DesignColors.error,
              actionLabel: 'Retry',
              onAction: _refresh,
            ),
          ),
          data: (villas) => _buildBody(villas),
        ),
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> villas) {
    if (villas.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 80),
            child: EmptyStateWidget(
              icon: Icons.home_work_outlined,
              title: 'No properties yet',
              subtitle: 'Tap + to add your first villa or property.',
              iconColor: DesignColors.primary,
            ),
          ),
        ],
      );
    }

    final inr = NumberFormat.currency(
        locale: 'en_IN', symbol: '\u20b9', decimalDigits: 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Summary
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [DesignColors.primary, DesignColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(DesignRadius.xl),
          ),
          child: Row(
            children: [
              const Icon(Icons.home_work_outlined,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                '${villas.length} Properties',
                style: DesignTypography.label.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AdminSearchField(
          controller: _searchCtl,
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          hint: 'Search by villa number, block, owner…',
        ),
        const SizedBox(height: 12),
        ..._filteredVillas(villas).asMap().entries.map((e) => _villaCard(e.value, inr, e.key)),
      ],
    );
  }

  List<Map<String, dynamic>> _filteredVillas(List<Map<String, dynamic>> villas) {
    if (_searchQuery.isEmpty) return villas;
    return villas.where((v) {
      final villaNum = (v['villaNumber'] ?? '').toString().toLowerCase();
      final block = (v['block'] ?? '').toString().toLowerCase();
      final owner = (v['ownerName'] ?? '').toString().toLowerCase();
      return villaNum.contains(_searchQuery) ||
          block.contains(_searchQuery) ||
          owner.contains(_searchQuery);
    }).toList();
  }

  Widget _villaCard(Map<String, dynamic> v, NumberFormat inr, [int index = 0]) {
    final villaNumber = v['villaNumber']?.toString() ?? '';
    final block = v['block']?.toString() ?? '';
    final ownerName = v['ownerName']?.toString() ?? '';
    final residentCount = _toInt(v['residentCount'] ?? v['_count']?['residents']);
    final maintenance = _toDouble(v['monthlyMaintenance']);

    return EnterprisePanel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      onTap: () => _showVillaForm(existing: v),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DesignColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              villaNumber.isNotEmpty ? villaNumber : '?',
              style: TextStyle(
                color: DesignColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
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
                        'Villa $villaNumber${block.isNotEmpty ? ' ($block)' : ''}',
                        style: DesignTypography.label
                            .copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (maintenance > 0)
                      Text(
                        inr.format(maintenance),
                        style: DesignTypography.captionSmall.copyWith(
                          color: DesignColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (ownerName.isNotEmpty) ownerName,
                    '$residentCount resident${residentCount != 1 ? 's' : ''}',
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
    ).animate(delay: DesignAnimations.staggerFor(index)).fadeIn(duration: 200.ms).slideY(begin: DesignAnimations.slideSubtle, curve: DesignAnimations.curveEntrance);
  }

  void _showVillaForm({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    final numberCtrl =
        TextEditingController(text: existing?['villaNumber']?.toString() ?? '');
    final blockCtrl =
        TextEditingController(text: existing?['block']?.toString() ?? '');
    final ownerNameCtrl =
        TextEditingController(text: existing?['ownerName']?.toString() ?? '');
    final ownerPhoneCtrl =
        TextEditingController(text: existing?['ownerPhone']?.toString() ?? '');
    final ownerEmailCtrl =
        TextEditingController(text: existing?['ownerEmail']?.toString() ?? '');
    final maintenanceCtrl = TextEditingController(
        text: existing?['monthlyMaintenance']?.toString() ?? '');
    final floorsCtrl =
        TextEditingController(text: existing?['floors']?.toString() ?? '');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
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
                  Text(isEdit ? 'Edit Villa' : 'Add Villa',
                      style: DesignTypography.headingM),
                  const SizedBox(height: 16),
                  _formField('Villa Number *', numberCtrl, required: true),
                  _formField('Block', blockCtrl),
                  _formField('Floors', floorsCtrl,
                      keyboardType: TextInputType.number),
                  _formField('Owner Name', ownerNameCtrl),
                  _formField('Owner Phone', ownerPhoneCtrl,
                      keyboardType: TextInputType.phone),
                  _formField('Owner Email', ownerEmailCtrl,
                      keyboardType: TextInputType.emailAddress),
                  _formField('Monthly Maintenance', maintenanceCtrl,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (isEdit) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _handleDelete(existing['id']?.toString() ?? '');
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: DesignColors.error,
                              side: BorderSide(color: DesignColors.error),
                            ),
                            child: const Text('Delete'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            if (!(formKey.currentState?.validate() ?? false)) return;
                            Navigator.pop(ctx);
                            if (isEdit) {
                              _handleUpdate(
                                existing['id']?.toString() ?? '',
                                numberCtrl.text,
                                blockCtrl.text,
                                ownerNameCtrl.text,
                                ownerPhoneCtrl.text,
                                ownerEmailCtrl.text,
                                maintenanceCtrl.text,
                                floorsCtrl.text,
                              );
                            } else {
                              _handleCreate(
                                numberCtrl.text,
                                blockCtrl.text,
                                ownerNameCtrl.text,
                                ownerPhoneCtrl.text,
                                ownerEmailCtrl.text,
                                maintenanceCtrl.text,
                                floorsCtrl.text,
                              );
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: DesignColors.primary,
                          ),
                          child: Text(isEdit ? 'Update' : 'Create'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formField(String label, TextEditingController ctrl,
      {TextInputType? keyboardType, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: DesignComponents.inputDecoration(label: label),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Future<void> _handleCreate(
    String number,
    String block,
    String ownerName,
    String ownerPhone,
    String ownerEmail,
    String maintenance,
    String floors,
  ) async {
    try {
      await ref.read(adminVillaRepositoryProvider).createVilla(
            villaNumber: number.trim(),
            block: block.trim().isNotEmpty ? block.trim() : null,
            ownerName: ownerName.trim().isNotEmpty ? ownerName.trim() : null,
            ownerPhone: ownerPhone.trim().isNotEmpty ? ownerPhone.trim() : null,
            ownerEmail: ownerEmail.trim().isNotEmpty ? ownerEmail.trim() : null,
            monthlyMaintenance: double.tryParse(maintenance),
            floors: int.tryParse(floors),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Villa created successfully')),
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
    String id,
    String number,
    String block,
    String ownerName,
    String ownerPhone,
    String ownerEmail,
    String maintenance,
    String floors,
  ) async {
    try {
      await ref.read(adminVillaRepositoryProvider).updateVilla(
            id,
            villaNumber: number.trim().isNotEmpty ? number.trim() : null,
            block: block.trim(),
            ownerName: ownerName.trim(),
            ownerPhone: ownerPhone.trim(),
            ownerEmail: ownerEmail.trim(),
            monthlyMaintenance: double.tryParse(maintenance),
            floors: int.tryParse(floors),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Villa updated successfully')),
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

  Future<void> _handleDelete(String id) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: DesignColors.borderLight, borderRadius: BorderRadius.circular(2))),
              Container(width: 56, height: 56,
                  decoration: BoxDecoration(color: DesignColors.error.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(Icons.home_work_outlined, color: DesignColors.error, size: 28)),
              const SizedBox(height: 16),
              Text('Delete Villa?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: DesignColors.textPrimary)),
              const SizedBox(height: 8),
              Text('Are you sure you want to delete this villa? This cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: DesignColors.textSecondary, height: 1.4)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetCtx, false),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                  child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(
                  onPressed: () => Navigator.pop(sheetCtx, true),
                  style: FilledButton.styleFrom(backgroundColor: DesignColors.error, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                  child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)))),
              ]),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(adminVillaRepositoryProvider).deleteVilla(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Villa deleted successfully')),
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

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}
