import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/providers/visitor_history_provider.dart';
import '../../data/models/visitor_model.dart';
import '../../../../core/widgets/empty_state_widget.dart';
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
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    final visitorsState = ref.watch(visitorHistoryProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        backgroundColor: DesignColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: DesignColors.textPrimary,
        ),
        title: const Text(
          'Visitor history',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: DesignColors.textPrimary,
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
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search name or phone',
                    hintStyle: const TextStyle(
                      color: DesignColors.textTertiary,
                      fontSize: 15,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 22,
                      color: DesignColors.textTertiary,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: DesignColors.surfaceSoft,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
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
      body: visitorsState.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: DesignColors.textTertiary,
                ),
                const SizedBox(height: 12),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: DesignColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(visitorHistoryProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (visitors) {
          if (visitors.isEmpty) return _buildEmptyState();
          return Builder(
            builder: (context) {
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

              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final weekAgo = today.subtract(const Duration(days: 7));

              final todayVisitors = filteredVisitors.where((v) {
                final visitDate = DateTime(
                  v.visitDate.year,
                  v.visitDate.month,
                  v.visitDate.day,
                );
                return visitDate.isAtSameMomentAs(today);
              }).toList();

              final weekVisitors = filteredVisitors
                  .where((v) => v.visitDate.isAfter(weekAgo))
                  .toList();

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildVisitorsList(filteredVisitors),
                  todayVisitors.isEmpty
                      ? _buildNoResultsState('No visitors today')
                      : _buildVisitorsList(todayVisitors),
                  weekVisitors.isEmpty
                      ? _buildNoResultsState('No visitors this week')
                      : _buildVisitorsList(weekVisitors),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildVisitorsList(List<VisitorModel> visitors) {
    final groupedVisitors = <String, List<VisitorModel>>{};
    for (final visitor in visitors) {
      final local = visitor.visitDate.toLocal();
      final dateKey = DateFormat('yyyy-MM-dd').format(local);
      groupedVisitors.putIfAbsent(dateKey, () => []).add(visitor);
    }

    final sortedDates = groupedVisitors.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      color: DesignColors.primary,
      onRefresh: () async {
        ref.invalidate(visitorHistoryProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
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
      color: DesignColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: DesignColors.borderLight),
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
                    backgroundColor: DesignColors.primary.withValues(alpha: 0.12),
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: DesignColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          visitor.phone,
                          style: const TextStyle(
                            fontSize: 13,
                            color: DesignColors.textSecondary,
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
                const Text(
                  'Purpose',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: DesignColors.textTertiary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  purpose,
                  style: const TextStyle(
                    fontSize: 13,
                    color: DesignColors.textSecondary,
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: DesignColors.textTertiary,
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
        Icon(icon, size: 15, color: DesignColors.textTertiary),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: DesignColors.textSecondary,
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
