import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/models/society_banner_type.dart';

/// Premium, type-specific cards for Community → Events (view-only; no RSVP).
class PremiumSocietyBannerCard extends StatelessWidget {
  const PremiumSocietyBannerCard({
    super.key,
    required this.event,
  });

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final type = event['bannerType'] as SocietyBannerType;
    return switch (type) {
      SocietyBannerType.emergency => _EmergencyPremiumCard(event: event),
      SocietyBannerType.maintenance => _MaintenancePremiumCard(event: event),
      SocietyBannerType.announcement => _AnnouncementPremiumCard(event: event),
      SocietyBannerType.event => _ScheduledEventPremiumCard(event: event),
      SocietyBannerType.festival => _FestivalPremiumCard(event: event),
      SocietyBannerType.community => _CommunityPremiumCard(event: event),
      SocietyBannerType.offer => _OfferPremiumCard(event: event),
    };
  }
}

// —— Shared bits ——

bool _hasImage(Map<String, dynamic> event) {
  final u = event['imageUrl'];
  return u != null && u.toString().trim().isNotEmpty;
}

String _imageUrl(Map<String, dynamic> event) => event['imageUrl'].toString().trim();

Widget _statusPill(bool live) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: live ? const Color(0xFF00C853).withValues(alpha: 0.95) : const Color(0xFF90A4AE),
      borderRadius: BorderRadius.circular(20),
      boxShadow: live
          ? [
              BoxShadow(
                color: const Color(0xFF00C853).withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
    ),
    child: Text(
      live ? 'LIVE' : 'ENDED',
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        color: Colors.white,
      ),
    ),
  );
}

Future<void> _openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri != null && await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open link'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

Widget _linkChip(BuildContext context, String url) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => _openLink(context, url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DesignColors.primary.withValues(alpha: 0.35)),
          color: DesignColors.primary.withValues(alpha: 0.06),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_rounded, size: 18, color: DesignColors.primary),
            SizedBox(width: 8),
            Text(
              'Open link',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: DesignColors.primary,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.open_in_new_rounded, size: 15, color: DesignColors.primary),
          ],
        ),
      ),
    ),
  );
}

Widget _heroImageOrGradient({
  required Map<String, dynamic> event,
  required SocietyBannerType type,
  required List<Color> fallbackGradient,
  BorderRadius borderRadius = const BorderRadius.vertical(top: Radius.circular(20)),
}) {
  if (_hasImage(event)) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: 148,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              _imageUrl(event),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                key: ValueKey<int>(Object.hash(context.hashCode, error.hashCode, stackTrace.hashCode)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: fallbackGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  return ClipRRect(
    borderRadius: borderRadius,
    child: Container(
      height: 112,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: fallbackGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              type.icon,
              size: 120,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Center(
            child: Icon(type.icon, size: 48, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    ),
  );
}

// —— Emergency ——

class _EmergencyPremiumCard extends StatelessWidget {
  const _EmergencyPremiumCard({required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final live = event['isUpcoming'] as bool;
    const type = SocietyBannerType.emergency;
    final title = event['title'] as String;
    final desc = event['description'] as String?;
    final actionUrl = event['actionUrl'] as String?;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB71C1C).withValues(alpha: live ? 0.22 : 0.08),
            blurRadius: live ? 24 : 12,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: live
                      ? const [Color(0xFFB71C1C), Color(0xFFD32F2F)]
                      : const [Color(0xFF8D6E63), Color(0xFF6D4C41)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type.displayLabel.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Society-wide alert',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _statusPill(live),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: context.surface.defaultSurface,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _metaLine(Icons.schedule_rounded, event['date'] as String, const Color(0xFFB71C1C)),
                  const SizedBox(height: 10),
                  _metaLine(Icons.apartment_rounded, event['location'] as String, const Color(0xFF546E7A)),
                  if (desc != null && desc.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: DesignColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (actionUrl != null && actionUrl.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _linkChip(context, actionUrl),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: DesignAnimations.durationEntrance).slideY(begin: DesignAnimations.slideSubtle, end: 0, curve: Curves.easeOutCubic);
  }
}

Widget _metaLine(IconData icon, String text, Color accent) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: accent.withValues(alpha: 0.85)),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: DesignColors.textSecondary,
            height: 1.35,
          ),
        ),
      ),
    ],
  );
}

// —— Maintenance ——

class _MaintenancePremiumCard extends StatelessWidget {
  const _MaintenancePremiumCard({required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final live = event['isUpcoming'] as bool;
    const type = SocietyBannerType.maintenance;
    final accent = type.accentColor;

    return Container(
      decoration: BoxDecoration(
        color: context.surface.defaultSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.surface.border),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              border: Border(bottom: BorderSide(color: accent.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.75)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(type.icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.displayLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Works & schedules',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: DesignColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusPill(live),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: _standardBody(context, event, accent),
          ),
        ],
      ),
    ).animate().fadeIn(duration: DesignAnimations.durationEntrance).slideY(begin: DesignAnimations.slideSubtle, end: 0, curve: Curves.easeOutCubic);
  }
}

// —— Announcement ——

