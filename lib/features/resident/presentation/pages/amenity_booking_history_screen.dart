import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/models/amenity_booking_model.dart';
import '../../data/providers/amenity_booking_provider.dart';

/// Modern Professional Amenity Booking History Screen
class AmenityBookingHistoryScreen extends ConsumerStatefulWidget {
  const AmenityBookingHistoryScreen({super.key});

  @override
  ConsumerState<AmenityBookingHistoryScreen> createState() => _AmenityBookingHistoryScreenState();
}

class _AmenityBookingHistoryScreenState extends ConsumerState<AmenityBookingHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    final bookingsState = ref.watch(amenityBookingProvider);
    final upcomingCount = ref.watch(upcomingBookingsCountProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: DesignColors.textPrimary),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Bookings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: DesignColors.textPrimary,
              ),
            ),
            if (upcomingCount > 0)
              Text(
                '$upcomingCount upcoming',
                style: TextStyle(
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
                  const Icon(Icons.upcoming, size: 18),
                  const SizedBox(width: 8),
                  const Text('Upcoming'),
                  if (upcomingCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: DesignColors.primary,
                        borderRadius: DesignRadius.borderLG,
                      ),
                      child: Text(
                        '$upcomingCount',
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
                  Text('Past'),
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list, size: 18),
                  SizedBox(width: 8),
                  Text('All'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: bookingsState.when(
        data: (bookings) {
          if (bookings.isEmpty) {
            return _buildEmptyState();
          }

          final now = DateTime.now();
          final upcomingBookings = bookings
              .where((b) => b.bookingDate.isAfter(now) && b.status == BookingStatus.confirmed)
              .toList()
            ..sort((a, b) => a.bookingDate.compareTo(b.bookingDate));

          final pastBookings = bookings
              .where((b) => b.bookingDate.isBefore(now) || b.status != BookingStatus.confirmed)
              .toList()
            ..sort((a, b) => b.bookingDate.compareTo(a.bookingDate));

          return TabBarView(
            controller: _tabController,
            children: [
              upcomingBookings.isEmpty
                  ? _buildNoUpcomingState()
                  : _buildBookingsList(upcomingBookings, isUpcoming: true),
              pastBookings.isEmpty
                  ? _buildNoPastState()
                  : _buildBookingsList(pastBookings, isUpcoming: false),
              _buildBookingsList(bookings, isUpcoming: false),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Failed to load bookings',
                style: TextStyle(fontSize: 16, color: DesignColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(amenityBookingProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/resident/amenities'),
        icon: const Icon(Icons.add),
        label: const Text('New Booking'),
      ),
    );
  }

  Widget _buildBookingsList(List<AmenityBookingModel> bookings, {required bool isUpcoming}) {
    return RefreshIndicator(
      onRefresh: () => ref.read(amenityBookingProvider.notifier).fetchBookings(),
      child: ListView.builder(
        padding: const EdgeInsets.all(DesignSpacing.lg),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildBookingCard(booking, index, isUpcoming),
          );
        },
      ),
    );
  }

  Widget _buildBookingCard(AmenityBookingModel booking, int index, bool isUpcoming) {
    final statusColor = booking.status == BookingStatus.confirmed
        ? Colors.green
        : booking.status == BookingStatus.completed
            ? Colors.blue
            : booking.status == BookingStatus.cancelled
                ? Colors.red
                : Colors.orange;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignRadius.borderXL,
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with amenity name
          Container(
            padding: const EdgeInsets.all(DesignSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  statusColor.withValues(alpha: 0.1),
                  statusColor.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(DesignSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: DesignRadius.borderLG,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    _getAmenityIcon(booking.amenityName),
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
                        booking.amenityName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: DesignColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          booking.status.label.toUpperCase(),
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
                ),
              ],
            ),
          ),
          
          // Booking details
          Padding(
            padding: const EdgeInsets.all(DesignSpacing.lg),
            child: Column(
              children: [
                _buildDetailRow(
                  Icons.calendar_today,
                  'Date',
                  DateFormat('EEEE, MMM d, y').format(booking.bookingDate),
                  Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.access_time,
                  'Time',
                  booking.timeSlot,
                  Colors.orange,
                ),
                if (booking.createdAt != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.history,
                    'Booked on',
                    DateFormat('MMM d, y').format(booking.createdAt!),
                    Colors.grey,
                  ),
                ],
                if (booking.cancelReason != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(DesignSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: DesignRadius.borderMD,
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, size: 20, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cancellation Reason',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                booking.cancelReason!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Cancel button (only for upcoming confirmed bookings)
          if (isUpcoming && booking.status == BookingStatus.confirmed) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(DesignSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _handleCancel(booking),
                  icon: const Icon(Icons.cancel, size: 20),
                  label: const Text('Cancel Booking'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: DesignRadius.borderLG,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate(delay: (50 * index).ms).fadeIn().slideY(begin: 0.2, end: 0);
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(DesignSpacing.sm),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: DesignRadius.borderMD,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: DesignColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: DesignColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  IconData _getAmenityIcon(String amenityName) {
    final name = amenityName.toLowerCase();
    if (name.contains('pool')) return Icons.pool;
    if (name.contains('gym')) return Icons.fitness_center;
    if (name.contains('club')) return Icons.celebration;
    if (name.contains('hall') || name.contains('room')) return Icons.meeting_room;
    if (name.contains('court') || name.contains('tennis')) return Icons.sports_tennis;
    if (name.contains('garden')) return Icons.park;
    return Icons.event_seat;
  }

  void _handleCancel(AmenityBookingModel booking) {
    final reasonController = TextEditingController();
    final parentContext = context;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to cancel your ${booking.amenityName} booking?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Keep It'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(amenityBookingProvider.notifier).cancelBooking(
                    booking.id!,
                    reason: reasonController.text.isNotEmpty ? reasonController.text : null,
                  );
              if (!parentContext.mounted) return;
              ScaffoldMessenger.of(parentContext).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Booking cancelled successfully'
                        : 'Failed to cancel booking',
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No Bookings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: DesignColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You haven\'t made any bookings yet',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/resident/amenities'),
            icon: const Icon(Icons.add),
            label: const Text('Book an Amenity'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoUpcomingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No Upcoming Bookings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: DesignColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Book an amenity to see it here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPastState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No Past Bookings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: DesignColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your booking history will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
