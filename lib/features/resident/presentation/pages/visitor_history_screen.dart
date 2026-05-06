import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/providers/visitor_history_provider.dart';
import '../../data/models/visitor_model.dart';

/// Modern Professional Visitor History Screen
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

  @override
  Widget build(BuildContext context) {
    final visitorsState = ref.watch(visitorHistoryProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: DesignColors.textPrimary),
        ),
        title: const Text(
          'Visitor History',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: DesignColors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(110),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: DesignColors.surfaceSoft,
                    border: OutlineInputBorder(
                      borderRadius: DesignRadius.borderLG,
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              // Tabs
              TabBar(
                controller: _tabController,
                labelColor: DesignColors.primary,
                unselectedLabelColor: DesignColors.textSecondary,
                indicatorColor: DesignColors.primary,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Today'),
                  Tab(text: 'This Week'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: visitorsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 56,
                color: DesignColors.error,
              ),
              const SizedBox(height: 12),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(visitorHistoryProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (visitors) {
          if (visitors.isEmpty) return _buildEmptyState();
          return Builder(
            builder: (context) {
              // Filter by search
              var filteredVisitors = visitors;
              if (_searchQuery.isNotEmpty) {
                filteredVisitors = visitors.where((v) {
                  return v.name.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ||
                      v.phone.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      );
                }).toList();
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

              final weekVisitors = filteredVisitors.where((v) {
                return v.visitDate.isAfter(weekAgo);
              }).toList();

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
    // Group by date
    final groupedVisitors = <String, List<VisitorModel>>{};
    for (final visitor in visitors) {
      final dateKey = DateFormat('yyyy-MM-dd').format(visitor.visitDate);
      groupedVisitors.putIfAbsent(dateKey, () => []).add(visitor);
    }

    final sortedDates = groupedVisitors.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Most recent first

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(visitorHistoryProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(DesignSpacing.lg),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final dateKey = sortedDates[index];
          final dateVisitors = groupedVisitors[dateKey]!;
          final date = DateTime.parse(dateKey);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Header
              Padding(
                padding: EdgeInsets.only(bottom: 12, top: index == 0 ? 0 : 8),
                child: Text(
                  _formatDateHeader(date),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DesignColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              // Visitors for this date
              ...dateVisitors.asMap().entries.map((entry) {
                final visitorIndex = entry.key;
                final visitor = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
    final statusColor = visitor.status == 'approved'
        ? Colors.green
        : visitor.status == 'rejected'
        ? Colors.red
        : visitor.status == 'checked_in'
        ? Colors.blue
        : visitor.status == 'checked_out'
        ? Colors.grey
        : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(DesignSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignRadius.borderXL,
        border: Border.all(color: DesignColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: DesignColors.primary.withValues(alpha: 0.1),
                  borderRadius: DesignRadius.borderLG,
                ),
                child: Center(
                  child: Text(
                    visitor.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: DesignColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name & Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visitor.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: DesignColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.phone,
                          size: 14,
                          color: DesignColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          visitor.phone,
                          style: TextStyle(
                            fontSize: 13,
                            color: DesignColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: DesignRadius.borderMD,
                ),
                child: Text(
                  visitor.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Details Grid
          Row(
            children: [
              Expanded(
                child: _buildInfoChip(
                  Icons.calendar_today,
                  DateFormat('MMM d, y').format(visitor.visitDate),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoChip(
                  Icons.access_time,
                  visitor.visitTime ?? 'N/A',
                ),
              ),
            ],
          ),

          if (visitor.purpose != null) ...[
            const SizedBox(height: 8),
            _buildInfoChip(Icons.info_outline, visitor.purpose!),
          ],

          if (visitor.checkInTime != null) ...[
            const SizedBox(height: 8),
            _buildInfoChip(
              Icons.login,
              'Check-in: ${DateFormat('h:mm a').format(visitor.checkInTime!)}',
            ),
          ],

          if (visitor.checkOutTime != null) ...[
            const SizedBox(height: 8),
            _buildInfoChip(
              Icons.logout,
              'Check-out: ${DateFormat('h:mm a').format(visitor.checkOutTime!)}',
            ),
          ],
        ],
      ),
    ).animate(delay: (50 * index).ms).fadeIn().slideX(begin: 0.2, end: 0);
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: DesignColors.background,
        borderRadius: DesignRadius.borderMD,
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: DesignColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: DesignColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly.isAtSameMomentAs(today)) {
      return 'TODAY';
    } else if (dateOnly.isAtSameMomentAs(yesterday)) {
      return 'YESTERDAY';
    } else {
      return DateFormat('EEEE, MMM d, y').format(date).toUpperCase();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No Visitor History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: DesignColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No visitors recorded yet',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: DesignColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
