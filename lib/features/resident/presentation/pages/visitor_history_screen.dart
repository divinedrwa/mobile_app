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

/// Visitor history — compact, readable cards; status labels and times derived from API fields.
class VisitorHistoryScreen extends ConsumerStatefulWidget {
  const VisitorHistoryScreen({super.key});

  @override
  ConsumerState<VisitorHistoryScreen> createState() =>
      _VisitorHistoryScreenState();
}

class _VisitorHistoryScreenState extends ConsumerState<VisitorHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _scrollController = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
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

  static String _normalizeStatusKey(String raw) {
    return raw.trim().toUpperCase().replaceAll('-', '_');
  }

  static Color _statusAccent(String raw) {
    switch (_normalizeStatusKey(raw)) {
      case 'APPROVED':
        return DesignColors.success;
      case 'CHECKED_IN':
        return DesignColors.primary;
      case 'CHECKED_OUT':
        return DesignColors.textSecondary;
      case 'REJECTED':
        return DesignColors.error;
      case 'PENDING':
      case 'PENDING_APPROVAL':
        return DesignColors.warning;
      default:
        return DesignColors.textSecondary;
    }
  }

  static String _statusLabel(String raw) {
    final key = _normalizeStatusKey(raw);
    const map = <String, String>{
      'CHECKED_IN': 'Checked in',
      'CHECKED_OUT': 'Checked out',
      'PENDING': 'Pending',
      'PENDING_APPROVAL': 'Awaiting approval',
      'APPROVED': 'Approved',
      'REJECTED': 'Rejected',
    };
    if (map.containsKey(key)) return map[key]!;
    return raw
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .map(
          (p) =>
              '${p[0].toUpperCase()}${p.length > 1 ? p.substring(1).toLowerCase() : ''}',
        )
        .join(' ');
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
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.text.primary,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: TextStyle(fontSize: 15, color: context.text.primary),
                  decoration: InputDecoration(
                    hintText: 'Search name or phone',
                    hintStyle: TextStyle(
                      color: context.text.tertiary,
                      fontSize: 15,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 22,
                      color: context.text.tertiary,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: context.surface.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.surface.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.surface.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                labelColor: DesignColors.primary,
                unselectedLabelColor: DesignColors.textTertiary,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorColor: DesignColors.primary,
                indicatorWeight: 2.5,
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
          onAction: () => ref.read(paginatedVisitorHistoryProvider.notifier).refresh(),
        ),
      );
    }

    final List<VisitorModel> visitors = List<VisitorModel>.from(pState.items);
    if (visitors.isEmpty) return _buildEmptyState();

    var filteredVisitors = visitors;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filteredVisitors = visitors
          .where((v) =>
              v.name.toLowerCase().contains(q) ||
              v.phone.toLowerCase().contains(q))
          .toList();
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));

    final todayVisitors = filteredVisitors.where((v) {
      final visitDate = DateTime(v.visitDate.year, v.visitDate.month, v.visitDate.day);
      return visitDate.isAtSameMomentAs(today);
    }).toList();

    final weekVisitors = filteredVisitors
        .where((v) => v.visitDate.isAfter(weekAgo))
        .toList();

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

  Widget _buildVisitorsList(List<VisitorModel> visitors, {bool showLoadMore = false}) {
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

    return RefreshIndicator(
      color: DesignColors.primary,
      onRefresh: () async {
        await ref.read(paginatedVisitorHistoryProvider.notifier).refresh();
      },
      child: ListView.builder(
        controller: showLoadMore ? _scrollController : null,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        itemCount: sortedDates.length + (hasFooter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= sortedDates.length) {
            // Load more footer
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
                  onPressed: () => ref.read(paginatedVisitorHistoryProvider.notifier).loadMore(),
                  child: const Text('Load more'),
                ),
              ),
            );
          }

          final dateKey = sortedDates[index];
          final dateVisitors = groupedVisitors[dateKey]!;
          final date = DateTime.parse(dateKey);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 8, top: index == 0 ? 0 : 14),
                child: Text(
                  _formatDateHeader(date),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: DesignColors.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              ...dateVisitors.asMap().entries.map((entry) {
                final visitorIndex = entry.key;
                final visitor = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildVisitorCard(visitor, visitorIndex),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVisitorCard(VisitorModel visitor, int index) {
    final accent = _statusAccent(visitor.status);
    final statusText = _statusLabel(visitor.status);
    final name = _titleCaseName(visitor.name);
    final timeStr = _displayTime(visitor);
    final hasCheckout = visitor.checkOutTime != null;
    final purpose = visitor.purpose?.trim();
    final hasPurpose = purpose != null && purpose.isNotEmpty;
    final vehicle = visitor.vehicleNumber?.trim();
    final hasVehicle = vehicle != null && vehicle.isNotEmpty;

    return Material(
      color: context.surface.defaultSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: context.surface.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: context.brand.primary.withValues(alpha: 0.12),
                    child: Text(
                      name.isNotEmpty
                          ? name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: DesignColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.text.primary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          visitor.phone,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.text.secondary,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: accent,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: DesignColors.divider),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _metaItem(
                    Icons.calendar_today_outlined,
                    DateFormat('EEE, MMM d, y').format(
                      visitor.visitDate.toLocal(),
                    ),
                  ),
                  _metaItem(Icons.schedule_outlined, timeStr),
                  if (hasVehicle)
                    _metaItem(Icons.directions_car_outlined, vehicle),
                ],
              ),
              if (hasPurpose) ...[
                const SizedBox(height: 8),
                Text(
                  'Purpose',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.text.tertiary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  purpose,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.text.secondary,
                    height: 1.35,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (hasCheckout) ...[
                const SizedBox(height: 6),
                Text(
                  'Checked out · ${DateFormat('h:mm a').format(visitor.checkOutTime!.toLocal())}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.text.tertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
    ).animate(delay: DesignAnimations.staggerFor(index)).fadeIn(duration: 200.ms);
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: context.text.tertiary),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.text.secondary,
          ),
        ),
      ],
    );
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
    return const EmptyStateWidget(
      icon: Icons.people_outline_rounded,
      title: 'No visitor history yet',
      subtitle: 'When visitors check in at the gate, they\'ll appear here.',
    );
  }

  Widget _buildNoResultsState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 56,
            color: DesignColors.textTertiary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              color: DesignColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
