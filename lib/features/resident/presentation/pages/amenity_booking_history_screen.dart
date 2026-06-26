import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/models/amenity_booking_model.dart';
import '../../data/providers/amenity_booking_provider.dart';
import '../widgets/list_skeleton.dart';

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
      backgroundColor: context.surface.background,
      appBar: AppBar(
        backgroundColor: context.surface.defaultSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.text.primary),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'My Bookings',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: context.text.primary),
            ),
            Text(
              upcomingCount > 0 ? '$upcomingCount upcoming' : 'Amenity booking history',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.text.secondary, height: 1.2),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: DesignColors.primary,
          unselectedLabelColor: context.text.secondary,
          indicatorColor: DesignColors.primary,
          dividerColor: context.surface.border.withValues(alpha: 0.5),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.upcoming_outlined, size: 18),
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
                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
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
                  Icon(Icons.history_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Past'),
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list_alt_rounded, size: 18),
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
        loading: () => const ListSkeleton(),
        error: (error, stack) => Padding(
          padding: const EdgeInsets.all(DesignSpacing.lg),
          child: EnterpriseInfoBanner(
            icon: Icons.event_seat_outlined,
            title: 'Could not load bookings',
            message: 'Check your connection and try again.',
            tone: EnterpriseTone.danger,
            actionLabel: 'Retry',
            onAction: () => ref.refresh(amenityBookingProvider),
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
                        style: TextStyle(
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
              style: TextStyle(
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

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Container(
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
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: DesignColors.borderLight, borderRadius: BorderRadius.circular(2)),
                  ),
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(color: DesignColors.error.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(Icons.event_busy_outlined, color: DesignColors.error, size: 28),
                  ),
                  const SizedBox(height: 16),
                  Text('Cancel booking?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: DesignColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text(
                    'Cancel your ${booking.amenityName} booking?\nThis action cannot be undone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: DesignColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    decoration: DesignComponents.inputDecoration(label: 'Reason (optional)'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                          child: const Text('No, Keep It'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            Navigator.pop(sheetCtx);
                            final error = await ref.read(amenityBookingProvider.notifier).cancelBooking(
                                  booking.id!,
                                  reason: reasonController.text.isNotEmpty ? reasonController.text : null,
                                );
                            if (!parentContext.mounted) return;
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Text(error ?? 'Booking cancelled successfully'),
                                backgroundColor: error == null ? DesignColors.success : DesignColors.error,
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(backgroundColor: DesignColors.error, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                          child: const Text('Yes, Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
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
