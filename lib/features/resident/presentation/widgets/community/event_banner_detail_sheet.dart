import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/models/society_banner_type.dart';

Future<void> showEventBannerDetailSheet(
  BuildContext context,
  Map<String, dynamic> event,
) {
  final type = event['bannerType'] as SocietyBannerType? ?? SocietyBannerType.event;
  final actionUrl = event['actionUrl']?.toString();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: ctx.surface.defaultSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ctx.surface.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: type.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        type.displayLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: type.accentColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (event['isUpcoming'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF00C853),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  event['title']?.toString() ?? 'Update',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: ctx.text.primary,
                    height: 1.25,
                    letterSpacing: -0.4,
                  ),
                ),
                if (event['date'] != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.event_rounded, size: 18, color: ctx.text.secondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event['date'].toString(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: ctx.text.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (event['endsLabel'] != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 18, color: ctx.text.secondary),
                      const SizedBox(width: 8),
                      Text(
                        'Ends ${event['endsLabel']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: ctx.text.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (event['description'] != null &&
                    event['description'].toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    event['description'].toString(),
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.55,
                      color: ctx.text.primary,
                    ),
                  ),
                ],
                if (actionUrl != null && actionUrl.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () async {
                      final uri = Uri.tryParse(actionUrl);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open link'),
                    style: FilledButton.styleFrom(
                      backgroundColor: DesignColors.primary,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: DesignRadius.borderLG,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}
