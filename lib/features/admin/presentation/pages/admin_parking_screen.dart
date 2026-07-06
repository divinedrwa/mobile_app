import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/admin_search_field.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for vehicle & parking management.
class AdminParkingScreen extends ConsumerStatefulWidget {
  const AdminParkingScreen({super.key});

  @override
  ConsumerState<AdminParkingScreen> createState() =>
      _AdminParkingScreenState();
}

class _AdminParkingScreenState extends ConsumerState<AdminParkingScreen> {
  String? _typeFilter;
  final _searchCtl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(adminParkingOverviewProvider);
    ref.invalidate(adminParkingVehiclesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(adminParkingOverviewProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Vehicles & Parking',
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
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: overviewAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ShimmerWrap(
              child: Column(
                children: [
                  ShimmerBox(height: 100, borderRadius: DesignRadius.xl),
                  const SizedBox(height: 12),
                  ...List.generate(
                    4,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ShimmerBox(
                          height: 64, borderRadius: DesignRadius.lg),
                    ),
                  ),
                ],
              ),
            ),
          ),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Failed to load parking data',
                  subtitle: 'Something went wrong. Please try again.',
                  iconColor: DesignColors.error,
                  actionLabel: 'Retry',
                  onAction: _refresh,
                ),
              ),
            ],
          ),
          data: (overview) => _buildBody(overview),
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> overview) {
    final vehiclesAsync = ref.watch(adminParkingVehiclesProvider);

    final totalSlots = _toInt(overview['totalSlots']);
    final occupied = _toInt(overview['occupiedSlots']);
    final available = totalSlots - occupied;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Slot utilization
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [DesignColors.secondary, Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(DesignRadius.xl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_parking,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Parking Overview',
                    style: DesignTypography.label.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _slotStat('Total', totalSlots),
                  const SizedBox(width: 16),
                  _slotStat('Occupied', occupied),
                  const SizedBox(width: 16),
                  _slotStat('Available', available),
                ],
              ),
              if (totalSlots > 0) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: totalSlots > 0 ? occupied / totalSlots : 0,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Vehicle list
        const EnterpriseSectionHeader(title: 'Vehicles'),
        const SizedBox(height: 8),
        AdminSearchField(
          controller: _searchCtl,
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          hint: 'Search by number, villa, owner…',
        ),
        const SizedBox(height: 12),
        vehiclesAsync.when(
          loading: () => ShimmerWrap(
            child: Column(
              children: List.generate(
                4,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child:
                      ShimmerBox(height: 64, borderRadius: DesignRadius.lg),
                ),
              ),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (vehicles) => _vehicleSection(vehicles),
        ),
      ],
    );
  }

  Widget _slotStat(String label, int value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: DesignTypography.captionSmall.copyWith(
              color: Colors.white54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleSection(List<Map<String, dynamic>> vehicles) {
    // Type counts
    final typeCounts = <String?, int>{null: vehicles.length};
    for (final v in vehicles) {
      final t = v['type']?.toString().toUpperCase() ??
          v['vehicleType']?.toString().toUpperCase();
      if (t != null) typeCounts[t] = (typeCounts[t] ?? 0) + 1;
    }

    final types = typeCounts.keys.where((k) => k != null).toList()..sort();
    var filtered = _typeFilter == null
        ? vehicles
        : vehicles.where((v) {
            final t = v['type']?.toString().toUpperCase() ??
                v['vehicleType']?.toString().toUpperCase();
            return t == _typeFilter;
          }).toList();

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((v) {
        final number = (v['vehicleNumber'] ?? v['registrationNumber'] ?? '').toString().toLowerCase();
        final villa = (v['villa'] as Map<String, dynamic>?)?['villaNumber']?.toString().toLowerCase() ?? '';
        final owner = (v['ownerName'] ?? v['residentName'] ?? v['ownerLabel'] ?? '').toString().toLowerCase();
        return number.contains(_searchQuery) ||
            villa.contains(_searchQuery) ||
            owner.contains(_searchQuery);
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _chipItem(null, 'All', typeCounts[null] ?? 0),
              ...types.map((t) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _chipItem(
                        t, _formatType(t!), typeCounts[t] ?? 0),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: EmptyStateWidget(
              icon: Icons.directions_car_outlined,
              title: 'No vehicles',
              subtitle: 'No vehicles registered yet.',
              iconColor: DesignColors.secondary,
            ),
          )
        else
          ...filtered.asMap().entries.map((e) => _vehicleCard(e.value, e.key)),
      ],
    );
  }

  Widget _chipItem(String? type, String label, int count) {
    final isSelected = _typeFilter == type;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (_) => setState(() => _typeFilter = type),
      selectedColor: DesignColors.secondary,
      backgroundColor: DesignColors.surfaceSoft,
      labelStyle: DesignTypography.labelSmall.copyWith(
        color: isSelected ? Colors.white : DesignColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      side: BorderSide(
        color: isSelected
            ? DesignColors.secondary
            : DesignColors.borderLight,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignRadius.full),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _vehicleCard(Map<String, dynamic> v, [int index = 0]) {
    final number = v['vehicleNumber']?.toString() ??
        v['registrationNumber']?.toString() ??
        '';
    final type = v['type']?.toString() ??
        v['vehicleType']?.toString() ??
        '';
    final villa = v['villa'] as Map<String, dynamic>?;
    final villaNum = villa?['villaNumber']?.toString() ?? '';
    final ownerLabel = v['ownerLabel']?.toString() ?? '';
    final category = v['registrationCategory']?.toString() ?? 'RESIDENT';
    final ownerName =
        v['ownerName']?.toString() ?? v['residentName']?.toString() ?? '';

    return EnterprisePanel(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DesignColors.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _vehicleIcon(type.toUpperCase()),
              color: DesignColors.secondary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number.isNotEmpty ? number : 'No registration',
                  style: DesignTypography.label
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  [
                    _formatCategory(category),
                    if (type.isNotEmpty) _formatType(type.toUpperCase()),
                    if (villaNum.isNotEmpty) 'Villa $villaNum',
                    if (ownerLabel.isNotEmpty) ownerLabel,
                    if (ownerName.isNotEmpty && ownerLabel.isEmpty) ownerName,
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

  static IconData _vehicleIcon(String type) {
    switch (type) {
      case 'FOUR_WHEELER':
      case 'CAR':
        return Icons.directions_car_outlined;
      case 'TWO_WHEELER':
      case 'BIKE':
      case 'MOTORCYCLE':
        return Icons.two_wheeler;
      case 'BICYCLE':
        return Icons.pedal_bike;
      case 'TRUCK':
        return Icons.local_shipping_outlined;
      default:
        return Icons.directions_car_outlined;
    }
  }

  static String _formatType(String type) {
    if (type.isEmpty) return '';
    return type[0].toUpperCase() + type.substring(1).toLowerCase();
  }

  static String _formatCategory(String category) {
    switch (category.toUpperCase()) {
      case 'VISITOR':
        return 'Visitor';
      case 'OTHER':
        return 'Other';
      default:
        return 'Resident';
    }
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
