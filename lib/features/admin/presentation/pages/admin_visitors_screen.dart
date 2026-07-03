import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/admin_search_field.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';

/// Admin society-wide visitor log.
class AdminVisitorsScreen extends ConsumerStatefulWidget {
  const AdminVisitorsScreen({super.key});

  @override
  ConsumerState<AdminVisitorsScreen> createState() =>
      _AdminVisitorsScreenState();
}

class _AdminVisitorsScreenState extends ConsumerState<AdminVisitorsScreen> {
  final _searchCtl = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(adminVisitorsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final visitorsAsync = ref.watch(adminVisitorsProvider);
    final statusFilter = ref.watch(adminVisitorStatusFilterProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Visitors',
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
        child: visitorsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: ShimmerWrap(
              child: Column(
                children: List.generate(
                  5,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: ShimmerBox(height: 72, borderRadius: DesignRadius.lg),
                  ),
                ),
              ),
            ),
          ),
          error: (_, __) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Failed to load visitors',
                  subtitle: 'Pull down to refresh',
                  actionLabel: 'Retry',
                  onAction: _refresh,
                ),
              ),
            ],
          ),
          data: (data) {
            final visitors = (data['visitors'] as List?)
                    ?.whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList() ??
                [];
            final todayCount = data['todayCount'] as int? ?? 0;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                EnterprisePanel(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.today_outlined,
                          color: DesignColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        '$todayCount visitors today',
                        style: DesignTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AdminSearchField(
                  controller: _searchCtl,
                  hint: 'Search name or phone…',
                  onChanged: (v) {
                    _searchDebounce?.cancel();
                    _searchDebounce =
                        Timer(const Duration(milliseconds: 300), () {
                      if (!mounted) return;
                      ref.read(adminVisitorSearchProvider.notifier).state = v;
                    });
                  },
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('All', null, statusFilter),
                      _filterChip('Active', 'active', statusFilter),
                      _filterChip('Checked out', 'checked_out', statusFilter),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (visitors.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyStateWidget(
                      icon: Icons.people_outline,
                      title: 'No visitors found',
                      subtitle: 'Try adjusting your search or filters.',
                    ),
                  )
                else
                  ...visitors.map((v) => _visitorTile(v)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _filterChip(String label, String? value, String? current) {
    final selected = current == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          ref.read(adminVisitorStatusFilterProvider.notifier).state = value;
        },
        selectedColor: DesignColors.primary.withValues(alpha: 0.15),
        checkmarkColor: DesignColors.primary,
      ),
    );
  }

  Widget _visitorTile(Map<String, dynamic> v) {
    final name = v['name']?.toString() ?? 'Visitor';
    final phone = v['phone']?.toString() ?? '';
    final purpose = v['purpose']?.toString() ?? '';
    final checkOut = v['checkOutAt'];
    final isActive = checkOut == null;
    final gate = v['gate'] is Map
        ? (v['gate'] as Map)['name']?.toString() ?? ''
        : '';

    String timeStr = '';
    try {
      final checkIn = DateTime.parse(v['checkInAt']?.toString() ?? '');
      timeStr = DateFormat('d MMM, h:mm a').format(checkIn.toLocal());
    } catch (_) {}

    final villas = <String>[];
    final vv = v['villaVisits'];
    if (vv is List) {
      for (final item in vv) {
        if (item is Map && item['villa'] is Map) {
          final vn = item['villa']['villaNumber']?.toString();
          if (vn != null) villas.add(vn);
        }
      }
    }

    return EnterprisePanel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (isActive ? DesignColors.success : DesignColors.textSecondary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isActive ? Icons.person_outline : Icons.logout,
              color: isActive ? DesignColors.success : DesignColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: DesignTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
                if (phone.isNotEmpty)
                  Text(phone,
                      style: DesignTypography.captionSmall.copyWith(
                        color: DesignColors.textSecondary,
                      )),
                if (villas.isNotEmpty)
                  Text('Villa: ${villas.join(', ')}',
                      style: DesignTypography.captionSmall),
                if (gate.isNotEmpty || timeStr.isNotEmpty)
                  Text(
                    [gate, timeStr].where((s) => s.isNotEmpty).join(' · '),
                    style: DesignTypography.captionSmall.copyWith(
                      color: DesignColors.textSecondary,
                    ),
                  ),
                if (purpose.isNotEmpty)
                  Text(purpose,
                      style: DesignTypography.captionSmall.copyWith(
                        color: DesignColors.textSecondary,
                      )),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isActive ? DesignColors.success : DesignColors.textSecondary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isActive ? 'Active' : 'Out',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive ? DesignColors.success : DesignColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
