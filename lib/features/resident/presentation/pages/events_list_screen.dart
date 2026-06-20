import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/models/society_banner_type.dart';
import '../../data/providers/content_provider.dart';
import '../widgets/community/community_ui.dart';
import '../widgets/community/event_banner_detail_sheet.dart';
import '../widgets/premium_society_banner_card.dart';

int _bannerTypeRank(SocietyBannerType t) {
  final i = SocietyBannerType.tabOrder.indexOf(t);
  return i >= 0 ? i : 999;
}

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
          padding: EdgeInsets.only(bottom: 8, top: out.isEmpty ? 0 : 14),
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: context.text.secondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    out.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onTap: () => showEventBannerDetailSheet(context, e),
          child: PremiumSocietyBannerCard(event: e),
        ),
      ),
    );
  }
  return out;
}

class EventsListScreen extends ConsumerWidget {
  const EventsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsState = ref.watch(eventsProvider);

    return CommunityListBody<List<Map<String, dynamic>>>(
      asyncValue: eventsState,
      onRetry: () => ref.invalidate(eventsProvider),
      emptyIcon: Icons.event_outlined,
      emptyTitle: 'No upcoming events',
      emptySubtitle:
          'Stay tuned — community events and activities will show up here.',
      errorTitle: 'Could not load events',
      shimmerHeight: 120,
      dataBuilder: (rawEvents) {
        final events = rawEvents.map(_toEventUiData).toList();
        final upcomingEvents =
            events.where((e) => e['isUpcoming'] as bool).toList();
        final pastEvents =
            events.where((e) => !(e['isUpcoming'] as bool)).toList();

        if (events.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 48),
              EmptyStateWidget(
                icon: Icons.event_outlined,
                title: 'No upcoming events',
                subtitle:
                    'Stay tuned — community events and activities will show up here.',
              ),
            ],
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(eventsProvider),
          child: ListView(
            padding: EdgeInsets.all(context.spacing.s16),
            children: [
              if (upcomingEvents.isNotEmpty) ...[
                const EnterpriseSectionHeader(
                  title: 'Live now',
                  subtitle: 'Announcements, festivals, offers & society updates',
                ),
                const SizedBox(height: 12),
                ..._buildBannersGroupedByType(context, upcomingEvents),
                const SizedBox(height: 8),
              ],
              if (pastEvents.isNotEmpty) ...[
                const EnterpriseSectionHeader(
                  title: 'Ended',
                  subtitle: 'Past campaigns',
                ),
                const SizedBox(height: 12),
                ..._buildBannersGroupedByType(context, pastEvents),
              ],
            ],
          ),
        );
      },
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
