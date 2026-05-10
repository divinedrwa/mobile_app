import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/models/parcel_model.dart';
import '../../data/providers/parcel_provider.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../widgets/list_skeleton.dart';

/// Modern Professional Parcel Management Screen
class ParcelManagementScreen extends ConsumerStatefulWidget {
  const ParcelManagementScreen({super.key});

  @override
  ConsumerState<ParcelManagementScreen> createState() => _ParcelManagementScreenState();
}

class _ParcelManagementScreenState extends ConsumerState<ParcelManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parcelsState = ref.watch(parcelProvider);
    final pendingCount = ref.watch(pendingParcelsCountProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: DesignColors.textPrimary),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Parcels',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: DesignColors.textPrimary,
              ),
            ),
            if (pendingCount > 0)
              Text(
                '$pendingCount pending collection',
                style: const TextStyle(
                  fontSize: 12,
                  color: DesignColors.textSecondary,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: DesignColors.primary,
          unselectedLabelColor: DesignColors.textSecondary,
          indicatorColor: DesignColors.primary,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox, size: 18),
                  const SizedBox(width: 8),
                  const Text('Pending'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: DesignRadius.borderLG,
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 18),
                  SizedBox(width: 8),
                  Text('History'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: parcelsState.when(
        data: (parcels) {
          if (parcels.isEmpty) {
            return _buildEmptyState();
          }

          final pendingParcels = parcels.where((p) => p.status == ParcelStatus.pending).toList();
          final historyParcels = parcels.where((p) => p.status != ParcelStatus.pending).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              pendingParcels.isEmpty
                  ? _buildNoPendingState()
                  : _buildParcelsList(pendingParcels, isPending: true),
              historyParcels.isEmpty
                  ? _buildNoHistoryState()
                  : _buildParcelsList(historyParcels, isPending: false),
            ],
          );
        },
        loading: () => const ListSkeleton(itemHeight: 100),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'Failed to load parcels',
                style: TextStyle(fontSize: 16, color: DesignColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(parcelProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParcelsList(List<ParcelModel> parcels, {required bool isPending}) {
    return RefreshIndicator(
      onRefresh: () => ref.read(parcelProvider.notifier).fetchParcels(),
      child: ListView.builder(
        padding: const EdgeInsets.all(DesignSpacing.lg),
        itemCount: parcels.length,
        itemBuilder: (context, index) {
          final parcel = parcels[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildParcelCard(parcel, index, isPending),
          );
        },
      ),
    );
  }

  Widget _buildParcelCard(ParcelModel parcel, int index, bool isPending) {
    final statusColor = parcel.status == ParcelStatus.pending
        ? Colors.orange
        : parcel.status == ParcelStatus.collected
            ? Colors.green
            : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(DesignSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignRadius.borderXL,
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
          width: 1,
        ),
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
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DesignSpacing.md),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: DesignRadius.borderLG,
                ),
                child: Icon(
                  Icons.local_shipping,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parcel.courier,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: DesignColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      parcel.trackingNumber,
                      style: const TextStyle(
                        fontSize: 13,
                        color: DesignColors.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: DesignRadius.borderMD,
                ),
                child: Text(
                  parcel.status.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Details
          if (parcel.receivedAt != null)
            _buildDetailRow(
              Icons.access_time,
              'Received',
              DateFormat('MMM d, y - h:mm a').format(parcel.receivedAt!),
            ),
          
          if (parcel.collectedAt != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.check_circle,
              'Collected',
              DateFormat('MMM d, y - h:mm a').format(parcel.collectedAt!),
            ),
          ],
          
          if (parcel.collectedBy != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.person,
              'Collected By',
              parcel.collectedBy!,
            ),
          ],
          
          if (parcel.notes != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(DesignSpacing.md),
              decoration: BoxDecoration(
                color: DesignColors.background,
                borderRadius: DesignRadius.borderMD,
              ),
              child: Row(
                children: [
                  const Icon(Icons.note, size: 16, color: DesignColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      parcel.notes!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: DesignColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Collect Button (only for pending parcels)
          if (isPending && parcel.status == ParcelStatus.pending) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _handleCollect(parcel),
                icon: const Icon(Icons.check_circle, size: 20),
                label: const Text('Mark as Collected'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: DesignRadius.borderLG,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate(delay: DesignAnimations.staggerFor(index)).fadeIn().slideX(begin: DesignAnimations.slideSubtle, end: 0);
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: DesignColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            color: DesignColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: DesignColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _handleCollect(ParcelModel parcel) {
    final pageContext = context;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Collect Parcel'),
        content: Text(
          'Mark this parcel from ${parcel.courier} as collected?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(parcelProvider.notifier).markAsCollected(parcel.id!);
              if (!pageContext.mounted) return;
              ScaffoldMessenger.of(pageContext).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Parcel marked as collected'
                        : 'Failed to mark parcel as collected',
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyStateWidget(
      icon: Icons.inventory_2_outlined,
      title: 'No parcels waiting',
      subtitle: 'We\'ll notify you as soon as one arrives at the gate.',
    );
  }

  Widget _buildNoPendingState() {
    return const EmptyStateWidget(
      icon: Icons.check_circle_outline_rounded,
      title: 'All collected!',
      subtitle: 'No pending parcels right now. We\'ll let you know when one arrives.',
      iconColor: DesignColors.success,
    );
  }

  Widget _buildNoHistoryState() {
    return const EmptyStateWidget(
      icon: Icons.history_rounded,
      title: 'No parcel history',
      subtitle: 'Collected parcels will show up here for your reference.',
    );
  }
}
