import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/models/event_model.dart';
import '../../data/providers/content_provider.dart';

/// Event Detail Screen
class EventDetailScreen extends ConsumerStatefulWidget {
  final EventModel event;

  const EventDetailScreen({
    super.key,
    required this.event,
  });

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _isRegistering = false;

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor(widget.event.category);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: DesignColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.text.primary),
        ),
        title: Text(
          'Event Details',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: context.text.primary),
        ),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: Icon(Icons.share_rounded, color: context.text.primary),
            onPressed: () {
              Share.share(
                '${widget.event.title}\n\n'
                '${DateFormat('dd MMM yyyy, hh:mm a').format(widget.event.startTime)}\n'
                'Location: ${widget.event.location}\n\n'
                '${widget.event.description}',
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Banner
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    categoryColor,
                    categoryColor.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Icon(
                  _getCategoryIcon(widget.event.category),
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ).animate().fadeIn(duration: 300.ms),

            // Event Info
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Badges
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      _buildBadge(
                        _getCategoryLabel(widget.event.category),
                        categoryColor,
                      ),
                      if (widget.event.isRegistered)
                        _buildBadge('REGISTERED', DesignColors.success),
                      if (widget.event.isFull)
                        _buildBadge('FULL', Colors.red),
                      if (widget.event.isPast)
                        _buildBadge('PAST', Colors.grey),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Title
                  Text(
                    widget.event.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Details
                  _buildDetailRow(
                    Icons.calendar_today,
                    'Date',
                    DateFormat('dd MMMM yyyy').format(widget.event.startTime),
                  ),
                  _buildDetailRow(
                    Icons.access_time,
                    'Time',
                    '${DateFormat('hh:mm a').format(widget.event.startTime)} - ${DateFormat('hh:mm a').format(widget.event.endTime)}',
                  ),
                  _buildDetailRow(
                    Icons.location_on,
                    'Location',
                    widget.event.location,
                  ),
                  if (widget.event.organizer != null)
                    _buildDetailRow(
                      Icons.person,
                      'Organizer',
                      widget.event.organizer!,
                    ),
                  if (widget.event.requiresRegistration)
                    _buildDetailRow(
                      Icons.people,
                      'Attendees',
                      widget.event.maxAttendees != null
                          ? '${widget.event.currentAttendees}/${widget.event.maxAttendees}'
                          : '${widget.event.currentAttendees}',
                    ),

                  const SizedBox(height: AppSpacing.lg),

                  // Description
                  Text(
                    'About',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.event.description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.6,
                        ),
                  ),

                  // Attendee Progress
                  if (widget.event.requiresRegistration &&
                      widget.event.maxAttendees != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    EnterprisePanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Registration',
                                style: TextStyle(fontWeight: FontWeight.w700, color: context.text.primary),
                              ),
                              Text(
                                '${widget.event.currentAttendees}/${widget.event.maxAttendees}',
                                style: TextStyle(fontWeight: FontWeight.w700, color: context.text.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ClipRRect(
                            borderRadius: DesignRadius.borderXS,
                            child: LinearProgressIndicator(
                              value: widget.event.maxAttendees! > 0
                                  ? widget.event.currentAttendees / widget.event.maxAttendees!
                                  : 0,
                              backgroundColor: DesignColors.borderLight,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                widget.event.isFull ? DesignColors.error : categoryColor,
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),
          ],
        ),
      ),
      bottomNavigationBar: widget.event.canRegister
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: DesignColors.surface,
                border: Border(top: BorderSide(color: DesignColors.borderLight.withValues(alpha: 0.9))),
                boxShadow: DesignElevation.sm,
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(DesignSpacing.lg, 0, DesignSpacing.lg, DesignSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: DesignSpacing.md),
                  child: FilledButton(
                    onPressed: _isRegistering ? null : _registerForEvent,
                    style: FilledButton.styleFrom(
                      backgroundColor: categoryColor,
                      padding: const EdgeInsets.symmetric(vertical: DesignSpacing.md + 2),
                      shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD),
                    ),
                    child: _isRegistering
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Text('Register for Event', style: DesignTypography.label.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: DesignColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: DesignColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: DesignRadius.borderXS,
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getCategoryLabel(EventCategory category) {
    switch (category) {
      case EventCategory.social:
        return 'SOCIAL';
      case EventCategory.sports:
        return 'SPORTS';
      case EventCategory.cultural:
        return 'CULTURAL';
      case EventCategory.meeting:
        return 'MEETING';
      case EventCategory.workshop:
        return 'WORKSHOP';
      case EventCategory.festival:
        return 'FESTIVAL';
    }
  }

  IconData _getCategoryIcon(EventCategory category) {
    switch (category) {
      case EventCategory.social:
        return Icons.groups;
      case EventCategory.sports:
        return Icons.sports;
      case EventCategory.cultural:
        return Icons.theater_comedy;
      case EventCategory.meeting:
        return Icons.meeting_room;
      case EventCategory.workshop:
        return Icons.school;
      case EventCategory.festival:
        return Icons.celebration;
    }
  }

  Color _getCategoryColor(EventCategory category) {
    switch (category) {
      case EventCategory.social:
        return Colors.blue;
      case EventCategory.sports:
        return Colors.red;
      case EventCategory.cultural:
        return Colors.purple;
      case EventCategory.meeting:
        return Colors.teal;
      case EventCategory.workshop:
        return Colors.orange;
      case EventCategory.festival:
        return Colors.pink;
    }
  }

  Future<void> _registerForEvent() async {
    setState(() {
      _isRegistering = true;
    });

    final error = await ref.read(eventRegistrationProvider.notifier).register(
          widget.event.id,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error ?? 'Successfully registered for event!',
          ),
          backgroundColor: error == null ? DesignColors.success : DesignColors.error,
        ),
      );
      if (error == null) context.pop();
      setState(() => _isRegistering = false);
    }
  }
}
