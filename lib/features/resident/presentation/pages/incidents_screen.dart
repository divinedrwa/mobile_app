import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/media_url.dart' show resolveServerFileUrl;
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/models/incident_model.dart';
import '../../data/providers/incident_provider.dart';

class IncidentsScreen extends ConsumerStatefulWidget {
  const IncidentsScreen({super.key});

  @override
  ConsumerState<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends ConsumerState<IncidentsScreen> {
  String _filter = 'all'; // all, unresolved, resolved

  @override
  Widget build(BuildContext context) {
    final incidentsAsync = ref.watch(incidentsProvider);

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
            Text('Incident Reports', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: context.text.primary)),
            Text('Society safety & incident log', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.text.secondary, height: 1.2)),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: () async => ref.invalidate(incidentsProvider),
        child: incidentsAsync.when(
          loading: () => _buildShimmer(),
          error: (err, _) => _buildError(context),
          data: (incidents) {
            if (incidents.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyStateWidget(
                    icon: Icons.shield_outlined,
                    title: 'No incidents reported',
                    subtitle:
                        'Incident reports from your society will appear here.',
                    actionLabel: 'Refresh',
                    onAction: () => ref.invalidate(incidentsProvider),
                  ),
                ],
              );
            }

            final filtered = _applyFilter(incidents);
            final unresolvedCount =
                incidents.where((i) => !i.isResolved).length;

