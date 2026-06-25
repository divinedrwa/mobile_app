import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/models/visitor_model.dart';
import '../../data/providers/visitor_history_provider.dart';
import '../widgets/list_skeleton.dart';
import '../widgets/visitor_management_ui.dart';

/// Visitor history — compact cards with scrollable period tabs and clear status chips.
///
/// [statusFilter] — optional status to pre-filter the list (e.g. `CHECKED_IN`,
/// `CHECKED_OUT`). When provided, a dismissible filter chip is shown and the
/// list is pre-filtered to that status.
class VisitorHistoryScreen extends ConsumerStatefulWidget {
  const VisitorHistoryScreen({super.key, this.statusFilter});

  /// Optional pre-filter: `CHECKED_IN`, `CHECKED_OUT`, etc.
  final String? statusFilter;

  @override
  ConsumerState<VisitorHistoryScreen> createState() =>
      _VisitorHistoryScreenState();
}

class _VisitorHistoryScreenState extends ConsumerState<VisitorHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _scrollController = ScrollController();
  String _searchQuery = '';
  late String? _activeStatusFilter;

  // Human-readable label for the active filter chip.
  static String _filterLabel(String status) {
    switch (status.toUpperCase()) {
      case 'CHECKED_IN':
        return 'Currently inside';
      case 'CHECKED_OUT':
        return 'Checked out';
      case 'PENDING_APPROVAL':
        return 'Awaiting approval';
      default:
        return status.replaceAll('_', ' ').toLowerCase();
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
    _activeStatusFilter = widget.statusFilter;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(paginatedVisitorHistoryProvider.notifier).loadMore();
    }
  }

  static Color _filterColor(String status) {
    switch (status.toUpperCase()) {
      case 'CHECKED_IN':
        return const Color(0xFF00B37E);
      case 'CHECKED_OUT':
        return const Color(0xFF0EA5E9);
      default:
        return DesignColors.primary;
    }
  }

  static IconData _filterIcon(String status) {
    switch (status.toUpperCase()) {
      case 'CHECKED_IN':
        return Icons.home_work_rounded;
      case 'CHECKED_OUT':
        return Icons.logout_rounded;
      default:
        return Icons.filter_list_rounded;
    }
  }

  static String _titleCaseName(String name) {
    final t = name.trim();
    if (t.isEmpty) return name;
    return t
        .split(RegExp(r'\s+'))
        .map(
          (w) => w.isEmpty
              ? ''
              : '${w[0].toUpperCase()}${w.length > 1 ? w.substring(1).toLowerCase() : ''}',
        )
        .join(' ');
  }

  static String _displayTime(VisitorModel v) {
    if (v.visitTime != null && v.visitTime!.trim().isNotEmpty) {
      return v.visitTime!.trim();
    }
    final ci = v.checkInTime;
    if (ci != null) {
      return DateFormat('h:mm a').format(ci.toLocal());
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final pState = ref.watch(paginatedVisitorHistoryProvider);

    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(
        backgroundColor: context.surface.defaultSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => context.pop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: context.text.primary,
          ),
        ),
        title: Text(
          'Visitor history',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: context.text.primary,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_activeStatusFilter != null ? 124 : 96),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: VisitorMgmtCompactSearch(
                  hintText: 'Search name or phone',
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              // Active status filter chip — dismissible
              if (_activeStatusFilter != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _filterColor(_activeStatusFilter!).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _filterColor(_activeStatusFilter!).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _filterIcon(_activeStatusFilter!),
                              size: 13,
                              color: _filterColor(_activeStatusFilter!),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _filterLabel(_activeStatusFilter!),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _filterColor(_activeStatusFilter!),
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _activeStatusFilter = null),
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: _filterColor(_activeStatusFilter!),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Tap × to clear filter',
                        style: TextStyle(
                          fontSize: 11,
                          color: DesignColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              VisitorMgmtTabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Today'),
                  Tab(text: 'This week'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _buildBody(context, pState),
    );
  }

  Widget _buildBody(BuildContext context, dynamic pState) {
    if (pState.isInitialLoad) return const ListSkeleton();

    if (pState.error != null && pState.items.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(context.spacing.s16),
        child: EnterpriseInfoBanner(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load visitor history',
          message: pState.error!,
          tone: EnterpriseTone.danger,
          actionLabel: 'Retry',
          onAction: () =>
              ref.read(paginatedVisitorHistoryProvider.notifier).refresh(),
        ),
      );
    }

    final List<VisitorModel> visitors = List<VisitorModel>.from(pState.items);
    if (visitors.isEmpty) return _buildEmptyState();

    var filteredVisitors = visitors;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filteredVisitors = visitors
          .where(
            (v) =>
                v.name.toLowerCase().contains(q) ||
                v.phone.toLowerCase().contains(q),
          )
          .toList();
    }
    // Apply status filter (set from hub stat box tap)
    if (_activeStatusFilter != null) {
      filteredVisitors = filteredVisitors
          .where((v) =>
              v.status.toUpperCase() == _activeStatusFilter!.toUpperCase())
          .toList();
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));

    final todayVisitors = filteredVisitors.where((v) {
      final visitDate =
          DateTime(v.visitDate.year, v.visitDate.month, v.visitDate.day);
      return visitDate.isAtSameMomentAs(today);
    }).toList();

    final weekVisitors =
        filteredVisitors.where((v) => v.visitDate.isAfter(weekAgo)).toList();

    return TabBarView(
      controller: _tabController,
      children: [
        _buildVisitorsList(filteredVisitors, showLoadMore: true),
        todayVisitors.isEmpty
            ? _buildNoResultsState('No visitors today')
            : _buildVisitorsList(todayVisitors),
        weekVisitors.isEmpty
            ? _buildNoResultsState('No visitors this week')
            : _buildVisitorsList(weekVisitors),
      ],
    );
  }

  Widget _buildVisitorsList(
    List<VisitorModel> visitors, {
    bool showLoadMore = false,
  }) {
    final pState = ref.watch(paginatedVisitorHistoryProvider);
    final groupedVisitors = <String, List<VisitorModel>>{};
    for (final visitor in visitors) {
      final local = visitor.visitDate.toLocal();
      final dateKey = DateFormat('yyyy-MM-dd').format(local);
      groupedVisitors.putIfAbsent(dateKey, () => []).add(visitor);
    }

    final sortedDates = groupedVisitors.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final hasFooter = showLoadMore && (pState.hasMore || pState.isLoadingMore);

    if (sortedDates.isEmpty) {
      return _buildNoResultsState('No matching visitors');
    }

    return RefreshIndicator(
      color: DesignColors.primary,
      onRefresh: () async {
        await ref.read(paginatedVisitorHistoryProvider.notifier).refresh();
      },
      child: ListView.builder(
        controller: showLoadMore ? _scrollController : null,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        itemCount: sortedDates.length + (hasFooter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= sortedDates.length) {
            if (pState.isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: TextButton(
                  onPressed: () =>
                      ref.read(paginatedVisitorHistoryProvider.notifier).loadMore(),
                  child: const Text('Load more'),
                ),
              ),
            );
          }

          final dateKey = sortedDates[index];
          final dateVisitors = groupedVisitors[dateKey]!;
          final date = DateTime.parse(dateKey);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VisitorMgmtSectionHeader(title: _formatDateHeader(date)),
              ...dateVisitors.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildVisitorCard(entry.value, entry.key),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVisitorCard(VisitorModel visitor, int index) {
    final name = _titleCaseName(visitor.name);
    final timeStr = _displayTime(visitor);
    final purpose = visitor.purpose?.trim();
    final hasPurpose = purpose != null && purpose.isNotEmpty;
    final vehicle = visitor.vehicleNumber?.trim();
    final hasVehicle = vehicle != null && vehicle.isNotEmpty;
    final hasCheckout = visitor.checkOutTime != null;

    return Material(
      color: context.surface.defaultSurface,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: context.surface.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VisitorMgmtAvatar(name: name),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.text.primary,
                          height: 1.2,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        visitor.phone,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.text.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                VisitorMgmtStatusChip(statusRaw: visitor.status),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                VisitorMgmtMetaChip(
                  icon: Icons.calendar_today_outlined,
                  label: DateFormat('EEE, MMM d, y').format(
                    visitor.visitDate.toLocal(),
                  ),
                ),
                VisitorMgmtMetaChip(
                  icon: Icons.schedule_outlined,
                  label: timeStr,
                ),
                if (hasVehicle)
                  VisitorMgmtMetaChip(
                    icon: Icons.directions_car_outlined,
                    label: vehicle,
                  ),
                if (hasPurpose)
                  VisitorMgmtMetaChip(
                    icon: Icons.notes_rounded,
                    label: purpose,
                    maxWidth: 280,
                  ),
              ],
            ),
            if (hasCheckout) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.logout_rounded,
                    size: 14,
                    color: context.text.tertiary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Checked out · ${DateFormat('h:mm a').format(visitor.checkOutTime!.toLocal())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.text.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ).animate(delay: DesignAnimations.staggerFor(index)).fadeIn(duration: 200.ms);
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final local = date.toLocal();
    final dateOnly = DateTime(local.year, local.month, local.day);

    if (dateOnly.isAtSameMomentAs(today)) return 'TODAY';
    if (dateOnly.isAtSameMomentAs(yesterday)) return 'YESTERDAY';
    return DateFormat('EEEE, MMM d').format(local).toUpperCase();
  }

  Widget _buildEmptyState() {
    if (_activeStatusFilter != null) {
      return EmptyStateWidget(
        icon: _filterIcon(_activeStatusFilter!) ,
        title: 'No visitors ${_filterLabel(_activeStatusFilter!).toLowerCase()}',
        subtitle: 'When visitors have this status, they\'ll appear here.',
      );
    }
    return const EmptyStateWidget(
      icon: Icons.people_outline_rounded,
      title: 'No visitor history yet',
      subtitle: 'When visitors check in at the gate, they\'ll appear here.',
    );
  }

  Widget _buildNoResultsState(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
        Icon(
          Icons.search_off_rounded,
          size: 52,
          color: DesignColors.textTertiary.withValues(alpha: 0.65),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: DesignColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
