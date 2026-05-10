import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/models/amenity_model.dart';
import '../../data/providers/amenity_booking_provider.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../widgets/list_skeleton.dart';
import 'amenity_booking_history_screen.dart';

/// Amenities Booking Screen
class AmenitiesScreen extends ConsumerStatefulWidget {
  const AmenitiesScreen({super.key});

  @override
  ConsumerState<AmenitiesScreen> createState() => _AmenitiesScreenState();
}

class _AmenitiesScreenState extends ConsumerState<AmenitiesScreen> {
  Future<void> _pickAndBook(AmenityModel amenity) async {
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
        const SnackBar(
          content: Text('End time must be after start time'),
          backgroundColor: DesignColors.error,
        ),
      );
      return;
    }

    final success = await ref.read(amenityBookingActionProvider.notifier).createBooking(
          amenityId: amenity.id,
          startTime: startDateTime,
          endTime: endDateTime,
        );

    if (!mounted) return;
    if (success) {
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
      final error = ref.read(amenityBookingActionProvider).error?.toString() ??
          'Failed to create booking';
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
      appBar: AppBar(
        title: const Text('Amenities'),
        actions: [
          IconButton(
            tooltip: 'Booking history',
            icon: const Icon(Icons.calendar_today),
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
      body: amenitiesState.when(
        loading: () => const ListSkeleton(itemHeight: 88),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: DesignColors.error),
              const SizedBox(height: 12),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: DesignColors.textSecondary),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(amenitiesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (amenities) => amenities.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.sports_tennis_outlined,
                title: 'No amenities available',
                subtitle: 'Your society hasn\'t set up bookable amenities yet. Check back later!',
              )
            : ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: amenities.length,
          itemBuilder: (context, index) {
            final amenity = amenities[index];
            final color = _amenityColor(amenity.type);
            final icon = _amenityIcon(amenity.type);
            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ListTile(
                contentPadding: const EdgeInsets.all(AppSpacing.md),
                leading: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: DesignRadius.borderLG,
                  ),
                  child: Icon(icon, color: color, size: 30),
                ),
                title: Text(
                  amenity.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.xs),
                    Text('₹${amenity.pricePerHour.toStringAsFixed(0)}/hour'),
                    if (amenity.location != null && amenity.location!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(amenity.location!),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    const Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: DesignColors.success),
                        SizedBox(width: AppSpacing.xs),
                        Text(
                          'Available',
                          style: TextStyle(color: DesignColors.success),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: ElevatedButton(
                  onPressed: () => _pickAndBook(amenity),
                  style: ElevatedButton.styleFrom(backgroundColor: color),
                  child: const Text('Book'),
                ),
              ),
            ).animate().fadeIn(
                  duration: 300.ms,
                  delay: DesignAnimations.staggerFor(index),
                );
          },
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

  Color _amenityColor(String type) {
    switch (type.toUpperCase()) {
      case 'SWIMMING_POOL':
        return Colors.blue;
      case 'GYM':
        return Colors.red;
      case 'BANQUET_HALL':
        return Colors.purple;
      case 'SPORTS_COURT':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }
}