            return ListView(
              padding: const EdgeInsets.all(DesignSpacing.lg),
              children: [
                _buildSummaryPill(context, incidents.length, unresolvedCount),
                const SizedBox(height: DesignSpacing.md),
                _buildFilterChips(context),
                const SizedBox(height: DesignSpacing.md),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        'No ${_filter == "resolved" ? "resolved" : "unresolved"} incidents',
                        style: DesignTypography.body.copyWith(
                          color: context.text.tertiary,
                        ),
                      ),
                    ),
                  )
                else
                  ...filtered.asMap().entries.map((entry) {
                    return _buildIncidentCard(context, entry.value, entry.key);
                  }),
              ],
            );
          },
        ),
      ),
    );
  }

  List<IncidentModel> _applyFilter(List<IncidentModel> all) {
    switch (_filter) {
      case 'unresolved':
        return all.where((i) => !i.isResolved).toList();
      case 'resolved':
        return all.where((i) => i.isResolved).toList();
      default:
        return all;
    }
  }

  Widget _buildSummaryPill(
      BuildContext context, int total, int unresolved) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.surface.defaultSurface,
        borderRadius: BorderRadius.circular(DesignRadius.full),
        border: Border.all(color: context.surface.border),
      ),
      child: Text(
        '$total total  ·  $unresolved unresolved',
        style: DesignTypography.labelSmall.copyWith(
          color: context.text.secondary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _filterChip(context, 'All', 'all'),
        _filterChip(context, 'Unresolved', 'unresolved'),
        _filterChip(context, 'Resolved', 'resolved'),
      ],
    );
  }

  Widget _filterChip(BuildContext context, String label, String value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (s) {
        if (s) setState(() => _filter = value);
      },
      selectedColor: DesignColors.primary.withValues(alpha: 0.15),
      labelStyle: DesignTypography.labelSmall.copyWith(
        color: selected ? DesignColors.primary : context.text.secondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected ? DesignColors.primary : context.surface.border,
      ),
    );
  }

  Widget _buildIncidentCard(
      BuildContext context, IncidentModel incident, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignSpacing.sm),
      child: EnterprisePanel(
        tone: EnterpriseTone.neutral,
        padding: const EdgeInsets.all(DesignSpacing.lg),
        onTap: () => _showIncidentDetail(context, incident),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _severityBadge(context, incident.severity),
                const Spacer(),
                if (incident.isResolved)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: DesignColors.success.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(DesignRadius.full),
                    ),
                    child: Text(
                      'Resolved',
                      style: DesignTypography.captionSmall.copyWith(
                        color: DesignColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: DesignColors.warning.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(DesignRadius.full),
                    ),
                    child: Text(
                      'Unresolved',
                      style: DesignTypography.captionSmall.copyWith(
                        color: DesignColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: DesignSpacing.sm),
            Text(
              incident.title,
              style: DesignTypography.headingM.copyWith(
                color: context.text.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              incident.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: DesignTypography.body.copyWith(
                color: context.text.secondary,
              ),
            ),
            const SizedBox(height: DesignSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (incident.location != null &&
                    incident.location!.isNotEmpty)
                  _infoChip(
                      context, Icons.location_on_outlined, incident.location!),
                if (incident.reportedByName != null)
                  _infoChip(context, Icons.person_outline,
                      incident.reportedByName!),
                _infoChip(
                    context,
                    Icons.access_time,
                    _relativeTime(incident.createdAt)),
              ],
            ),
            if (incident.photoUrl != null && incident.photoUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: DesignSpacing.sm),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(DesignRadius.md),
                  child: CachedNetworkImage(
                    imageUrl: resolveServerFileUrl(incident.photoUrl!) ?? incident.photoUrl!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const ShimmerBox(height: 120),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
          ],
        ),
      ),
    )
        .animate(delay: DesignAnimations.staggerFor(index))
        .slideY(
          begin: DesignAnimations.slideNormal,
          end: 0,
          duration: DesignAnimations.durationEntrance,
        )
        .fadeIn();
  }

  Widget _severityBadge(BuildContext context, String severity) {
    final (Color bg, Color fg) = switch (severity.toUpperCase()) {
      'CRITICAL' => (
          DesignColors.error.withValues(alpha: 0.15),
          DesignColors.error,
        ),
      'HIGH' => (
          DesignColors.error.withValues(alpha: 0.12),
          DesignColors.error,
        ),
      'MEDIUM' => (
          DesignColors.warning.withValues(alpha: 0.12),
          DesignColors.warning,
        ),
      _ => (
          DesignColors.info.withValues(alpha: 0.12),
          DesignColors.info,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DesignRadius.full),
      ),
      child: Text(
        severity.toUpperCase(),
        style: DesignTypography.captionSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _infoChip(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: context.text.tertiary),
        const SizedBox(width: 3),
        Text(
          text,
          style: DesignTypography.caption.copyWith(
            color: context.text.tertiary,
          ),
        ),
      ],
    );
  }

  void _showIncidentDetail(BuildContext context, IncidentModel incident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surface.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(DesignSpacing.xl),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.surface.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: DesignSpacing.lg),
            Row(
              children: [
                _severityBadge(context, incident.severity),
                const SizedBox(width: 8),
                if (incident.isResolved)
                  Text(
                    'Resolved ${incident.resolvedAt != null ? DateFormat.yMMMd().format(incident.resolvedAt!.toLocal()) : ""}',
                    style: DesignTypography.caption.copyWith(
                      color: DesignColors.success,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: DesignSpacing.md),
            Text(
              incident.title,
              style: DesignTypography.headingL.copyWith(
                color: context.text.primary,
              ),
            ),
            const SizedBox(height: DesignSpacing.sm),
            Text(
              incident.description,
              style: DesignTypography.body.copyWith(
                color: context.text.secondary,
              ),
            ),
            if (incident.location != null) ...[
              const SizedBox(height: DesignSpacing.md),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 16, color: context.text.tertiary),
                  const SizedBox(width: 4),
                  Text(
                    incident.location!,
                    style: DesignTypography.bodySmall.copyWith(
                      color: context.text.secondary,
                    ),
                  ),
                ],
              ),
            ],
            if (incident.reportedByName != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 16, color: context.text.tertiary),
                  const SizedBox(width: 4),
                  Text(
                    'Reported by ${incident.reportedByName}',
                    style: DesignTypography.bodySmall.copyWith(
                      color: context.text.secondary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time,
                    size: 16, color: context.text.tertiary),
                const SizedBox(width: 4),
                Text(
                  DateFormat.yMMMd()
                      .add_jm()
                      .format(incident.createdAt.toLocal()),
                  style: DesignTypography.bodySmall.copyWith(
                    color: context.text.secondary,
                  ),
                ),
              ],
            ),
            if (incident.photoUrl != null &&
                incident.photoUrl!.isNotEmpty) ...[
              const SizedBox(height: DesignSpacing.lg),
              ClipRRect(
                borderRadius: BorderRadius.circular(DesignRadius.lg),
                child: CachedNetworkImage(
                  imageUrl: resolveServerFileUrl(incident.photoUrl!) ?? incident.photoUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      const ShimmerBox(height: 200),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ShimmerWrap(
      child: Padding(
        padding: const EdgeInsets.all(DesignSpacing.lg),
        child: Column(
          children: [
            const ShimmerBox(height: 30),
            const SizedBox(height: DesignSpacing.md),
            const ShimmerBox(height: 30, width: 200),
            const SizedBox(height: DesignSpacing.md),
            const ShimmerBox(height: 140),
            const SizedBox(height: DesignSpacing.sm),
            const ShimmerBox(height: 140),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: DesignColors.error, size: 48),
          const SizedBox(height: DesignSpacing.sm),
          Text(
            'Failed to load incidents',
            style: DesignTypography.body.copyWith(
                color: context.text.secondary),
          ),
          const SizedBox(height: DesignSpacing.sm),
          TextButton(
            onPressed: () => ref.invalidate(incidentsProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat.yMMMd().format(dt.toLocal());
}
