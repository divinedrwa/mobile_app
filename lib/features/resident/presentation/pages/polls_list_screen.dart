import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/providers/content_provider.dart';
import '../widgets/community/community_ui.dart';

class PollsListScreen extends ConsumerStatefulWidget {
  const PollsListScreen({super.key});

  @override
  ConsumerState<PollsListScreen> createState() => _PollsListScreenState();
}

class _PollsListScreenState extends ConsumerState<PollsListScreen> {
  final Map<String, String?> _selectedVotes = {};

  @override
  Widget build(BuildContext context) {
    final pollsState = ref.watch(pollsProvider);

    return CommunityListBody<List<Map<String, dynamic>>>(
      asyncValue: pollsState,
      onRetry: () => ref.invalidate(pollsProvider),
      emptyIcon: Icons.how_to_vote_outlined,
      emptyTitle: 'No active polls right now',
      emptySubtitle: 'When your society creates a poll, you can vote on it here.',
      errorTitle: 'Could not load polls',
      shimmerHeight: 160,
      dataBuilder: (rawPolls) {
        final polls = rawPolls.map(_toPollUiData).toList();
        final activePolls = polls.where((p) => p['isActive'] as bool).toList();
        final closedPolls = polls.where((p) => !(p['isActive'] as bool)).toList();

        if (activePolls.isEmpty && closedPolls.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 48),
              EmptyStateWidget(
                icon: Icons.how_to_vote_outlined,
                title: 'No active polls right now',
                subtitle: 'When your society creates a poll, you can vote on it here.',
              ),
            ],
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(pollsProvider),
          child: ListView(
            padding: EdgeInsets.all(context.spacing.s16),
            children: [
              if (activePolls.isNotEmpty) ...[
                const EnterpriseSectionHeader(
                  title: 'Active polls',
                  subtitle: 'Cast your vote',
                ),
                SizedBox(height: context.spacing.s12),
                ...activePolls.map(
                  (poll) => Padding(
                    padding: EdgeInsets.only(bottom: context.spacing.s12),
                    child: _buildModernPollCard(context, poll),
                  ),
                ),
                SizedBox(height: context.spacing.s8),
              ],
              if (closedPolls.isNotEmpty) ...[
                const EnterpriseSectionHeader(
                  title: 'Closed polls',
                  subtitle: 'View results',
                ),
                SizedBox(height: context.spacing.s12),
                ...closedPolls.map(
                  (poll) => Padding(
                    padding: EdgeInsets.only(bottom: context.spacing.s12),
                    child: _buildModernPollCard(context, poll),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernPollCard(BuildContext context, Map<String, dynamic> poll) {
    final isActive = poll['isActive'] as bool;
    final hasVoted = poll['hasVoted'] as bool;
    final myOptionId = poll['myOptionId'] as String?;
    final options = (poll['options'] as List).cast<Map<String, dynamic>>();
    final pendingPick = _selectedVotes[poll['id']];
    final effectivePick = hasVoted ? myOptionId : pendingPick;

    return Container(
      padding: const EdgeInsets.all(DesignSpacing.lg),
      decoration: BoxDecoration(
        color: context.surface.defaultSurface,
        borderRadius: DesignRadius.borderXL,
        border: Border.all(
          color: isActive
              ? context.state.approved.solid.withValues(alpha: 0.35)
              : context.surface.border,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusBadge(
                context,
                isActive ? 'ACTIVE' : 'CLOSED',
                isActive ? context.state.approved.solid : context.text.tertiary,
                isActive ? Icons.check_circle : Icons.done_all,
              ),
              if (isActive && hasVoted) ...[
                const SizedBox(width: 8),
                _statusBadge(
                  context,
                  'YOU VOTED',
                  const Color(0xFFE65100),
                  Icons.how_to_vote,
                ),
              ],
              const Spacer(),
              Icon(Icons.people_outline, size: 18, color: context.text.secondary),
              const SizedBox(width: 4),
              Text(
                '${poll['votes']} votes',
                style: TextStyle(
                  fontSize: 13,
                  color: context.text.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            poll['question'] as String,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.text.primary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (isActive && hasVoted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.brand.primary.withValues(alpha: 0.08),
                borderRadius: DesignRadius.borderLG,
                border: Border.all(
                  color: context.brand.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 18, color: context.brand.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your flat already voted. Your choice is highlighted below.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.text.primary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          ...options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final oid = option['id'] as String;
            final isSelected = effectivePick != null && effectivePick == oid;
            final percentage = option['percentage'] as int;
            final showResults = !isActive;

            return Padding(
              padding: EdgeInsets.only(bottom: index < options.length - 1 ? 12 : 0),
              child: _buildPollOption(
                context,
                option['text'] as String,
                percentage,
                isSelected,
                showResults,
                () {
                  if (isActive && !hasVoted) {
                    setState(() => _selectedVotes[poll['id']] = oid);
                  }
                },
              ),
            );
          }),
          if (isActive && !hasVoted) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selectedVotes[poll['id']] != null
                    ? () async {
                        final selectedId = _selectedVotes[poll['id']];
                        if (selectedId == null) return;
                        final errorMsg = await ref
                            .read(pollVoteProvider.notifier)
                            .vote(
                              pollId: poll['id'] as String,
                              optionId: selectedId,
                            );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              errorMsg ?? 'Vote submitted successfully!',
                            ),
                            backgroundColor:
                                errorMsg != null ? context.state.denied.solid : context.state.approved.solid,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        if (errorMsg == null) {
                          setState(() => _selectedVotes.remove(poll['id'] as String));
                          ref.invalidate(pollsProvider);
                        }
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: context.brand.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: DesignRadius.borderLG,
                  ),
                ),
                child: const Text(
                  'Submit Vote',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          if (poll['endDate'] != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: context.text.tertiary),
                const SizedBox(width: 6),
                Text(
                  'Ends ${poll['endDate']}',
                  style: TextStyle(fontSize: 13, color: context.text.secondary),
                ),
              ],
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(
          delay: DesignAnimations.durationFast,
          duration: DesignAnimations.durationEntrance,
        )
        .slideY(begin: DesignAnimations.slideNormal, end: 0);
  }

  Widget _statusBadge(
    BuildContext context,
    String label,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: DesignRadius.borderXL,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollOption(
    BuildContext context,
    String text,
    int percentage,
    bool isSelected,
    bool showResults,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: showResults ? null : onTap,
      borderRadius: DesignRadius.borderLG,
      child: Container(
        padding: const EdgeInsets.all(DesignSpacing.lg),
        decoration: BoxDecoration(
          color: showResults
              ? (isSelected
                  ? context.brand.primary.withValues(alpha: 0.1)
                  : context.surface.background)
              : context.surface.background,
          borderRadius: DesignRadius.borderLG,
          border: Border.all(
            color: isSelected
                ? context.brand.primary
                : context.surface.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            if (showResults)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.brand.primary.withValues(alpha: 0.15),
                        context.brand.primary.withValues(alpha: 0.05),
                      ],
                      stops: [percentage / 100, percentage / 100],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            Row(
              children: [
                if (!showResults)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? context.brand.primary
                            : context.text.tertiary,
                        width: 2,
                      ),
                      color: isSelected ? context.brand.primary : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                if (!showResults) const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: context.text.primary,
                    ),
                  ),
                ),
                if (showResults)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? context.brand.primary : context.surface.border,
                      borderRadius: DesignRadius.borderLG,
                    ),
                    child: Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : context.text.secondary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _toPollUiData(Map<String, dynamic> poll) {
    final optionsRaw = poll['options'] as List? ?? const [];
    final totalVotes = (poll['_count']?['votes'] as num?)?.toInt() ?? 0;
    final options = optionsRaw.whereType<Map>().map((raw) {
      final option = Map<String, dynamic>.from(raw);
      final votes = (option['_count']?['votes'] as num?)?.toInt() ?? 0;
      final pct = totalVotes > 0 ? ((votes * 100) / totalVotes).round() : 0;
      return {
        'id': option['id']?.toString() ?? '',
        'text': option['optionText']?.toString() ?? 'Option',
        'percentage': pct,
      };
    }).toList();

    final status = (poll['status']?.toString() ?? '').toUpperCase();
    final isActive = status == 'ACTIVE';
    final myVoteRaw = poll['myVoteOptionId'];
    final myOptionId =
        myVoteRaw != null && myVoteRaw.toString().trim().isNotEmpty
            ? myVoteRaw.toString()
            : null;
    final hasVotedServer = poll['hasVoted'] == true;
    final hasVoted =
        hasVotedServer || (myOptionId != null && myOptionId.isNotEmpty);

    return {
      'id': poll['id']?.toString() ?? '',
      'question': poll['title']?.toString() ?? 'Poll',
      'isActive': isActive,
      'votes': totalVotes,
      'myOptionId': myOptionId,
      'hasVoted': hasVoted,
      'endDate': poll['endDate'] != null
          ? DateTime.tryParse(
              poll['endDate'].toString(),
            )?.toLocal().toString().split(' ').first
          : null,
      'options': options,
    };
  }
}
