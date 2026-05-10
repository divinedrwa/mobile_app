import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/models/society_banner_type.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../data/providers/content_provider.dart';
import '../widgets/premium_society_banner_card.dart';

int _bannerTypeRank(SocietyBannerType t) {
  final i = SocietyBannerType.tabOrder.indexOf(t);
  return i >= 0 ? i : 999;
}

/// Order items for Events tab: type (emergency → … → offer), then priority.
void _sortBannersForEventsTab(List<Map<String, dynamic>> items) {
  items.sort((a, b) {
    final ra = _bannerTypeRank(a['bannerType'] as SocietyBannerType);
    final rb = _bannerTypeRank(b['bannerType'] as SocietyBannerType);
    if (ra != rb) return ra.compareTo(rb);
    final pa = a['priority'] as int;
    final pb = b['priority'] as int;
    return pb.compareTo(pa);
  });
}

List<Widget> _buildBannersGroupedByType(
  BuildContext context,
  List<Map<String, dynamic>> items,
  Widget Function(BuildContext, Map<String, dynamic>) cardBuilder,
) {
  _sortBannersForEventsTab(items);
  final out = <Widget>[];
  SocietyBannerType? previous;
  for (final e in items) {
    final t = e['bannerType'] as SocietyBannerType;
    if (previous != t) {
      previous = t;
      out.add(
        Padding(
          padding: EdgeInsets.only(bottom: 10, top: out.isEmpty ? 0 : 18),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: t.accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                t.displayLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: DesignColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    out.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: cardBuilder(context, e),
      ),
    );
  }
  return out;
}

/// Modern Professional Events List Screen
class EventsListScreen extends ConsumerWidget {
  const EventsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsState = ref.watch(eventsProvider);

    return Container(
      color: DesignColors.background,
      child: eventsState.when(
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
                onPressed: () => ref.invalidate(eventsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (rawEvents) {
          final events = rawEvents.map(_toEventUiData).toList();
          final upcomingEvents = events
              .where((e) => e['isUpcoming'] as bool)
              .toList();
          final pastEvents = events
              .where((e) => !(e['isUpcoming'] as bool))
              .toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(eventsProvider),
            child: events.isEmpty
                ? _buildEmptyState()
                : ListView(
                    padding: const EdgeInsets.all(DesignSpacing.lg),
                    children: [
                      if (upcomingEvents.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Live now',
                          'Announcements, festivals, offers & society updates',
                          Colors.blue,
                        ),
                        const SizedBox(height: 16),
                        ..._buildBannersGroupedByType(
                          context,
                          upcomingEvents,
                          (_, e) => PremiumSocietyBannerCard(event: e),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (pastEvents.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Ended',
                          'Past campaigns',
                          DesignColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        ..._buildBannersGroupedByType(
                          context,
                          pastEvents,
                          (_, e) => PremiumSocietyBannerCard(event: e),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: DesignColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: DesignColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const EmptyStateWidget(
      icon: Icons.event_outlined,
      title: 'No upcoming events',
      subtitle: 'Stay tuned \u2014 community events and activities will show up here.',
    );
  }

  Map<String, dynamic> _toEventUiData(Map<String, dynamic> event) {
    final startDateRaw =
        event['startDate']?.toString() ?? event['createdAt']?.toString() ?? '';
    final startDate = DateTime.tryParse(startDateRaw);

    DateTime? endDate;
    final endRaw = event['endDate'];
    if (endRaw != null && endRaw.toString().trim().isNotEmpty) {
      endDate = DateTime.tryParse(endRaw.toString());
    }

    final now = DateTime.now();
    // Past only when an end date exists and has passed. Otherwise treat as upcoming/open.
    final isPastByEnd = endDate != null && !endDate.isAfter(now);
    final isUpcoming = !isPastByEnd;

    final bannerType = SocietyBannerType.fromApi(event['type']);
    final endsLabel = endDate != null
        ? DateFormat('MMM d, y').format(endDate.toLocal())
        : null;

    return {
      'id': event['id']?.toString() ?? '',
      'title': event['title']?.toString() ?? 'Community Event',
      'description': event['description']?.toString(),
      'date': startDate != null
          ? DateFormat('MMM d, y • h:mm a').format(startDate.toLocal())
          : 'TBA',
      'location': 'Your society',
      'priority': (event['priority'] as num?)?.toInt() ?? 0,
      'isUpcoming': isUpcoming,
      'imageUrl': event['imageUrl'],
      'bannerType': bannerType,
      'actionUrl': event['actionUrl']?.toString(),
      'endsLabel': endsLabel,
    };
  }
}
