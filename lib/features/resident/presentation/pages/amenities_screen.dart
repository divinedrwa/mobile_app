import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/async_animated_switcher.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/models/amenity_model.dart';
import '../../data/providers/amenity_booking_provider.dart';
import '../widgets/list_skeleton.dart';
import 'amenity_booking_history_screen.dart';

/// Amenities Booking Screen
class AmenitiesScreen extends ConsumerStatefulWidget {
  const AmenitiesScreen({super.key});

  @override
  ConsumerState<AmenitiesScreen> createState() => _AmenitiesScreenState();
}

class _AmenitiesScreenState extends ConsumerState<AmenitiesScreen> {
  bool _booking = false; // guards against double-submit

  Future<void> _pickAndBook(AmenityModel amenity) async {
    if (_booking) return;
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final lastDate = firstDate.add(const Duration(days: 60));

    final pickedDate = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: firstDate,
    );
    if (pickedDate == null) return;

    if (!mounted) return;
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (start == null) return;

    if (!mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: start.hour + 1, minute: start.minute),
    );
    if (end == null) return;
    if (!mounted) return;

    final startDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      start.hour,
      start.minute,
    );
    final endDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      end.hour,
      end.minute,
    );

    if (!endDateTime.isAfter(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('End time must be after start time'),
          backgroundColor: DesignColors.error,
        ),
      );
      return;
    }

    setState(() => _booking = true);
    final error = await ref
        .read(amenityBookingActionProvider.notifier)
        .createBooking(
          amenityId: amenity.id,
          startTime: startDateTime,
          endTime: endDateTime,
        );

    if (mounted) setState(() => _booking = false);
    if (!mounted) return;
    if (error == null) {
      ref.invalidate(amenitiesProvider);
      unawaited(ref.read(amenityBookingProvider.notifier).fetchBookings());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${amenity.name} booked for ${DateFormat('dd MMM, hh:mm a').format(startDateTime)}',
          ),
          backgroundColor: DesignColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: DesignColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final amenitiesState = ref.watch(amenitiesProvider);

    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(
        backgroundColor: context.surface.defaultSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.text.primary),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Amenities',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: context.text.primary,
              ),
            ),
            Text(
              'Book shared spaces in your society',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.text.secondary,
                height: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Booking history',
            icon: Icon(Icons.history_rounded, color: context.brand.primary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AmenityBookingHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: amenitiesState.whenAnimated(
        skipLoadingOnReload: true,
        loading: () => const ListSkeleton(itemHeight: 88),
        error: (error, _) => Padding(
          padding: EdgeInsets.all(context.spacing.s16),
          child: EnterpriseInfoBanner(
            icon: Icons.event_busy_rounded,
            title: 'Could not load amenities',
            message: userFacingMessage(error),
            tone: EnterpriseTone.danger,
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(amenitiesProvider),
          ),
        ),
        data: (amenities) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(amenitiesProvider),
          child: amenities.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [EmptyStateWidget(
                  icon: Icons.sports_tennis_outlined,
                  title: 'No amenities available',
                  subtitle: 'Your society hasn\'t set up bookable amenities yet. Check back later!',
                )],
              )
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  context.spacing.s16,
                  context.spacing.s12,
                  context.spacing.s16,
                  context.spacing.s32,
                ),
                children: [
                  EnterprisePanel(
                    tone: EnterpriseTone.info,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Book shared spaces with confidence',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: context.text.primary,
                              ),
                        ),
                        SizedBox(height: context.spacing.s8),
                        Text(
                          'Choose a date and time, confirm the booking, and track previous reservations from booking history.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: context.text.secondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.spacing.s24),
                  EnterpriseSectionHeader(
                    title: 'Available amenities',
                    subtitle: '${amenities.length} bookable ${amenities.length == 1 ? 'space' : 'spaces'} in your society',
                  ),
                  SizedBox(height: context.spacing.s12),
                  for (int index = 0; index < amenities.length; index++)
                    _AmenityCard(
                      amenity: amenities[index],
                      icon: _amenityIcon(amenities[index].type),
                      color: _amenityColor(context, amenities[index].type),
                      busy: _booking,
                      onBook: () => _pickAndBook(amenities[index]),
                    ).animate().fadeIn(
                          duration: 300.ms,
                          delay: DesignAnimations.staggerFor(index),
                        ),
                ],
              ),
        ),
      ),
    );
  }

  IconData _amenityIcon(String type) {
    switch (type.toUpperCase()) {
      case 'SWIMMING_POOL':
        return Icons.pool;
      case 'GYM':
        return Icons.fitness_center;
      case 'BANQUET_HALL':
        return Icons.celebration;
      case 'SPORTS_COURT':
        return Icons.sports_tennis;
      default:
        return Icons.apartment;
    }
  }

  Color _amenityColor(BuildContext context, String type) {
    switch (type.toUpperCase()) {
      case 'SWIMMING_POOL':
        return context.state.info.solid;
      case 'GYM':
        return context.state.denied.solid;
      case 'BANQUET_HALL':
        return context.brand.accent;
      case 'SPORTS_COURT':
        return context.state.approved.solid;
      default:
        return context.brand.primary;
    }
  }
}

class _AmenityCard extends StatelessWidget {
  const _AmenityCard({
    required this.amenity,
    required this.icon,
    required this.color,
    required this.onBook,
    this.busy = false,
  });

  final AmenityModel amenity;
  final IconData icon;
  final Color color;
  final VoidCallback onBook;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final priceLabel = 'INR ${amenity.pricePerHour.toStringAsFixed(0)}/hour';
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.text.secondary,
        );

    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.s12),
      child: EnterprisePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(context.radius.md),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: color, size: 24),
                ),
                SizedBox(width: context.spacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        amenity.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: context.text.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      SizedBox(height: context.spacing.s4),
                      Text(priceLabel, style: subtitleStyle),
                      if (amenity.location != null &&
                          amenity.location!.trim().isNotEmpty) ...[
                        SizedBox(height: context.spacing.s4),
                        Text(amenity.location!, style: subtitleStyle),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: context.spacing.s12),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.spacing.s8,
                    vertical: context.spacing.s4,
                  ),
                  decoration: BoxDecoration(
                    color: context.state.approved.bg,
                    borderRadius: BorderRadius.circular(context.radius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: context.state.approved.solid,
                      ),
                      SizedBox(width: context.spacing.s4),
                      Text(
                        'Available',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: context.state.approved.fg,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: busy ? null : onBook,
                  child: const Text('Book now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