class _AnnouncementPremiumCard extends StatelessWidget {
  const _AnnouncementPremiumCard({required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    const type = SocietyBannerType.announcement;
    final accent = type.accentColor;
    final live = event['isUpcoming'] as bool;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.white,
            accent.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.1),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: [accent, accent.withValues(alpha: 0.5)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(type.icon, size: 20, color: accent),
                            const SizedBox(width: 8),
                            Text(
                              type.displayLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: accent,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const Spacer(),
                            _statusPill(live),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          event['title'] as String,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                            letterSpacing: -0.4,
                            color: context.text.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: _standardBody(context, event, accent, skipTitle: true),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: DesignAnimations.durationEntrance).slideY(begin: DesignAnimations.slideSubtle, end: 0, curve: Curves.easeOutCubic);
  }
}

// —— Scheduled “Event” ——

class _ScheduledEventPremiumCard extends StatelessWidget {
  const _ScheduledEventPremiumCard({required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    const type = SocietyBannerType.event;
    final accent = type.accentColor;
    final live = event['isUpcoming'] as bool;
    final gStart = accent;
    final gEnd = Color.lerp(accent, const Color(0xFF0D47A1), 0.35)!;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heroImageOrGradient(
              event: event,
              type: type,
              fallbackGradient: [gStart, gEnd],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            Container(
              color: context.surface.defaultSurface,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: accent.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_note_rounded, size: 18, color: accent),
                            const SizedBox(width: 8),
                            Text(
                              type.displayLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _statusPill(live),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    event['title'] as String,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.45,
                      height: 1.25,
                      color: context.text.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _standardBody(context, event, accent, skipTitle: true),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: DesignAnimations.durationEntrance).slideY(begin: DesignAnimations.slideSubtle, end: 0, curve: Curves.easeOutCubic);
  }
}

// —— Festival ——

class _FestivalPremiumCard extends StatelessWidget {
  const _FestivalPremiumCard({required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    const type = SocietyBannerType.festival;
    final live = event['isUpcoming'] as bool;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3E0), Color(0xFFFFFDE7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFFFE0B2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6D00).withValues(alpha: 0.18),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heroImageOrGradient(
              event: event,
              type: type,
              fallbackGradient: const [
                Color(0xFFFF8F00),
                Color(0xFFFF6D00),
              ],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '✦ ${type.displayLabel}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.5,
                          color: type.accentColor,
                        ),
                      ),
                      const Spacer(),
                      _statusPill(live),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event['title'] as String,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1.2,
                      color: context.text.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _standardBody(context, event, type.accentColor, skipTitle: true),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: DesignAnimations.durationEntrance).slideY(begin: DesignAnimations.slideSubtle, end: 0, curve: Curves.easeOutCubic);
  }
}

// —— Community ——

class _CommunityPremiumCard extends StatelessWidget {
  const _CommunityPremiumCard({required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    const type = SocietyBannerType.community;
    final accent = type.accentColor;
    final live = event['isUpcoming'] as bool;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: context.surface.defaultSurface,
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.2),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -40,
              child: CircleAvatar(
                radius: 90,
                backgroundColor: accent.withValues(alpha: 0.07),
              ),
            ),
            Positioned(
              left: -30,
              bottom: 80,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: accent.withValues(alpha: 0.05),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.14),
                        accent.withValues(alpha: 0.03),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.groups_rounded, color: accent, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          type.displayLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: accent,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      _statusPill(live),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: _standardBody(context, event, accent),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: DesignAnimations.durationEntrance).slideY(begin: DesignAnimations.slideSubtle, end: 0, curve: Curves.easeOutCubic);
  }
}

// —— Offer ——

class _OfferPremiumCard extends StatelessWidget {
  const _OfferPremiumCard({required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    const type = SocietyBannerType.offer;
    final accent = type.accentColor;
    final live = event['isUpcoming'] as bool;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE8F5E9),
            Colors.white,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.rotate(
                    angle: -0.08,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withValues(alpha: 0.75)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        'OFFER',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  _statusPill(live),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(type.icon, color: accent, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Member benefit',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: accent.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event['title'] as String,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      height: 1.25,
                      color: context.text.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _standardBody(context, event, accent, skipTitle: true),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: DesignAnimations.durationEntrance).slideY(begin: DesignAnimations.slideSubtle, end: 0, curve: Curves.easeOutCubic);
  }
}

Widget _standardBody(
  BuildContext context,
  Map<String, dynamic> event,
  Color accent, {
  bool skipTitle = false,
}) {
  final desc = event['description'] as String?;
  final actionUrl = event['actionUrl'] as String?;
  final endLabel = event['endsLabel'] as String?;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!skipTitle && event['title'] != null) ...[
        Text(
          event['title'] as String,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.35,
            height: 1.25,
            color: context.text.primary,
          ),
        ),
        const SizedBox(height: 12),
      ],
      _metaLine(Icons.calendar_month_rounded, event['date'] as String, accent),
      if (endLabel != null && endLabel.isNotEmpty) ...[
        const SizedBox(height: 8),
        _metaLine(Icons.flag_rounded, 'Ends $endLabel', accent),
      ],
      const SizedBox(height: 10),
      _metaLine(Icons.location_city_rounded, event['location'] as String, accent),
      if (desc != null && desc.trim().isNotEmpty) ...[
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.surface.elevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.surface.border),
          ),
          child: Text(
            desc,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: DesignColors.textSecondary,
            ),
          ),
        ),
      ],
      if (actionUrl != null && actionUrl.trim().isNotEmpty) ...[
        const SizedBox(height: 14),
        _linkChip(context, actionUrl),
      ],
    ],
  );
}
